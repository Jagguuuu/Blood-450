"""
Active / Standby donor pool: assign donors by distance, promote standby when active rejects.
Works alongside existing Notification/DonorResponse; does not replace them.
"""
import logging
from django.db import transaction
from django.utils import timezone

from .models import (
    BloodRequest,
    DonorProfile,
    RequestDonorPoolAssignment,
    RequestTimeline,
    Notification,
)

logger = logging.getLogger(__name__)

# Config: number of active and standby donors per request (when location-based)
ACTIVE_TARGET = 5
STANDBY_TARGET = 10
# Max radius for refill when pulling new standby (km)
REFILL_RADIUS_MULTIPLIER = 1.5  # e.g. 1.5 * request.radius_km


def create_request_and_assign_donors(blood_request, donor_distance_list, haversine_km_fn):
    """
    After request is created with location: assign donors to ACTIVE and STANDBY pools.
    donor_distance_list: list of (DonorProfile, distance_km) sorted by distance ascending.
    Does not create notifications (existing flow does that); only creates RequestDonorPoolAssignment.
    """
    if not donor_distance_list or blood_request.req_lat is None or blood_request.req_lng is None:
        return
    with transaction.atomic():
        seen = set()
        rank = 0
        active_count = 0
        standby_count = 0
        for donor_profile, dist_km in donor_distance_list:
            if donor_profile.user_id in seen:
                continue
            if active_count < ACTIVE_TARGET:
                pool_type = RequestDonorPoolAssignment.POOL_TYPE_ACTIVE
                active_count += 1
            elif standby_count < STANDBY_TARGET:
                pool_type = RequestDonorPoolAssignment.POOL_TYPE_STANDBY
                standby_count += 1
            else:
                break
            RequestDonorPoolAssignment.objects.create(
                request=blood_request,
                donor=donor_profile.user,
                distance_km=round(dist_km, 4),
                pool_type=pool_type,
                state=RequestDonorPoolAssignment.STATE_PENDING,
                rank=rank,
            )
            rank += 1
            seen.add(donor_profile.user_id)
        logger.info(
            "donor_pool: request_id=%s assigned active=%s standby=%s",
            blood_request.id, active_count, standby_count,
        )


def _refill_standby(blood_request, haversine_km_fn):
    """Pull next nearest donors not already in pool and add as STANDBY until STANDBY_TARGET reached."""
    from .views import get_compatible_blood_groups
    from .utils import donor_has_location

    current_standby = RequestDonorPoolAssignment.objects.filter(
        request=blood_request,
        pool_type=RequestDonorPoolAssignment.POOL_TYPE_STANDBY,
    ).count()
    if current_standby >= STANDBY_TARGET:
        return
    assigned_donor_ids = set(
        RequestDonorPoolAssignment.objects.filter(request=blood_request).values_list('donor_id', flat=True)
    )
    req_lat = float(blood_request.req_lat)
    req_lng = float(blood_request.req_lng)
    radius_km = float(blood_request.radius_km or 50) * REFILL_RADIUS_MULTIPLIER
    compatible = get_compatible_blood_groups(blood_request.blood_group)
    candidates = []
    for dp in DonorProfile.objects.filter(
        blood_group__in=compatible,
        is_available=True,
    ).select_related('user'):
        if dp.user_id in assigned_donor_ids:
            continue
        if not donor_has_location(dp):
            continue
        try:
            d = haversine_km_fn(req_lat, req_lng, float(dp.last_lat), float(dp.last_lng))
            if d is not None and d <= radius_km:
                candidates.append((dp, round(d, 4)))
        except (TypeError, ValueError):
            continue
    candidates.sort(key=lambda x: x[1])
    next_rank = RequestDonorPoolAssignment.objects.filter(request=blood_request).order_by('-rank').values_list('rank', flat=True).first() or 0
    added = 0
    for donor_profile, dist_km in candidates:
        if current_standby + added >= STANDBY_TARGET:
            break
        if donor_profile.user_id in assigned_donor_ids:
            continue
        next_rank += 1
        RequestDonorPoolAssignment.objects.create(
            request=blood_request,
            donor=donor_profile.user,
            distance_km=dist_km,
            pool_type=RequestDonorPoolAssignment.POOL_TYPE_STANDBY,
            state=RequestDonorPoolAssignment.STATE_PENDING,
            rank=next_rank,
        )
        assigned_donor_ids.add(donor_profile.user_id)
        added += 1
    if added:
        logger.info("donor_pool: request_id=%s refilled standby by %s", blood_request.id, added)


