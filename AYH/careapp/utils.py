"""
Distance utilities for location-based donor matching.
Uses Haversine formula (no PostGIS required).
"""
import math
import logging

logger = logging.getLogger(__name__)


def validate_lat_lon(lat, lon):
    """
    Validate latitude and longitude ranges.
    lat must be in [-90, 90], lon in [-180, 180].
    Returns (lat, lon) as float or (None, None) if invalid.
    """
    if lat is None or lon is None:
        return None, None
    try:
        lat_f = float(lat)
        lon_f = float(lon)
    except (TypeError, ValueError):
        return None, None
    if not (-90 <= lat_f <= 90):
        return None, None
    if not (-180 <= lon_f <= 180):
        return None, None
    return lat_f, lon_f


def haversine_km(lat1, lon1, lat2, lon2):
    """
    Compute distance in km between two points using Haversine formula.
    Accepts float or Decimal. Returns float. Uses degrees (not radians) for inputs.
    Validates: lat in [-90, 90], lon in [-180, 180]. Returns None if invalid.
    """
    lat1, lon1 = validate_lat_lon(lat1, lon1)
    lat2, lon2 = validate_lat_lon(lat2, lon2)
    if lat1 is None or lat2 is None:
        return None
    R = 6371  # Earth radius in km
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlam = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlam / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c


def donor_has_location(donor_profile):
    """Return True if donor has valid lat/lng for distance matching."""
    if donor_profile.last_lat is None or donor_profile.last_lng is None:
        return False
    lat_f, lon_f = validate_lat_lon(donor_profile.last_lat, donor_profile.last_lng)
    return lat_f is not None
