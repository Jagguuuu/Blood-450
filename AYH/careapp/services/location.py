"""
Readable location helpers (city/state display) + optional reverse geocoding.

Coordinates (lat/lng) remain the source of truth for Haversine matching.
City/state are display-only and never used for radius matching.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from django.utils import timezone

logger = logging.getLogger(__name__)

NOMINATIM_REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"
# Identify the app; Nominatim requires a valid User-Agent.
_USER_AGENT = "Blood450/1.0 (donor-location; contact=support@blood450.local)"
_TIMEOUT_SEC = 3  # Keep short so donor save/update never hangs on Nominatim


def format_location_display(
    city: Optional[str] = None,
    state: Optional[str] = None,
    *,
    has_coordinates: bool = False,
    prefix: str = "",
) -> str:
    """
    Build a human-readable location string.

    Prefer "City, State". If only city: "City".
    If neither but coordinates exist: "Location available".
    Empty string when nothing is known.
    """
    city_s = (city or "").strip()
    state_s = (state or "").strip()
    if city_s and state_s:
        body = f"{city_s}, {state_s}"
    elif city_s:
        body = city_s
    elif state_s:
        body = state_s
    elif has_coordinates:
        body = "Location available"
    else:
        return ""
    if prefix:
        return f"{prefix}{body}"
    return body


def reverse_geocode(lat: Any, lng: Any) -> dict:
    """
    Reverse-geocode coordinates via Nominatim (same provider as website Google complete-profile).

    Returns dict with keys city, state, area, pincode (empty strings on failure).
    Never raises for network/parse errors.
    """
    empty = {"city": "", "state": "", "area": "", "pincode": ""}
    try:
        lat_f = float(lat)
        lng_f = float(lng)
    except (TypeError, ValueError):
        return empty
    if not (-90 <= lat_f <= 90 and -180 <= lng_f <= 180):
        return empty

    try:
        import requests
        resp = requests.get(
            NOMINATIM_REVERSE_URL,
            params={
                "lat": f"{lat_f:.6f}",
                "lon": f"{lng_f:.6f}",
                "format": "json",
                "addressdetails": 1,
            },
            headers={
                "Accept": "application/json",
                "Accept-Language": "en",
                "User-Agent": _USER_AGENT,
            },
            timeout=_TIMEOUT_SEC,
        )
        if not resp.ok:
            logger.info("Nominatim reverse failed: status=%s", resp.status_code)
            return empty
        data = resp.json() or {}
        addr = data.get("address") or {}
        city = (
            addr.get("city")
            or addr.get("town")
            or addr.get("village")
            or addr.get("municipality")
            or addr.get("county")
            or ""
        )
        state = addr.get("state") or addr.get("region") or ""
        area = (
            addr.get("suburb")
            or addr.get("neighbourhood")
            or addr.get("locality")
            or ""
        )
        pincode = addr.get("postcode") or ""
        return {
            "city": str(city).strip(),
            "state": str(state).strip(),
            "area": str(area).strip(),
            "pincode": str(pincode).strip(),
        }
    except Exception:
        logger.exception("reverse_geocode failed for lat=%s lng=%s", lat, lng)
        return empty


def donor_readable_city_state(donor_profile) -> tuple[str, str]:
    """
    Resolve display city/state for a DonorProfile.

    city: DonorProfile.city, else UserProfile.city
    state: UserProfile.state
    """
    city = (getattr(donor_profile, "city", None) or "").strip()
    state = ""
    user = getattr(donor_profile, "user", None)
    if user is not None:
        try:
            up = user.user_profile
        except Exception:
            up = None
        if up is not None:
            if not city:
                city = (up.city or "").strip()
            state = (up.state or "").strip()
    return city, state


def donor_location_display(donor_profile) -> str:
    """Readable donor location for API/UI (no pin emoji; clients may add their own)."""
    from careapp.utils import donor_has_location

    city, state = donor_readable_city_state(donor_profile)
    return format_location_display(
        city,
        state,
        has_coordinates=donor_has_location(donor_profile),
    )


def blood_request_location_display(blood_request) -> str:
    """Readable request place: location_name preferred, else city/state, else coords flag."""
    name = (getattr(blood_request, "location_name", None) or "").strip()
    city = (getattr(blood_request, "city", None) or "").strip()
    state = (getattr(blood_request, "state", None) or "").strip()
    has_coords = (
        getattr(blood_request, "req_lat", None) is not None
        and getattr(blood_request, "req_lng", None) is not None
    )
    place = format_location_display(city, state, has_coordinates=False)
    if name and place:
        return f"{name} — {place}"
    if name:
        return name
    if place:
        return place
    return format_location_display(None, None, has_coordinates=has_coords)


def apply_reverse_geocode_to_donor(donor_profile, lat=None, lng=None, *, force: bool = False) -> dict:
    """
    Fill DonorProfile.city and linked UserProfile city/state from coordinates.

    Uses last_lat/last_lng when lat/lng not passed.
    Skips overwrite of existing city/state unless force=True (location update → force).
    Returns the geocode dict (may be empty).
    """
    use_lat = lat if lat is not None else donor_profile.last_lat
    use_lng = lng if lng is not None else donor_profile.last_lng
    geo = reverse_geocode(use_lat, use_lng)
    if not geo.get("city") and not geo.get("state"):
        return geo

    update_fields = []
    if geo.get("city") and (force or not (donor_profile.city or "").strip()):
        donor_profile.city = geo["city"]
        update_fields.append("city")
    if update_fields:
        donor_profile.save(update_fields=update_fields)

    user = getattr(donor_profile, "user", None)
    if user is not None:
        from careapp.models import UserProfile

        up, _ = UserProfile.objects.get_or_create(user=user)
        up_fields = []
        if geo.get("city") and (force or not (up.city or "").strip()):
            up.city = geo["city"]
            up_fields.append("city")
        if geo.get("state") and (force or not (up.state or "").strip()):
            up.state = geo["state"]
            up_fields.append("state")
        if geo.get("area") and (force or not (up.area or "").strip()):
            up.area = geo["area"]
            up_fields.append("area")
        if geo.get("pincode") and (force or not (up.pincode or "").strip()):
            up.pincode = geo["pincode"]
            up_fields.append("pincode")
        if up_fields:
            up.updated_at = timezone.now()
            up_fields.append("updated_at")
            up.save(update_fields=up_fields)
    return geo


def apply_reverse_geocode_to_blood_request(blood_request, *, force: bool = False) -> dict:
    """
    Fill BloodRequest.city/state from req_lat/req_lng when missing (or force).
    Does not touch req_lat/req_lng/radius_km.
    """
    if blood_request.req_lat is None or blood_request.req_lng is None:
        return {"city": "", "state": "", "area": "", "pincode": ""}
    geo = reverse_geocode(blood_request.req_lat, blood_request.req_lng)
    fields = []
    if geo.get("city") and (force or not (blood_request.city or "").strip()):
        blood_request.city = geo["city"]
        fields.append("city")
    if geo.get("state") and (force or not (blood_request.state or "").strip()):
        blood_request.state = geo["state"]
        fields.append("state")
    if fields:
        blood_request.save(update_fields=fields)
    return geo
