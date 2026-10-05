"""
Leaderboard calculation from existing DonorResponse acceptance records.

A "donation" for ranking purposes is one DonorResponse with response='accepted'.
unique_together on (blood_request, donor) prevents duplicate counting per request.
"""

from django.contrib.auth.models import User
from django.db.models import Count, Max

from .models import DonorProfile, DonorResponse

LIVES_PER_DONATION = 3


def donor_display_name(user: User) -> str:
    full = (user.get_full_name() or '').strip()
    if full:
        return full
    return user.username


def badge_for_donations(donations: int) -> str:
    """Badge tiers aligned with the approved static leaderboard concepts."""
    if donations >= 20:
        return '🏆 Life Saver'
    if donations >= 15:
        return '💎 Elite Donor'
    if donations >= 10:
        return '⭐ Hero Donor'
    if donations >= 5:
        return '❤️ Community Hero'
    if donations >= 1:
        return '🔥 Active Donor'
    return '🌱 New Donor'


def _serialize_entry(rank: int, user: User, blood_group: str, donations: int) -> dict:
    return {
        'rank': rank,
        'name': donor_display_name(user),
        'blood_group': blood_group or '?',
        'donations': donations,
        'badge': badge_for_donations(donations),
    }


def build_leaderboard_payload(current_user: User) -> dict:
    """
    Rank all donor-profile holders by accepted donation count (desc),
    then most recent acceptance (desc), then stable user id (asc).
    """
    stats_by_donor = {
        row['donor_id']: row
        for row in (
            DonorResponse.objects.filter(response='accepted')
            .values('donor_id')
            .annotate(
                donations=Count('id'),
                last_donation_at=Max('responded_at'),
            )
        )
    }

    profiles = DonorProfile.objects.select_related('user').order_by('user_id')
    ranked = []
    for profile in profiles:
        user = profile.user
        stat = stats_by_donor.get(user.id, {})
        donations = int(stat.get('donations') or 0)
        last_donation_at = stat.get('last_donation_at')
        ranked.append((user, profile.blood_group, donations, last_donation_at))

    ranked.sort(
        key=lambda item: (
            -item[2],
            item[3] is None,
            -(item[3].timestamp() if item[3] else 0),
            item[0].id,
        )
    )

    all_entries = []
    for index, (user, blood_group, donations, _) in enumerate(ranked, start=1):
        all_entries.append(_serialize_entry(index, user, blood_group, donations))

    top_donors = [entry for entry in all_entries if entry['donations'] > 0][:10]

    current_user_payload = None
    try:
        current_user.donor_profile
    except DonorProfile.DoesNotExist:
        profile = None
    else:
        profile = current_user.donor_profile

    if profile is not None:
        entry_by_user_id = {}
        for idx, (user, blood_group, donations, _) in enumerate(ranked, start=1):
            entry_by_user_id[user.id] = _serialize_entry(idx, user, blood_group, donations)

        entry = entry_by_user_id.get(current_user.id)
        if entry is not None:
            current_user_payload = {
                **entry,
                'lives_impacted': entry['donations'] * LIVES_PER_DONATION,
            }

    return {
        'top_donors': top_donors,
        'current_user': current_user_payload,
    }
