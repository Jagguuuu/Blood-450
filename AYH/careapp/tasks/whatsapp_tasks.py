"""Celery tasks for queued WhatsApp delivery."""
import logging

logger = logging.getLogger(__name__)

try:
    from celery import shared_task
except ImportError:
    def shared_task(*dargs, **dkwargs):
        def decorator(fn):
            fn.delay = lambda *a, **k: fn(*a, **k)
            return fn
        return decorator


def _run_or_sync(func, *args, **kwargs):
    try:
        return func(*args, **kwargs)
    except Exception:
        logger.exception('WhatsApp task failed: %s', func.__name__)
        return None


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_whatsapp_text_task(self, phone: str, message: str, message_type: str = 'text'):
    from careapp.services.whatsapp_service import whatsapp_service
    result = whatsapp_service.send_text_message(phone, message, message_type=message_type)
    if not result.get('ok'):
        raise self.retry(exc=Exception(result.get('error', 'send failed')))
    return result


@shared_task(bind=True, max_retries=3, default_retry_delay=60)
def send_blood_request_alert_task(self, blood_request_id: int, donor_profile_id: int):
    from careapp.models import BloodRequest, DonorProfile
    from careapp.services.whatsapp_service import whatsapp_service
    try:
        br = BloodRequest.objects.get(pk=blood_request_id)
        dp = DonorProfile.objects.get(pk=donor_profile_id)
    except (BloodRequest.DoesNotExist, DonorProfile.DoesNotExist):
        return {'ok': False, 'error': 'not found'}
    result = whatsapp_service.send_blood_request_alert(br, dp)
    if not result.get('ok'):
        raise self.retry(exc=Exception(result.get('error', 'alert failed')))
    return result


@shared_task
def retry_failed_whatsapp_log(log_id: int):
    from careapp.whatsapp_models import WhatsAppMessageLog
    from careapp.services.whatsapp_service import whatsapp_service
    log = WhatsAppMessageLog.objects.filter(pk=log_id, status=WhatsAppMessageLog.STATUS_FAILED).first()
    if not log:
        return
    log.retry_count += 1
    log.save(update_fields=['retry_count'])
    return whatsapp_service.send_text_message(
        log.phone,
        log.message,
        message_type=log.message_type,
        save_chat=False,
    )
