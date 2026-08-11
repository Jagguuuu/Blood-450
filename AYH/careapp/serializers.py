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
    """User registration with password"""
    password = serializers.CharField(write_only=True, min_length=8, style={'input_type': 'password'})
    password_confirm = serializers.CharField(write_only=True, min_length=8, style={'input_type': 'password'})
    phone = serializers.CharField(write_only=True, required=False, allow_blank=True, max_length=15)
    
    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'password_confirm', 'first_name', 'last_name', 'phone']
    
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
        return data
    
    def create(self, validated_data):
        """Create user with hashed password, or set password on Google-only account."""
        validated_data.pop('password_confirm')
        phone = (validated_data.pop('phone', None) or '').strip()
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

        if phone:
            from .models import DonorProfile
            profile, _ = DonorProfile.objects.get_or_create(user=user, defaults={'phone': phone})
            if not profile.phone:
                profile.phone = phone
                profile.save(update_fields=['phone'])
        return user


# ==============================================================================
# DONOR PROFILE SERIALIZERS
# ==============================================================================

class DonorProfileSerializer(serializers.ModelSerializer):
    """Donor profile with user information"""
    user = UserSerializer(read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    
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
        ]
        read_only_fields = ['id', 'created_at']


class DonorProfileCreateSerializer(serializers.ModelSerializer):
    """Create/Update donor profile"""
    
    class Meta:
        model = DonorProfile
        fields = ['phone', 'blood_group', 'is_available', 'last_lat', 'last_lng']
    
    def create(self, validated_data):
        """Set location_updated_at when creating with last_lat/last_lng"""
        from django.utils import timezone
        if 'last_lat' in validated_data or 'last_lng' in validated_data:
            validated_data['location_updated_at'] = timezone.now()
        return super().create(validated_data)
    
    def update(self, instance, validated_data):
        """Set location_updated_at when last_lat/last_lng change"""
        from django.utils import timezone
        if 'last_lat' in validated_data or 'last_lng' in validated_data:
            validated_data['location_updated_at'] = timezone.now()
        return super().update(instance, validated_data)
    
    def validate_phone(self, value):
        """Accept any non-empty phone (allow all formats)."""
        if not value or not str(value).strip():
            raise serializers.ValidationError("Phone number is required")
        return str(value).strip()
    
    def validate_last_lat(self, value):
        """Donor latitude must be between -90 and 90 when provided."""
        if value is not None and (value < -90 or value > 90):
            raise serializers.ValidationError("Latitude must be between -90 and 90")
        return value
    
    def validate_last_lng(self, value):
        """Donor longitude must be between -180 and 180 when provided."""
        if value is not None and (value < -180 or value > 180):
            raise serializers.ValidationError("Longitude must be between -180 and 180")
        return value


class DonorProfileListSerializer(serializers.ModelSerializer):
    """Simplified donor list for admin"""
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    
    class Meta:
        model = DonorProfile
        fields = ['id', 'username', 'email', 'phone', 'blood_group', 'is_available', 'created_at', 'last_lat', 'last_lng', 'location_updated_at']


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
            'radius_km',
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'status', 'status_display', 'closed_at', 'closure_reason', 'closure_type']
    
    def get_notified_count(self, obj):
        """Count of notified donors"""
        return obj.notifications.count()
    
    def get_accepted_count(self, obj):
        """Count of donors who accepted"""
        return obj.responses.filter(response='accepted').count()


class BloodRequestCreateSerializer(serializers.ModelSerializer):
    """Create blood request (optionally with location for distance-based matching)"""
    
    class Meta:
        model = BloodRequest
        fields = ['blood_group', 'units_needed', 'urgency', 'note', 'req_lat', 'req_lng', 'location_name', 'radius_km']
    
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


class BloodRequestDetailSerializer(serializers.ModelSerializer):
    """Detailed blood request with responses"""
    created_by = UserSerializer(read_only=True)
    notified_donors = serializers.SerializerMethodField()
    accepted_donors = serializers.SerializerMethodField()
    urgency_display = serializers.CharField(source='get_urgency_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    
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
            'radius_km',
            'notified_donors',
            'accepted_donors'
        ]
    
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
