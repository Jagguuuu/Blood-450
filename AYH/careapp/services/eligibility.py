"""
Canonical 90-day donor eligibility from last *physical* donation date.

Source of truth: DonorProfile.last_donation_date

Acceptance / DonorResponse.responded_at is NOT a clinical donation date.
"""
from __future__ import annotations

from datetime import date, datetime
from typing import Any, Optional

from django.utils import timezone

# Cooling-off period after a physical blood donation.
COOLING_OFF_DAYS = 90

STATUS_ELIGIBLE = 'eligible'
STATUS_COOLING_OFF = 'cooling_off'
STATUS_UNKNOWN = 'unknown'

VALID_STATUSES = frozenset({STATUS_ELIGIBLE, STATUS_COOLING_OFF, STATUS_UNKNOWN})


def _as_date(value) -> Optional[date]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    return None


def today_local() -> date:
    """Current calendar date in the active Django timezone."""
    return timezone.localdate()


def compute_eligibility(
    last_donation_date,
    *,
    today: Optional[date] = None,
) -> dict[str, Any]:
    """
    Classify donor eligibility from last donation date.

    Boundary rule (date arithmetic, not months):

        days_since = (today - last_donation_date).days

        days_since >= 90  →  eligible
        days_since <  90  →  cooling_off
        no date           →  unknown

    Therefore:
        donation 89 days ago → cooling_off
        donation 90 days ago → eligible
        donation 91 days ago → eligible
    """
    today = today or today_local()
    last = _as_date(last_donation_date)

    if last is None:
        return {
            'last_donation_date': None,
            'eligibility_status': STATUS_UNKNOWN,
            'days_since_last_donation': None,
            'days_until_eligible': None,
            'eligibility_progress': 0.0,
        }

    days_since = (today - last).days
    if days_since < 0:
        # Future date — treat as still in cooling-off with full wait.
        days_since = 0

    if days_since >= COOLING_OFF_DAYS:
        return {
            'last_donation_date': last,
            'eligibility_status': STATUS_ELIGIBLE,
            'days_since_last_donation': days_since,
            'days_until_eligible': 0,
            'eligibility_progress': 1.0,
        }

    days_until = COOLING_OFF_DAYS - days_since
    return {
        'last_donation_date': last,
        'eligibility_status': STATUS_COOLING_OFF,
        'days_since_last_donation': days_since,
        'days_until_eligible': days_until,
        'eligibility_progress': round(days_since / COOLING_OFF_DAYS, 4),
    }


def eligibility_for_donor(donor_profile, *, today: Optional[date] = None) -> dict[str, Any]:
    """Eligibility from canonical DonorProfile.last_donation_date.

    If there is no date but UserProfile.donated_before is explicitly False
    (never donated), treat as eligible for a first donation.
    """
    last = getattr(donor_profile, 'last_donation_date', None) if donor_profile else None
    result = compute_eligibility(last, today=today)
    if result['eligibility_status'] != STATUS_UNKNOWN or donor_profile is None:
        return result

    user = getattr(donor_profile, 'user', None)
    up = getattr(user, 'user_profile', None) if user else None
    if up is None and user is not None:
        try:
            from careapp.models import UserProfile
            up = UserProfile.objects.filter(user=user).first()
        except Exception:
            up = None
    donated_before = getattr(up, 'donated_before', None) if up else None
    if donated_before is False:
        return {
            'last_donation_date': None,
            'eligibility_status': STATUS_ELIGIBLE,
            'days_since_last_donation': None,
            'days_until_eligible': 0,
            'eligibility_progress': 1.0,
        }
    return result


def sync_last_donation_from_user_profile(donor_profile, user_profile=None) -> bool:
    """
    Copy UserProfile.last_donation_date → DonorProfile.last_donation_date
    ONLY when DonorProfile date is empty and UserProfile date is set.

    Returns True if DonorProfile was updated.
    Does not overwrite an existing non-null DonorProfile date.
    """
    if donor_profile is None:
        return False
    if donor_profile.last_donation_date is not None:
        return False

    if user_profile is None:
        user = getattr(donor_profile, 'user', None)
        if user is None:
            return False
        user_profile = getattr(user, 'user_profile', None)
        if user_profile is None:
            try:
                from careapp.models import UserProfile
                user_profile = UserProfile.objects.filter(user=user).first()
            except Exception:
                return False

    up_date = getattr(user_profile, 'last_donation_date', None) if user_profile else None
    if up_date is None:
        return False

    donor_profile.last_donation_date = up_date
    donor_profile.save(update_fields=['last_donation_date'])
    return True


def seed_donor_last_donation(donor_profile, last_donation_date=None, user_profile=None) -> None:
    """
    On donor create/convert: set last_donation_date from explicit value if provided;
    otherwise seed from UserProfile when donor field is empty.
    """
    if donor_profile is None:
        return
    if last_donation_date is not None and donor_profile.last_donation_date is None:
        donor_profile.last_donation_date = _as_date(last_donation_date)
        donor_profile.save(update_fields=['last_donation_date'])
        return
    sync_last_donation_from_user_profile(donor_profile, user_profile=user_profile)
