from rest_framework.throttling import AnonRateThrottle


class PasswordResetRateThrottle(AnonRateThrottle):
    """Limit anonymous password-reset requests to reduce abuse."""

    scope = "password_reset"
