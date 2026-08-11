"""
Lightweight WhatsApp send/receive helpers for Blood450.

Public API:
  send_whatsapp_message(phone, message)
  receive_whatsapp_message(phone, text, whatsapp_message_id)
  send_whatsapp_welcome_on_register(user, phone)
"""
import logging
from typing import Any, Dict, Optional

from django.conf import settings
from django.contrib.auth import get_user_model

from careapp.services.whatsapp_utils import normalize_phone, parse_reply_keyword

logger = logging.getLogger(__name__)
User = get_user_model()


def send_whatsapp_message(
    phone: str,
    message: str,
    *,
    outbound_kind: str = 'session',
) -> Dict[str, Any]:
    """
    Send a text message via Meta WhatsApp Cloud API (or console provider in dev).

    outbound_kind: 'session' for replies after donor messaged us; 'admin'; 'proactive'.
    """
    from careapp.services.whatsapp_service import whatsapp_service

    result = whatsapp_service.send_text_message(
        phone,
        message,
        outbound_kind=outbound_kind,
    )
    if result.get('ok'):
        logger.info('WhatsApp SENT to %s: %s', normalize_phone(phone), message[:120])
    else:
        logger.error('WhatsApp SEND failed to %s: %s', phone, result.get('error'))
    return result


def receive_whatsapp_message(
    phone: str,
    text: str,
    whatsapp_message_id: str = '',
    *,
    message_type: str = 'text',
    media_url: str = '',
    profile_name: str = '',
) -> Dict[str, Any]:
    """
    Process inbound donor WhatsApp (personal account → business test number).

    Stores message, then optional auto-reply from business number via Cloud API.
    """
    # Use Meta's `from` as-is (digits, country code included) for storage and reply.
    normalized = normalize_phone(phone)
    body = (text or '').strip()

    logger.info(
        'WhatsApp IN | phone=%s | msg_id=%s | text=%s',
        normalized,
        whatsapp_message_id,
        body[:500],
    )
    print(f'[WhatsApp IN] donor={normalized} (personal) -> business: {body[:120]}')

    from careapp.services.whatsapp_service import whatsapp_service

    stored = whatsapp_service.handle_inbound_text(
        phone,
        body,
        whatsapp_message_id=whatsapp_message_id,
        media_url=media_url,
        message_type=message_type,
        profile_name=profile_name,
    )

    auto_reply_result = None
    if getattr(settings, 'WHATSAPP_AUTO_REPLY_ENABLED', True):
        auto_reply_result = _maybe_auto_reply(normalized, body)

    return {
        'ok': True,
        'phone': normalized,
        'text': body,
        'message_id': stored.id,
        'auto_reply': auto_reply_result,
    }


def send_whatsapp_welcome_on_register(user: User, phone: str) -> Dict[str, Any]:
    """Send welcome WhatsApp after donor completes registration (proactive; dev-gated)."""
    if not getattr(settings, 'WHATSAPP_SEND_WELCOME_ON_REGISTER', False):
        return {'ok': False, 'skipped': True, 'reason': 'WHATSAPP_SEND_WELCOME_ON_REGISTER=false'}

    normalized = normalize_phone(phone)
    if not normalized:
        return {'ok': False, 'error': 'No phone number'}

    name = (user.get_full_name() or user.first_name or user.username or 'Donor').strip()
    business_line = getattr(settings, 'WHATSAPP_BASE_PHONE_DISPLAY', '') or '+1 (555) 656-5019'

    message = (
        f'Welcome to Blood450, {name}!\n\n'
        f'You are registered as a blood donor. '
        f'Message us on WhatsApp at {business_line} for support or blood requests.\n\n'
        f'Reply HELP for options.'
    )

    from careapp.services.whatsapp_service import whatsapp_service
    from careapp.models import DonorProfile
    from careapp.whatsapp_models import WhatsAppMessage

    donor = getattr(user, 'donor_profile', None)
    if donor is None:
        donor = DonorProfile.objects.filter(user=user).first()

    conv = whatsapp_service.get_or_create_conversation(
        normalized,
        donor_profile=donor,
        donor_user=user,
    )

    return whatsapp_service.send_text_message(
        normalized,
        message,
        conversation=conv,
        sender_type=WhatsAppMessage.SENDER_SYSTEM,
        outbound_kind='proactive',
    )


def _maybe_auto_reply(phone: str, text: str) -> Optional[Dict[str, Any]]:
    """
    Auto-reply after donor messaged the business number (session message).
    Skips YES/NO blood keywords (handled in whatsapp_service).
    """
    if parse_reply_keyword(text):
        return None

    upper = text.upper().strip()
    reply = None

    if upper in ('HELP', 'HI', 'HELLO', 'HEY', 'START'):
        reply = (
            'Blood450 Support\n'
            '- Reply with questions about donation\n'
            '- For blood requests you will receive alerts; reply YES to accept or NO to decline\n'
            '- Our team will respond during emergencies'
        )
    elif upper in ('THANKS', 'THANK YOU', 'TY'):
        reply = 'Thank you for supporting Blood450. Stay safe!'
    elif text:
        reply = (
            'Thank you for messaging Blood450. '
            'Our team has received your message and will reply shortly. '
            'Reply HELP for options.'
        )

    if not reply:
        return None

    result = send_whatsapp_message(phone, reply, outbound_kind='session')
    if result.get('ok'):
        logger.info('WhatsApp AUTO-REPLY sent to donor %s', phone)
        print(f'[WhatsApp AUTO-REPLY] business -> donor {phone}: {reply[:80]}...')
    else:
        err = result.get('error', 'unknown')
        logger.error('WhatsApp AUTO-REPLY failed to %s: %s', phone, err)
        print(f'[WhatsApp AUTO-REPLY FAILED] donor={phone} error={err}')
    return result
