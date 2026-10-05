# careapp/otp_service.py – OTP generation, cache storage, and SMS (console/Twilio/MSG91/Fast2SMS)

import random
import string
import logging
from django.core.cache import cache
from django.conf import settings

logger = logging.getLogger(__name__)

OTP_EXPIRY = getattr(settings, "OTP_EXPIRY_SECONDS", 600)
OTP_LEN = getattr(settings, "OTP_LENGTH", 6)


def _normalize_phone_e164(phone):
    """Convert Indian 10-digit to E.164 +91XXXXXXXXXX for Twilio/MSG91."""
    p = (phone or "").strip().replace(" ", "").replace("-", "")
    if len(p) == 10 and p.isdigit() and p[0] in "6789":
        return "+91" + p
    if p.startswith("+91") and len(p) == 13:
        return p
    if p.startswith("91") and len(p) == 12 and p[2:].isdigit():
        return "+" + p
    return p


def generate_otp(length=None):
    length = length or OTP_LEN
    return "".join(random.choices(string.digits, k=length))


def get_cache_key(phone):
    return f"otp:{phone}"


def set_otp(phone, otp):
    key = get_cache_key(phone)
    cache.set(key, otp, timeout=OTP_EXPIRY)


def get_otp(phone):
    key = get_cache_key(phone)
    return cache.get(key)


def clear_otp(phone):
    key = get_cache_key(phone)
    cache.delete(key)


def send_otp_sms(phone, otp):
    """
    Send OTP to the given phone number.
    Uses OTP_SMS_BACKEND: 'console', 'twilio', 'twilio_verify', 'msg91', 'fast2sms'.
    For twilio_verify, pass otp=None (Twilio generates and sends); returns True if sent.
    """
    backend = getattr(settings, "OTP_SMS_BACKEND", "console")
    logger.info("Sending OTP using backend: %s", backend)
    logger.info("Phone: %s, OTP: %s", phone, otp)

    if backend == "console":
        logger.info("OTP for %s: %s (not sent; set OTP_SMS_BACKEND for real SMS)", phone, otp)
        return True
    if backend == "twilio":
        logger.info("Using Twilio to send OTP")
        return _send_via_twilio(phone, otp)
    if backend == "twilio_verify":
        logger.info("Using Twilio Verify to send OTP")
        return _send_via_twilio_verify(phone)
    if backend == "msg91":
        logger.info("Using MSG91 to send OTP")
        return _send_via_msg91(phone, otp)
    if backend == "fast2sms":
        logger.info("Using Fast2SMS to send OTP")
        return _send_via_fast2sms(phone, otp)

    logger.warning("Unknown OTP_SMS_BACKEND=%s; logging OTP for %s: %s", backend, phone, otp)
    return True


def check_otp_twilio_verify(phone, code):
    """
    Verify OTP using Twilio Verify API (only when OTP_SMS_BACKEND is 'twilio_verify').
    Returns (True, None) if valid, else (False, error_message).
    """
    try:
        from twilio.rest import Client
        account_sid = getattr(settings, "TWILIO_ACCOUNT_SID", None)
        auth_token = getattr(settings, "TWILIO_AUTH_TOKEN", None)
        service_sid = getattr(settings, "TWILIO_VERIFY_SERVICE_SID", None)
        if not all([account_sid, auth_token, service_sid]):
            return False, "Twilio Verify not configured."
        to_number = _normalize_phone_e164(phone)
        client = Client(account_sid, auth_token)
        check = client.verify.v2.services(service_sid).verification_checks.create(
            to=to_number,
            code=(code or "").strip(),
        )
        if check.status == "approved":
            return True, None
        return False, "Invalid or expired code."
    except Exception as e:
        logger.exception("Twilio Verify check failed: %s", e)
        err = str(e)
        if "404" in err or "not found" in err.lower():
            return False, "Invalid or expired code."
        return False, "Verification failed. Please try again."


def _send_via_twilio(phone, otp):
    try:
        from twilio.rest import Client
        account_sid = getattr(settings, "TWILIO_ACCOUNT_SID", None)
        auth_token = getattr(settings, "TWILIO_AUTH_TOKEN", None)
        from_number = getattr(settings, "TWILIO_FROM_NUMBER", None)
        if not all([account_sid, auth_token, from_number]):
            logger.warning("Twilio not configured; OTP for %s: %s", phone, otp)
            return True
        to_number = _normalize_phone_e164(phone)
        client = Client(account_sid, auth_token)
        body = f"Your Blood450 verification code is {otp}. Valid for {OTP_EXPIRY // 60} minutes."
        client.messages.create(to=to_number, from_=from_number, body=body)
        logger.info("Twilio SMS sent to %s", to_number)
        return True
    except Exception as e:
        logger.exception("Twilio SMS failed: %s", e)
        return False


