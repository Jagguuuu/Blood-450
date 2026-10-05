"""
Mobile password-reset email delivery using Django's PasswordResetTokenGenerator.

Always returns a generic message to callers — never reveals account existence.
"""
import logging

from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.utils.encoding import force_bytes
from django.utils.http import urlsafe_base64_encode

logger = logging.getLogger(__name__)

GENERIC_SUCCESS_MESSAGE = (
    "If an account exists for this email, a password reset link has been sent."
)


def _reset_confirm_url(user: User) -> str:
    uid = urlsafe_base64_encode(force_bytes(user.pk))
    token = default_token_generator.make_token(user)
    base = settings.APP_BASE_URL.rstrip("/")
    return f"{base}/accounts/reset/{uid}/{token}/"


def _active_users_for_email(email: str):
    """Active users with a non-empty email (includes Google-only accounts)."""
    email = (email or "").strip()
    if not email:
        return User.objects.none()
    return User.objects.filter(email__iexact=email, is_active=True).exclude(email="")


def send_password_reset_for_email(email: str) -> int:
    """
    Send reset email(s) for matching active users.
    Returns count of emails sent (for logging/tests only — never expose to clients).
    """
    users = list(_active_users_for_email(email))
    if not users:
        return 0

    sent = 0
    site_name = getattr(settings, "PASSWORD_RESET_SITE_NAME", "Blood450")
    from_email = settings.DEFAULT_FROM_EMAIL

    for user in users:
        reset_url = _reset_confirm_url(user)
        context = {
            "user": user,
            "reset_url": reset_url,
            "site_name": site_name,
        }
        subject = render_to_string(
            "registration/password_reset_subject.txt",
            context,
        ).strip()
        text_body = render_to_string(
            "registration/password_reset_email.txt",
            context,
        )
        html_body = render_to_string(
            "registration/password_reset_email.html",
            context,
        )

        try:
            send_mail(
                subject,
                text_body,
                from_email,
                [user.email],
                html_message=html_body,
                fail_silently=False,
            )
            sent += 1
        except Exception:
            logger.exception(
                "password reset email failed for user_id=%s", user.pk
            )

    return sent


def request_password_reset(email: str) -> str:
    """
    Trigger password reset emails. Always returns the generic success message.
    """
    email = (email or "").strip()
    if email:
        try:
            send_password_reset_for_email(email)
        except Exception:
            logger.exception("password reset request failed")
    return GENERIC_SUCCESS_MESSAGE
