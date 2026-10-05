"""Hooks into existing blood-request notification flow (non-invasive)."""
import logging
import time

logger = logging.getLogger(__name__)

# Cached Redis/Celery broker probe — .delay() retries for ~60s when Redis is down.
_broker_ok = None
_broker_checked_at = 0.0
_BROKER_TTL_SEC = 30.0


def _celery_broker_available() -> bool:
    """Fast Redis ping so create-request never waits on Celery reconnect loops."""
    global _broker_ok, _broker_checked_at
    now = time.monotonic()
    if _broker_ok is not None and (now - _broker_checked_at) < _BROKER_TTL_SEC:
        return bool(_broker_ok)
    try:
        import redis
        from django.conf import settings

        client = redis.from_url(
            settings.REDIS_URL,
            socket_connect_timeout=0.2,
            socket_timeout=0.2,
        )
        client.ping()
        _broker_ok = True
    except Exception:
        _broker_ok = False
    _broker_checked_at = now
    return bool(_broker_ok)


def trigger_blood_alert_whatsapp(donor_user, blood_request):
    """
    Queue a WhatsApp blood alert. Never block the HTTP request.

    If Redis/Celery is unavailable, skip WhatsApp for this notify cycle
    instead of calling .delay() (that made Create Request take 60s+).
    """
    profile = getattr(donor_user, 'donor_profile', None)
    if not profile or not profile.phone:
        return
    if not _celery_broker_available():
        logger.info(
            'WhatsApp blood alert skipped (Redis unavailable). '
            'request_id=%s donor_profile_id=%s',
            getattr(blood_request, 'id', None),
            getattr(profile, 'id', None),
        )
        return
    try:
        from careapp.tasks.whatsapp_tasks import send_blood_request_alert_task
        send_blood_request_alert_task.delay(blood_request.id, profile.id)
    except Exception:
        global _broker_ok, _broker_checked_at
        _broker_ok = False
        _broker_checked_at = time.monotonic()
        logger.warning(
            'WhatsApp blood alert not queued (Celery/broker unavailable). '
            'request_id=%s donor_profile_id=%s',
            getattr(blood_request, 'id', None),
            getattr(profile, 'id', None),
            exc_info=True,
        )


def trigger_standby_promotion_whatsapp(donor_user, blood_request):
    trigger_blood_alert_whatsapp(donor_user, blood_request)
