"""
API Serializers for Blood Donation System
Converts Django models to/from JSON for REST API
"""

from rest_framework import serializers
from django.contrib.auth.models import User
from .models import DonorProfile, BloodRequest, Notification, DonorResponse


# ==============================================================================
# USER SERIALIZERS
# ==============================================================================

class UserSerializer(serializers.ModelSerializer):
    """Basic user information"""
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'is_staff']
        read_only_fields = ['id', 'is_staff']


class UserRegistrationSerializer(serializers.ModelSerializer):
    """User registration with password + optional full donor profile (mobile one-go signup)."""
    password = serializers.CharField(write_only=True, min_length=8, style={'input_type': 'password'})
    password_confirm = serializers.CharField(write_only=True, min_length=8, style={'input_type': 'password'})
    phone = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=15)
    blood_group = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=5)
    gender = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=1)
    is_available = serializers.BooleanField(write_only=True, required=False, default=True)
    last_lat = serializers.FloatField(write_only=True, required=False, allow_null=True)
    last_lng = serializers.FloatField(write_only=True, required=False, allow_null=True)
    city = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=100)
    last_donation_date = serializers.DateField(write_only=True, required=False, allow_null=True)
    donated_before = serializers.BooleanField(write_only=True, required=False, allow_null=True)
    medical_conditions = serializers.BooleanField(write_only=True, required=False, allow_null=True)
    currently_healthy = serializers.BooleanField(write_only=True, required=False, allow_null=True)
    emergency_available = serializers.BooleanField(write_only=True, required=False, default=True)
    preferred_contact = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=20)
    consent_contact = serializers.BooleanField(write_only=True, required=False, default=False)
    consent_terms = serializers.BooleanField(write_only=True, required=False, default=False)

    class Meta:
        model = User
        fields = [
            'username', 'email', 'password', 'password_confirm', 'first_name', 'last_name',
            'phone', 'blood_group', 'gender', 'is_available', 'last_lat', 'last_lng', 'city',
            'last_donation_date', 'donated_before', 'medical_conditions', 'currently_healthy',
            'emergency_available', 'preferred_contact', 'consent_contact', 'consent_terms',
        ]

    def validate_blood_group(self, value):
        value = (value or '').strip()
        if not value:
            return ''
        from .models import DonorProfile
        if value not in dict(DonorProfile.BLOOD_GROUP_CHOICES):
            raise serializers.ValidationError('Invalid blood group.')
        return value

    def validate_phone(self, value):
        phone = (value or '').strip().replace(' ', '')
        if not phone:
            return ''
        digits = ''.join(c for c in phone if c.isdigit())
        if len(digits) < 10:
            raise serializers.ValidationError('Enter a valid mobile number (at least 10 digits).')
        normalized = digits
        if len(digits) == 12 and digits.startswith('91'):
            normalized = digits[2:]
        elif len(digits) > 12:
            normalized = digits[-10:] if digits.startswith('91') else digits
        from .models import DonorProfile
        if DonorProfile.objects.filter(phone=normalized).exists() or DonorProfile.objects.filter(phone=digits).exists():
            raise serializers.ValidationError('This mobile number is already registered.')
        return normalized

    def validate(self, data):
        """Validate password match and email availability."""
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError({"password": "Passwords must match."})

        email = (data.get('email') or '').strip()
        if email:
            existing = User.objects.filter(email__iexact=email).first()
            if existing and existing.has_usable_password():
                raise serializers.ValidationError(
                    {"email": "This email is already registered. Please log in instead."}
                )

        # Full donor signup requires phone + blood group together.
        phone = (data.get('phone') or '').strip()
        blood_group = (data.get('blood_group') or '').strip()
        if phone and not blood_group:
            raise serializers.ValidationError({"blood_group": "Blood group is required with phone."})
        if blood_group and not phone:
            raise serializers.ValidationError({"phone": "Phone is required with blood group."})
        return data

    def create(self, validated_data):
        """Create user with hashed password and optional complete donor/user profiles."""
        from django.utils import timezone
        from .models import DonorProfile, UserProfile
        from .services.location import apply_reverse_geocode_to_donor

        validated_data.pop('password_confirm')
        phone = (validated_data.pop('phone', None) or '').strip()
        blood_group = (validated_data.pop('blood_group', None) or '').strip() or None
        gender = (validated_data.pop('gender', None) or '').strip().upper() or None
        if gender and gender not in dict(UserProfile.GENDER_CHOICES):
            gender = None
        is_available = validated_data.pop('is_available', True)
        last_lat = validated_data.pop('last_lat', None)
        last_lng = validated_data.pop('last_lng', None)
        # GPS often has >6 decimals; DB columns are decimal_places=6.
        from decimal import Decimal, ROUND_HALF_UP
        def _coord6(v):
            if v is None:
                return None
            return Decimal(str(v)).quantize(Decimal('0.000001'), rounding=ROUND_HALF_UP)
        last_lat = _coord6(last_lat)
        last_lng = _coord6(last_lng)
        if last_lat is not None and (last_lat < -90 or last_lat > 90):
            raise serializers.ValidationError({'last_lat': 'Latitude must be between -90 and 90'})
        if last_lng is not None and (last_lng < -180 or last_lng > 180):
            raise serializers.ValidationError({'last_lng': 'Longitude must be between -180 and 180'})
        city = (validated_data.pop('city', None) or '').strip()
        last_donation_date = validated_data.pop('last_donation_date', None)
        donated_before = validated_data.pop('donated_before', None)
        medical_conditions = validated_data.pop('medical_conditions', None)
        currently_healthy = validated_data.pop('currently_healthy', None)
        emergency_available = validated_data.pop('emergency_available', True)
        preferred_contact = (validated_data.pop('preferred_contact', None) or 'call').strip() or 'call'
        if preferred_contact not in dict(UserProfile.CONTACT_METHOD_CHOICES):
            preferred_contact = 'call'
        consent_contact = bool(validated_data.pop('consent_contact', False))
        consent_terms = bool(validated_data.pop('consent_terms', False))

        password = validated_data['password']
        email = (validated_data.get('email') or '').strip()

        existing = User.objects.filter(email__iexact=email).first() if email else None
        if existing and not existing.has_usable_password():
            existing.set_password(password)
            if validated_data.get('first_name'):
                existing.first_name = validated_data['first_name']
            if validated_data.get('last_name'):
                existing.last_name = validated_data['last_name']
            existing.save()
            user = existing
        else:
            user = User.objects.create_user(
                username=validated_data['username'],
                email=validated_data.get('email', ''),
                password=password,
                first_name=validated_data.get('first_name', ''),
                last_name=validated_data.get('last_name', '')
            )

        UserProfile.objects.update_or_create(
            user=user,
            defaults={
                'gender': gender,
                'city': city,
                'donated_before': donated_before,
                'last_donation_date': last_donation_date,
                'medical_conditions': medical_conditions,
                'currently_healthy': currently_healthy,
                'emergency_available': emergency_available if emergency_available is not None else True,
                'preferred_contact': preferred_contact,
                'consent_contact': consent_contact,
                'consent_terms': consent_terms,
            },
        )

        if phone or blood_group:
            coords_ok = last_lat is not None and last_lng is not None
            profile, created = DonorProfile.objects.get_or_create(
                user=user,
                defaults={
                    'phone': phone,
                    'blood_group': blood_group,
                    'is_available': is_available if is_available is not None else True,
                    'city': city,
                    'last_lat': last_lat,
                    'last_lng': last_lng,
                    'location_updated_at': timezone.now() if coords_ok else None,
                    'last_donation_date': last_donation_date,
                    'phone_verified': False,
                },
            )
            if not created:
                if phone:
                    profile.phone = phone
                if blood_group:
                    profile.blood_group = blood_group
                profile.is_available = is_available if is_available is not None else profile.is_available
                if city:
                    profile.city = city
                if last_donation_date is not None:
                    profile.last_donation_date = last_donation_date
                if coords_ok:
                    profile.last_lat = last_lat
                    profile.last_lng = last_lng
                    profile.location_updated_at = timezone.now()
                profile.save()
            if coords_ok:
                try:
                    apply_reverse_geocode_to_donor(profile, last_lat, last_lng, force=True)
                except Exception:
                    import logging
                    logging.getLogger(__name__).exception(
                        'reverse geocode after register create failed'
                    )
        return user