def promote_standby_to_active(blood_request_id, haversine_km_fn=None):
    """
    When an active donor rejects/times out/drops: promote nearest standby to active and refill standby.
    Call with select_for_update on request to avoid race conditions (caller can lock).
    """
    from .utils import haversine_km
    haversine_km_fn = haversine_km_fn or haversine_km

    with transaction.atomic():
        blood_request = BloodRequest.objects.select_for_update().get(id=blood_request_id)
        # Count active in PENDING or ACCEPTED (we want to maintain ACTIVE_TARGET)
        active_ok = RequestDonorPoolAssignment.objects.filter(
            request=blood_request,
            pool_type=RequestDonorPoolAssignment.POOL_TYPE_ACTIVE,
            state__in=(RequestDonorPoolAssignment.STATE_PENDING, RequestDonorPoolAssignment.STATE_ACCEPTED),
        ).count()
        while active_ok < ACTIVE_TARGET:
            next_standby = (
                RequestDonorPoolAssignment.objects.filter(
                    request=blood_request,
                    pool_type=RequestDonorPoolAssignment.POOL_TYPE_STANDBY,
                    state=RequestDonorPoolAssignment.STATE_PENDING,
                ).order_by('rank').first()
            )
            if not next_standby:
                logger.info("donor_pool: request_id=%s no standby to promote", blood_request_id)
                break
            next_standby.pool_type = RequestDonorPoolAssignment.POOL_TYPE_ACTIVE
            next_standby.notified_at = timezone.now()
            next_standby.save(update_fields=['pool_type', 'notified_at'])
            RequestTimeline.objects.create(
                request=blood_request,
                event_type='STANDBY_PROMOTED',
                actor='SYSTEM',
                metadata={'donor_id': next_standby.donor_id, 'donor_username': next_standby.donor.username},
            )
            # Optionally send notification to promoted donor (existing Notification may already exist)
            if not Notification.objects.filter(blood_request=blood_request, user=next_standby.donor).exists():
                try:
                    Notification.objects.create(user=next_standby.donor, blood_request=blood_request)
                    from .whatsapp_integration import trigger_standby_promotion_whatsapp
                    trigger_standby_promotion_whatsapp(next_standby.donor, blood_request)
                except Exception:
                    pass
            active_ok += 1
            logger.info("donor_pool: request_id=%s promoted donor_id=%s to ACTIVE", blood_request_id, next_standby.donor_id)
        _refill_standby(blood_request, haversine_km_fn)


def handle_donor_response_for_pool(blood_request_id, donor_id, response_accepted, haversine_km_fn=None):
    """
    Update pool assignment state when donor responds. On REJECT, trigger promotion.
    response_accepted: True for accept, False for reject.
    """
    from .utils import haversine_km
    haversine_km_fn = haversine_km_fn or haversine_km

    assignment = RequestDonorPoolAssignment.objects.filter(
        request_id=blood_request_id,
        donor_id=donor_id,
    ).first()
    if not assignment:
        return
    now = timezone.now()
    assignment.responded_at = now
    assignment.state = RequestDonorPoolAssignment.STATE_ACCEPTED if response_accepted else RequestDonorPoolAssignment.STATE_REJECTED
    assignment.save(update_fields=['state', 'responded_at'])
    if not response_accepted and assignment.pool_type == RequestDonorPoolAssignment.POOL_TYPE_ACTIVE:
        promote_standby_to_active(blood_request_id, haversine_km_fn)