def _send_via_twilio_verify(phone):
    """Send OTP via Twilio Verify API (uses Service SID, no from number). Twilio generates OTP."""
    try:
        from twilio.rest import Client
        account_sid = getattr(settings, "TWILIO_ACCOUNT_SID", None)
        auth_token = getattr(settings, "TWILIO_AUTH_TOKEN", None)
        service_sid = getattr(settings, "TWILIO_VERIFY_SERVICE_SID", None)
        if not all([account_sid, auth_token, service_sid]):
            logger.warning("Twilio Verify not configured (need TWILIO_VERIFY_SERVICE_SID); OTP not sent")
            return True
        to_number = _normalize_phone_e164(phone)
        client = Client(account_sid, auth_token)
        client.verify.v2.services(service_sid).verifications.create(
            to=to_number,
            channel="sms",
        )
        logger.info("Twilio Verify SMS sent to %s", to_number)
        return True
    except Exception as e:
        logger.exception("Twilio Verify send failed: %s", e)
        return False


def _send_via_msg91(phone, otp):
    try:
        import urllib.request
        import urllib.parse
        authkey = getattr(settings, "MSG91_AUTH_KEY", None)
        if not authkey:
            logger.warning("MSG91 not configured; OTP for %s: %s", phone, otp)
            return True
        mobile = _normalize_phone_e164(phone)
        # MSG91 OTP send: https://docs.msg91.com/p/otp-api
        url = "https://control.msg91.com/api/v5/flow/"
        data = urllib.parse.urlencode({
            "template_id": getattr(settings, "MSG91_OTP_TEMPLATE_ID", ""),
            "short_url": "0",
            "recipients": mobile.lstrip("+"),
            "otp": otp,
        }).encode()
        req = urllib.request.Request(
            url,
            data=data,
            headers={"authkey": authkey, "Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status == 200
    except Exception as e:
        logger.exception("MSG91 SMS failed: %s", e)
        return False


def _send_via_fast2sms(phone, otp):
    """Send OTP via Fast2SMS (India). Phone: 10-digit Indian number. API expects JSON body."""
    try:
        import urllib.request
        import json
        api_key = getattr(settings, "FAST2SMS_API_KEY", None)
        if not api_key:
            logger.warning("Fast2SMS not configured; OTP for %s: %s", phone, otp)
            return True
        logger.info("Fast2SMS API Key found. Preparing request.")

        # Fast2SMS expects 10-digit Indian number(s)
        p = (phone or "").strip().replace(" ", "").replace("-", "")
        if p.startswith("+91"):
            p = p[3:].strip()
        elif p.startswith("91") and len(p) == 12:
            p = p[2:]
        if len(p) != 10 or not p.isdigit():
            logger.warning("Fast2SMS: invalid Indian number %s (digits=%s)", phone, p)
            return False

        url = "https://www.fast2sms.com/dev/bulkV2"
        payload = {
            "variables_values": str(otp),
            "route": "otp",
            "numbers": p,
        }
        body_bytes = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=body_bytes,
            headers={
                "authorization": api_key,
                "Content-Type": "application/json",
            },
            method="POST",
        )
        logger.info("Sending request to Fast2SMS: %s", payload)
        with urllib.request.urlopen(req, timeout=15) as r:
            resp_body = r.read().decode()
            logger.info("Fast2SMS response for %s: %s", p, resp_body[:400])
            if r.status != 200:
                logger.warning("Fast2SMS HTTP %s: %s", r.status, resp_body)
                return False
            try:
                data = json.loads(resp_body)
                if data.get("return") is False:
                    logger.warning("Fast2SMS API returned false: %s", data.get("message", resp_body))
                    return False
            except (ValueError, TypeError):
                logger.error("Failed to parse Fast2SMS response: %s", resp_body)
                return False
            return True
    except urllib.error.HTTPError as e:
        err_body = ""
        if hasattr(e, "fp") and e.fp:
            try:
                err_body = e.fp.read().decode()[:300]
            except Exception:
                pass
        logger.error("Fast2SMS failed for %s: HTTP Error %s: %s", phone, e.code, err_body)
        if "website verification" in err_body.lower():
            logger.error("Fast2SMS: Website verification required. Complete verification in the Fast2SMS dashboard.")
        return False
    except Exception as e:
        logger.exception("Fast2SMS failed for %s: %s", phone, e)
        return False


def create_and_send_otp(phone):
    otp = generate_otp()
    set_otp(phone, otp)
    send_otp_sms(phone, otp)
    return otp


def verify_otp(phone, user_otp):
    stored = get_otp(phone)
    if stored is None:
        return False, "OTP expired or invalid. Please request a new one."
    if str(user_otp).strip() != str(stored):
        return False, "Invalid OTP."
    clear_otp(phone)
    return True, None