# ==============================================================================
# DONOR PROFILE SERIALIZERS
# ==============================================================================

class DonorProfileSerializer(serializers.ModelSerializer):
    """Donor profile with user information"""
    user = UserSerializer(read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    city = serializers.SerializerMethodField()
    state = serializers.SerializerMethodField()
    location_display = serializers.SerializerMethodField()
    eligibility_status = serializers.SerializerMethodField()
    days_since_last_donation = serializers.SerializerMethodField()
    days_until_eligible = serializers.SerializerMethodField()

    class Meta:
        model = DonorProfile
        fields = [
            'id',
            'user',
            'username',
            'phone',
            'blood_group',
            'is_available',
            'created_at',
            'last_lat',
            'last_lng',
            'location_updated_at',
            'city',
            'state',
            'location_display',
            'last_donation_date',
            'eligibility_status',
            'days_since_last_donation',
            'days_until_eligible',
        ]
        read_only_fields = [
            'id',
            'created_at',
            'city',
            'state',
            'location_display',
            'eligibility_status',
            'days_since_last_donation',
            'days_until_eligible',
        ]

    def _eligibility(self, obj):
        from .services.eligibility import eligibility_for_donor
        cache = getattr(self, '_eligibility_cache', None)
        if cache is None:
            cache = {}
            setattr(self, '_eligibility_cache', cache)
        key = getattr(obj, 'pk', id(obj))
        if key not in cache:
            cache[key] = eligibility_for_donor(obj)
        return cache[key]

    def get_city(self, obj):
        from .services.location import donor_readable_city_state
        city, _ = donor_readable_city_state(obj)
        return city or None

    def get_state(self, obj):
        from .services.location import donor_readable_city_state
        _, state = donor_readable_city_state(obj)
        return state or None

    def get_location_display(self, obj):
        from .services.location import donor_location_display
        return donor_location_display(obj) or None

    def get_eligibility_status(self, obj):
        return self._eligibility(obj)['eligibility_status']

    def get_days_since_last_donation(self, obj):
        return self._eligibility(obj)['days_since_last_donation']

    def get_days_until_eligible(self, obj):
        return self._eligibility(obj)['days_until_eligible']


class DonorProfileCreateSerializer(serializers.ModelSerializer):
    """Create/Update donor profile"""
    # Accept full GPS precision; quantize to DB decimal_places=6 in validators.
    last_lat = serializers.FloatField(required=False, allow_null=True)
    last_lng = serializers.FloatField(required=False, allow_null=True)

    class Meta:
        model = DonorProfile
        fields = [
            'phone',
            'blood_group',
            'is_available',
            'last_lat',
            'last_lng',
            'city',
            'last_donation_date',
        ]
    
    def create(self, validated_data):
        """Set location_updated_at when creating with last_lat/last_lng; reverse-geocode city/state."""
        from django.utils import timezone
        from .services.eligibility import sync_last_donation_from_user_profile
        from .services.location import apply_reverse_geocode_to_donor
        coords_provided = (
            validated_data.get('last_lat') is not None
            and validated_data.get('last_lng') is not None
        )
        if coords_provided:
            validated_data['location_updated_at'] = timezone.now()
        instance = super().create(validated_data)
        # Seed from UserProfile only when client did not send a date.
        if instance.last_donation_date is None:
            sync_last_donation_from_user_profile(instance)
            instance.refresh_from_db()
        if coords_provided:
            # Best-effort display fields — never fail profile create if geocode fails.
            try:
                apply_reverse_geocode_to_donor(
                    instance,
                    validated_data.get('last_lat'),
                    validated_data.get('last_lng'),
                    force=True,
                )
                instance.refresh_from_db()
            except Exception:
                import logging
                logging.getLogger(__name__).exception(
                    'reverse geocode after donor create failed'
                )
        return instance
    
    def update(self, instance, validated_data):
        """Set location_updated_at when last_lat/last_lng change; reverse-geocode city/state."""
        from django.utils import timezone
        from .services.location import apply_reverse_geocode_to_donor
        coords_changing = (
            'last_lat' in validated_data or 'last_lng' in validated_data
        )
        if coords_changing:
            validated_data['location_updated_at'] = timezone.now()
        instance = super().update(instance, validated_data)
        if coords_changing and instance.last_lat is not None and instance.last_lng is not None:
            # Best-effort — coords are already saved; city/state are display-only.
            try:
                apply_reverse_geocode_to_donor(
                    instance,
                    instance.last_lat,
                    instance.last_lng,
                    force=True,
                )
                instance.refresh_from_db()
            except Exception:
                import logging
                logging.getLogger(__name__).exception(
                    'reverse geocode after donor update failed'
                )
        return instance
    
    def validate_phone(self, value):
        """Accept any non-empty phone (allow all formats)."""
        if not value or not str(value).strip():
            raise serializers.ValidationError("Phone number is required")
        return str(value).strip()
    
    def validate_last_lat(self, value):
        """Round GPS and ensure latitude is between -90 and 90."""
        if value is None:
            return None
        from decimal import Decimal, ROUND_HALF_UP
        value = Decimal(str(value)).quantize(Decimal('0.000001'), rounding=ROUND_HALF_UP)
        if value < -90 or value > 90:
            raise serializers.ValidationError("Latitude must be between -90 and 90")
        return value

    def validate_last_lng(self, value):
        """Round GPS and ensure longitude is between -180 and 180."""
        if value is None:
            return None
        from decimal import Decimal, ROUND_HALF_UP
        value = Decimal(str(value)).quantize(Decimal('0.000001'), rounding=ROUND_HALF_UP)
        if value < -180 or value > 180:
            raise serializers.ValidationError("Longitude must be between -180 and 180")
        return value


class DonorProfileListSerializer(serializers.ModelSerializer):
    """Simplified donor list for admin (Sprint 3 prep: eligibility fields included)."""
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    city = serializers.SerializerMethodField()
    state = serializers.SerializerMethodField()
    location_display = serializers.SerializerMethodField()
    eligibility_status = serializers.SerializerMethodField()
    has_location = serializers.SerializerMethodField()
    profile_complete = serializers.SerializerMethodField()

    class Meta:
        model = DonorProfile
        fields = [
            'id',
            'username',
            'email',
            'phone',
            'blood_group',
            'is_available',
            'created_at',
            'last_lat',
            'last_lng',
            'location_updated_at',
            'city',
            'state',
            'location_display',
            'last_donation_date',
            'eligibility_status',
            'has_location',
            'profile_complete',
        ]

    def _eligibility(self, obj):
        from .services.eligibility import eligibility_for_donor
        cache = getattr(self, '_eligibility_cache', None)
        if cache is None:
            cache = {}
            setattr(self, '_eligibility_cache', cache)
        key = getattr(obj, 'pk', id(obj))
        if key not in cache:
            cache[key] = eligibility_for_donor(obj)
        return cache[key]

    def get_city(self, obj):
        from .services.location import donor_readable_city_state
        city, _ = donor_readable_city_state(obj)
        return city or None

    def get_state(self, obj):
        from .services.location import donor_readable_city_state
        _, state = donor_readable_city_state(obj)
        return state or None

    def get_location_display(self, obj):
        from .services.location import donor_location_display
        return donor_location_display(obj) or None

    def get_eligibility_status(self, obj):
        return self._eligibility(obj)['eligibility_status']

    def get_has_location(self, obj):
        return obj.last_lat is not None and obj.last_lng is not None

    def get_profile_complete(self, obj):
        phone_ok = bool((obj.phone or '').strip())
        blood_ok = bool(obj.blood_group)
        return phone_ok and blood_ok


# ==============================================================================
# BLOOD REQUEST SERIALIZERS
# ==============================================================================

class BloodRequestSerializer(serializers.ModelSerializer):
    """Blood request with creator information"""
    created_by_username = serializers.CharField(source='created_by.username', read_only=True)
    notified_count = serializers.SerializerMethodField()
    accepted_count = serializers.SerializerMethodField()
    urgency_display = serializers.CharField(source='get_urgency_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    location_display = serializers.SerializerMethodField()

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'blood_group',
            'units_needed',
            'urgency',
            'urgency_display',
            'note',
            'created_by',
            'created_by_username',
            'is_active',
            'status',
            'status_display',
            'closed_at',
            'closure_reason',
            'closure_type',
            'created_at',
            'notified_count',
            'accepted_count',
            'req_lat',
            'req_lng',
            'location_name',
            'city',
            'state',
            'location_display',
            'radius_km',
        ]
        read_only_fields = [
            'id', 'created_by', 'created_at', 'status', 'status_display',
            'closed_at', 'closure_reason', 'closure_type', 'location_display',
        ]

    def get_notified_count(self, obj):
        """Count of notified donors"""
        return obj.notifications.count()

    def get_accepted_count(self, obj):
        """Count of donors who accepted"""
        return obj.responses.filter(response='accepted').count()

    def get_location_display(self, obj):
        from .services.location import blood_request_location_display
        return blood_request_location_display(obj) or None


class BloodRequestCreateSerializer(serializers.ModelSerializer):
    """Create blood request (optionally with location for distance-based matching)"""

    class Meta:
        model = BloodRequest
        fields = [
            'blood_group', 'units_needed', 'urgency', 'note',
            'req_lat', 'req_lng', 'location_name', 'city', 'state', 'radius_km',
        ]

    def validate_units_needed(self, value):
        """Validate units is positive"""
        if value < 1:
            raise serializers.ValidationError("Units needed must be at least 1")
        if value > 10:
            raise serializers.ValidationError("Units needed cannot exceed 10")
        return value

    def validate_radius_km(self, value):
        """Validate radius is positive and reasonable. Default from settings if not provided."""
        from django.conf import settings
        if value is None:
            return getattr(settings, 'DEFAULT_RADIUS_KM', 10)
        if value < 0.1 or value > 500:
            raise serializers.ValidationError("Radius must be between 0.1 and 500 km")
        return value

    def validate_req_lat(self, value):
        """Latitude must be between -90 and 90 when provided."""
        if value is not None and (value < -90 or value > 90):
            raise serializers.ValidationError("Latitude must be between -90 and 90")
        return value

    def validate_req_lng(self, value):
        """Longitude must be between -180 and 180 when provided."""
        if value is not None and (value < -180 or value > 180):
            raise serializers.ValidationError("Longitude must be between -180 and 180")
        return value

    def validate(self, attrs):
        """If any location field is set, both req_lat and req_lng are required. Default radius from settings."""
        from django.conf import settings
        req_lat = attrs.get('req_lat')
        req_lng = attrs.get('req_lng')
        location_name = attrs.get('location_name') or ''
        radius_km = attrs.get('radius_km')
        if req_lat is not None and req_lng is not None and (radius_km is None or radius_km <= 0):
            attrs['radius_km'] = getattr(settings, 'DEFAULT_RADIUS_KM', 10)
        has_any = (
            req_lat is not None or req_lng is not None or
            (isinstance(location_name, str) and location_name.strip()) or
            (radius_km is not None and radius_km != 0)
        )
        if has_any and (req_lat is None or req_lng is None):
            raise serializers.ValidationError(
                "When using location-based matching, both req_lat and req_lng are required. "
                "Provide request latitude and longitude (e.g. hospital/camp location)."
            )
        return attrs

    def create(self, validated_data):
        """Create request; fill city/state from coords when missing (display only)."""
        from .services.location import apply_reverse_geocode_to_blood_request
        instance = super().create(validated_data)
        if (
            instance.req_lat is not None
            and instance.req_lng is not None
            and (not (instance.city or '').strip() or not (instance.state or '').strip())
        ):
            apply_reverse_geocode_to_blood_request(instance, force=False)
            instance.refresh_from_db()
        return instance


class BloodRequestDetailSerializer(serializers.ModelSerializer):
    """Detailed blood request with responses"""
    created_by = UserSerializer(read_only=True)
    notified_donors = serializers.SerializerMethodField()
    accepted_donors = serializers.SerializerMethodField()
    urgency_display = serializers.CharField(source='get_urgency_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    location_display = serializers.SerializerMethodField()

    class Meta:
        model = BloodRequest
        fields = [
            'id',
            'blood_group',
            'units_needed',
            'urgency',
            'urgency_display',
            'note',
            'created_by',
            'is_active',
            'status',
            'status_display',
            'closed_at',
            'closure_reason',
            'closure_type',
            'created_at',
            'req_lat',
            'req_lng',
            'location_name',
            'city',
            'state',
            'location_display',
            'radius_km',
            'notified_donors',
            'accepted_donors'
        ]

    def get_location_display(self, obj):
        from .services.location import blood_request_location_display
        return blood_request_location_display(obj) or None
    
    def get_notified_donors(self, obj):
        """List of notified donors (with distance_km when request has location)"""
        from .utils import haversine_km
        notifications = obj.notifications.select_related('user__donor_profile').all()
        result = []
        for n in notifications:
            entry = {
                'id': n.user.id,
                'username': n.user.username,
                'blood_group': n.user.donor_profile.blood_group if hasattr(n.user, 'donor_profile') else None,
                'notified_at': n.created_at,
            }
            if obj.req_lat is not None and obj.req_lng is not None and hasattr(n.user, 'donor_profile'):
                prof = n.user.donor_profile
                if prof.last_lat is not None and prof.last_lng is not None:
                    dist = haversine_km(obj.req_lat, obj.req_lng, prof.last_lat, prof.last_lng)
                    entry['distance_km'] = round(dist, 2) if dist is not None else None
            result.append(entry)
        return result
    
    def get_accepted_donors(self, obj):
        """List of donors who accepted (with distance_km when request has location)"""
        from .utils import haversine_km
        responses = obj.responses.filter(response='accepted').select_related('donor__donor_profile')
        result = []
        for r in responses:
            donor = r.donor
            full_name = f"{(donor.first_name or '').strip()} {(donor.last_name or '').strip()}".strip()
            entry = {
                'id': donor.id,
                'username': donor.username,
                'first_name': donor.first_name or '',
                'last_name': donor.last_name or '',
                'full_name': full_name or donor.username,
                'phone': donor.donor_profile.phone if hasattr(donor, 'donor_profile') else None,
                'blood_group': donor.donor_profile.blood_group if hasattr(donor, 'donor_profile') else None,
                'responded_at': r.responded_at,
            }
            if obj.req_lat is not None and obj.req_lng is not None and hasattr(donor, 'donor_profile'):
                prof = donor.donor_profile
                if prof.last_lat is not None and prof.last_lng is not None:
                    dist = haversine_km(obj.req_lat, obj.req_lng, prof.last_lat, prof.last_lng)
                    entry['distance_km'] = round(dist, 2) if dist is not None else None
            result.append(entry)
        return result


# ==============================================================================
# NOTIFICATION SERIALIZERS
# ==============================================================================

class NotificationSerializer(serializers.ModelSerializer):
    """Notification with blood request details"""
    blood_request = BloodRequestSerializer(read_only=True)
    has_responded = serializers.SerializerMethodField()
    response_status = serializers.SerializerMethodField()
    responded_at = serializers.SerializerMethodField()
    distance_km = serializers.SerializerMethodField()
    
    class Meta:
        model = Notification
        fields = [
            'id',
            'blood_request',
            'is_read',
            'created_at',
            'has_responded',
            'response_status',
            'responded_at',
            'distance_km',
        ]
        read_only_fields = ['id', 'created_at']
    
    def get_distance_km(self, obj):
        """Distance from request location to current donor's location (for display on donor app)."""
        from .utils import haversine_km
        req = obj.blood_request
        if req.req_lat is None or req.req_lng is None:
            return None
        user = self.context.get('request').user if self.context.get('request') else None
        if not user or not hasattr(user, 'donor_profile'):
            return None
        prof = user.donor_profile
        if prof.last_lat is None or prof.last_lng is None:
            return None
        dist = haversine_km(req.req_lat, req.req_lng, prof.last_lat, prof.last_lng)
        return round(dist, 2) if dist is not None else None
    
    def get_has_responded(self, obj):
        """Check if donor has responded"""
        user = self.context.get('request').user if self.context.get('request') else None
        if user:
            return DonorResponse.objects.filter(
                blood_request=obj.blood_request,
                donor=user
            ).exists()
        return False
    
    def get_response_status(self, obj):
        """Get donor's response status"""
        user = self.context.get('request').user if self.context.get('request') else None
        if user:
            try:
                response = DonorResponse.objects.get(
                    blood_request=obj.blood_request,
                    donor=user
                )
                return response.response
            except DonorResponse.DoesNotExist:
                return None
        return None
    
    def get_responded_at(self, obj):
        """Get date donor responded"""
        user = self.context.get('request').user if self.context.get('request') else None
        if user:
            try:
                response = DonorResponse.objects.get(
                    blood_request=obj.blood_request,
                    donor=user
                )
                return response.responded_at
            except DonorResponse.DoesNotExist:
                return None
        return None


# ==============================================================================
# DONOR RESPONSE SERIALIZERS
# ==============================================================================

class DonorResponseSerializer(serializers.ModelSerializer):
    """Donor response to blood request"""
    donor = UserSerializer(read_only=True)
    blood_request = BloodRequestSerializer(read_only=True)
    response_display = serializers.CharField(source='get_response_display', read_only=True)
    
    class Meta:
        model = DonorResponse
        fields = [
            'id',
            'blood_request',
            'donor',
            'response',
            'response_display',
            'responded_at'
        ]
        read_only_fields = ['id', 'donor', 'responded_at']


class DonorResponseCreateSerializer(serializers.ModelSerializer):
    """Create donor response"""
    
    class Meta:
        model = DonorResponse
        fields = ['blood_request', 'response']
    
    def validate_response(self, value):
        """Validate response value"""
        if value not in ['accepted', 'rejected']:
            raise serializers.ValidationError("Response must be 'accepted' or 'rejected'")
        return value
    
    def validate(self, data):
        """Check if donor already responded"""
        user = self.context['request'].user
        blood_request = data['blood_request']
        
        if DonorResponse.objects.filter(blood_request=blood_request, donor=user).exists():
            raise serializers.ValidationError("You have already responded to this request")
        
        return data


# ==============================================================================
# DASHBOARD SERIALIZERS
# ==============================================================================

class DashboardStatsSerializer(serializers.Serializer):
    """Admin dashboard statistics"""
    total_requests = serializers.IntegerField()
    active_requests = serializers.IntegerField()
    total_donors = serializers.IntegerField()
    available_donors = serializers.IntegerField()
    total_accepted = serializers.IntegerField()
    critical_requests = serializers.IntegerField()
    recent_requests = BloodRequestSerializer(many=True)


# ==============================================================================
# LEADERBOARD SERIALIZERS
# ==============================================================================

class LeaderboardDonorSerializer(serializers.Serializer):
    rank = serializers.IntegerField()
    name = serializers.CharField()
    blood_group = serializers.CharField()
    donations = serializers.IntegerField()
    badge = serializers.CharField()


class LeaderboardCurrentUserSerializer(LeaderboardDonorSerializer):
    lives_impacted = serializers.IntegerField()


class LeaderboardResponseSerializer(serializers.Serializer):
    top_donors = LeaderboardDonorSerializer(many=True)
    current_user = LeaderboardCurrentUserSerializer(allow_null=True)
