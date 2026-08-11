"""Hooks into existing blood-request notification flow (non-invasive)."""
import logging

logger = logging.getLogger(__name__)


def trigger_blood_alert_whatsapp(donor_user, blood_request):
    """Send WhatsApp blood alert when in-app notification is created."""
    profile = getattr(donor_user, 'donor_profile', None)
    if not profile or not profile.phone:
        return
    from careapp.tasks.whatsapp_tasks import send_blood_request_alert_task
    try:
        send_blood_request_alert_task.delay(blood_request.id, profile.id)
    except Exception:
        try:
            send_blood_request_alert_task(blood_request.id, profile.id)
        except Exception:
            logger.exception('WhatsApp blood alert failed (sync)')


def trigger_standby_promotion_whatsapp(donor_user, blood_request):
    trigger_blood_alert_whatsapp(donor_user, blood_request)
