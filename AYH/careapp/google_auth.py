"""
Google identity helpers for Flutter mobile ID-token auth.

Web Google OAuth in careapp.views.google_callback is separate and unchanged.
"""
import logging

import requests
from django.conf import settings as django_settings
from django.contrib.auth.models import User
from django.db import transaction

from .models import UserProfile

logger = logging.getLogger(__name__)

GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo"


def allowed_google_audiences():
    """OAuth client IDs that may appear as `aud` on a verified Google ID token."""
    audiences = []
    for key in (
        "GOOGLE_OAUTH_CLIENT_ID",
        "GOOGLE_OAUTH_ANDROID_CLIENT_ID",
        "GOOGLE_OAUTH_IOS_CLIENT_ID",
    ):
        value = getattr(django_settings, key, None)
        if value:
            audiences.append(value)
    return audiences


def verify_google_id_token(id_token: str):
    """
    Verify a Google ID token via Google's tokeninfo endpoint.
    Returns userinfo dict with email/name on success, or raises ValueError.
    """
    if not id_token or not str(id_token).strip():
        raise ValueError("id_token is required")

    audiences = allowed_google_audiences()
    if not audiences:
        raise ValueError("Google Sign-In is not configured on the server")

    resp = requests.get(
        GOOGLE_TOKENINFO_URL,
        params={"id_token": id_token.strip()},
        timeout=10,
    )
    if not resp.ok:
        logger.warning("Google tokeninfo failed: %s %s", resp.status_code, resp.text[:300])
        raise ValueError("Invalid Google ID token")

    payload = resp.json()
    aud = payload.get("aud")
    if aud not in audiences:
        logger.warning("Google token audience mismatch: aud=%s allowed=%s", aud, audiences)
        raise ValueError("Google token audience mismatch")

    email = (payload.get("email") or "").strip().lower()
    if not email:
        raise ValueError("Google account did not provide an email")

    if str(payload.get("email_verified", "true")).lower() in ("false", "0"):
        raise ValueError("Google email is not verified")

    name = (payload.get("name") or payload.get("given_name") or email).strip()
    return {
        "email": email,
        "name": name,
        "sub": payload.get("sub"),
        "picture": payload.get("picture"),
    }


def get_or_create_user_from_google(email: str, name: str):
    """
    Find or create Django User (+ UserProfile) for a Google identity.

    Does NOT create DonorProfile. Donor status comes only from the mobile
    donor opt-in flow (DonorWillingDialog → CreateProfileScreen → POST /api/donors/).
    """
    email = (email or "").strip().lower()
    name = (name or email or "User").strip()
    user = User.objects.filter(email__iexact=email).first()

    if not user:
        username = email.split("@")[0].replace(".", "_")[:30] or "user"
        base_username = username
        n = 0
        while User.objects.filter(username__iexact=username).exists():
            n += 1
            username = f"{base_username}{n}"[:30]

        with transaction.atomic():
            user = User.objects.create(
                username=username,
                email=email,
                first_name=name[:30],
                is_active=True,
                is_staff=False,
            )
            user.set_unusable_password()
            user.save()
            UserProfile.objects.get_or_create(user=user)
        created = True
    else:
        UserProfile.objects.get_or_create(user=user)
        created = False

    return user, created


def is_donor_profile_complete(user) -> bool:
    """Completed donor = DonorProfile exists with a non-empty blood_group."""
    try:
        profile = user.donor_profile
    except Exception:
        return False
    return bool((profile.blood_group or "").strip())
