"""Phone normalization and webhook security helpers."""
import hashlib
import hmac
import re
from typing import Optional

from django.conf import settings


def default_country_code() -> str:
    return str(getattr(settings, 'WHATSAPP_DEFAULT_COUNTRY_CODE', '91') or '91').lstrip('+')


def meta_recipient_digits(phone: str) -> str:
    """Digits-only number for Meta Cloud API `to` field (same as webhook `from`)."""
    return normalize_phone(phone)


def normalize_phone(phone: str, country_code: Optional[str] = None) -> str:
    """Return digits-only E.164 without + (e.g. 919876543210)."""
    if not phone:
        return ''
    cc = country_code or default_country_code()
    digits = re.sub(r'\D', '', str(phone))
    if not digits:
        return ''
    if len(digits) == 10:
        return f'{cc}{digits}'
    if digits.startswith('0') and len(digits) == 11:
        return f'{cc}{digits[1:]}'
    return digits


def phones_match(a: str, b: str) -> bool:
    na, nb = normalize_phone(a), normalize_phone(b)
    if not na or not nb:
        return False
    return na == nb or na.endswith(nb[-10:]) or nb.endswith(na[-10:])


def verify_webhook_signature(payload: bytes, signature_header: Optional[str]) -> bool:
    """Meta WhatsApp Cloud API X-Hub-Signature-256 verification."""
    app_secret = getattr(settings, 'WHATSAPP_APP_SECRET', None) or ''
    if not app_secret or not signature_header:
        return not app_secret  # skip when secret not configured (dev)
    if not signature_header.startswith('sha256='):
        return False
    expected = signature_header.split('=', 1)[1]
    digest = hmac.new(
        app_secret.encode('utf-8'),
        payload,
        hashlib.sha256,
    ).hexdigest()
    return hmac.compare_digest(digest, expected)


def format_whatsapp_api_error(error) -> str:
    """Turn Meta/Twilio error payload into a short user-facing message."""
    if error is None:
        return 'WhatsApp send failed'
    if isinstance(error, str):
        return error
    if isinstance(error, dict):
        inner = error.get('error') if 'error' in error else error
        if isinstance(inner, dict):
            msg = inner.get('message') or 'WhatsApp API error'
            code = inner.get('code')
            details = ''
            ed = inner.get('error_data')
            if isinstance(ed, dict):
                details = ed.get('details') or ''
            text = f'{msg}'
            if details:
                text = f'{msg} — {details}'
            if code == 131030:
                text += (
                    ' Add the donor phone in Meta > WhatsApp > API Setup > '
                    'test recipients (Send test messages).'
                )
            elif code in (131047, 131026):
                text += (
                    ' Donor must message your business number first, or use an '
                    'approved template (24-hour window).'
                )
            elif code == 190:
                text += ' Access token expired — generate a new token in Meta.'
            return text
        return str(error)
    return str(error)


def parse_reply_keyword(text: str) -> Optional[str]:
    """Map donor WhatsApp reply to accept/reject."""
    if not text:
        return None
    t = text.strip().upper()
    accept = {'YES', 'Y', 'ACCEPT', 'OK', '1', 'HAAN', 'हाँ', 'हां'}
    reject = {'NO', 'N', 'REJECT', 'DECLINE', '2', 'NAHI', 'नहीं'}
    if t in accept:
        return 'accepted'
    if t in reject:
        return 'rejected'
    return None
