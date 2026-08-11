"""Shared login helpers for web forms and mobile API."""
from django.contrib.auth.models import User


def resolve_login_username(identifier: str) -> str:
    """
    Match DonorLoginForm: case-insensitive username or email login.
    Returns the actual User.username for authenticate().
    """
    value = (identifier or '').strip()
    if not value:
        return value

    try:
        return User.objects.get(username__iexact=value).username
    except User.DoesNotExist:
        pass

    try:
        return User.objects.get(email__iexact=value).username
    except User.DoesNotExist:
        pass

    return value


def find_user_by_login_identifier(identifier: str):
    """Resolve username or email (case-insensitive) to a User, or None."""
    value = (identifier or '').strip()
    if not value:
        return None

    user = User.objects.filter(username__iexact=value).first()
    if user:
        return user

    if '@' in value:
        return User.objects.filter(email__iexact=value).first()

    return None


def authenticate_with_identifier(identifier: str, password: str):
    """
    Authenticate by username or email + password.
    Uses check_password so email login works reliably for all registered donors.
    """
    if not password:
        return None

    user = find_user_by_login_identifier(identifier)
    if user is None:
        return None

    if user.check_password(password):
        return user

    return None
