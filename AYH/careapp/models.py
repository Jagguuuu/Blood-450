import uuid
from django.db import models
from django.contrib.auth.models import User


class UserProfile(models.Model):
    """User's personal, location, health and contact details (linked to User)."""
    GENDER_CHOICES = [
        ('M', 'Male'),
        ('F', 'Female'),
        ('O', 'Other'),
    ]
    CONTACT_METHOD_CHOICES = [
        ('call', 'Call'),
        ('whatsapp', 'WhatsApp'),
        ('sms', 'SMS'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='user_profile')
    gender = models.CharField(max_length=1, choices=GENDER_CHOICES, null=True, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)
    state = models.CharField(max_length=100, blank=True)
    city = models.CharField(max_length=100, blank=True)
    area = models.CharField(max_length=200, blank=True)
    pincode = models.CharField(max_length=10, blank=True)
    weight_kg = models.FloatField(null=True, blank=True)
    donated_before = models.BooleanField(null=True, blank=True)
    last_donation_date = models.DateField(null=True, blank=True)
    medical_conditions = models.BooleanField(null=True, blank=True)
    currently_healthy = models.BooleanField(null=True, blank=True)
    emergency_available = models.BooleanField(default=True)
    preferred_contact = models.CharField(max_length=20, choices=CONTACT_METHOD_CHOICES, default='call')
    consent_contact = models.BooleanField(default=False)
    consent_terms = models.BooleanField(default=False)
    alternate_mobile = models.CharField(max_length=15, blank=True)
    preferred_language = models.CharField(max_length=50, blank=True)
    preferred_contact_time = models.CharField(max_length=50, blank=True)
    occupation = models.CharField(max_length=100, blank=True)
    emergency_contact_name = models.CharField(max_length=100, blank=True)
    emergency_contact_number = models.CharField(max_length=15, blank=True)
    profile_photo = models.ImageField(upload_to='donor_photos/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profile: {self.user.username}"

    class Meta:
        ordering = ['-created_at']


class DonorProfile(models.Model):
    """Donor identity: phone, blood group, availability, location (for matching). Linked to User."""
    BLOOD_GROUP_CHOICES = [
        ('A+', 'A+'),
        ('A-', 'A-'),
        ('B+', 'B+'),
        ('B-', 'B-'),
        ('O+', 'O+'),
        ('O-', 'O-'),
        ('AB+', 'AB+'),
        ('AB-', 'AB-'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='donor_profile')
    phone = models.CharField(max_length=15, blank=True)  # blank allowed for Google sign-in; add later in profile
    blood_group = models.CharField(max_length=3, choices=BLOOD_GROUP_CHOICES, null=True, blank=True)
    is_available = models.BooleanField(default=True)
    phone_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    last_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    last_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    location_updated_at = models.DateTimeField(null=True, blank=True)
    donor_id = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)

    city = models.CharField(max_length=100, blank=True)

    last_donation_date = models.DateField(null=True, blank=True)

    AVAILABILITY_CHOICES = [
        ('Available', 'Available'),
        ('Busy', 'Busy'),
    ]
    availability_status = models.CharField(
        max_length=20,
        choices=AVAILABILITY_CHOICES,
        default='Available'
    )

    reliability_score = models.FloatField(null=True, blank=True)


    def __str__(self):
        return f"{self.user.username} - {self.blood_group or 'No BG'}"

    class Meta:
        ordering = ['-created_at']





class BloodRequest(models.Model):
    """Blood donation request - extended with request_id, city, state, hospital, status, SLA, closure."""
    BLOOD_GROUP_CHOICES = DonorProfile.BLOOD_GROUP_CHOICES

    URGENCY_CHOICES = [
        ('critical', 'Critical'),
        ('high', 'High'),
        ('medium', 'Medium'),
    ]
    STATUS_CHOICES = [
        ('open', 'Open'),
        ('fulfilled', 'Fulfilled'),
        ('failed', 'Failed'),
        ('cancelled', 'Cancelled'),
    ]
    SOURCE_CHOICES = [
        ('app', 'App'),
        ('call', 'Call'),
        ('hospital', 'Hospital'),
    ]
    CLOSURE_TYPE_CHOICES = [
        ('donor', 'Donor'),
        ('bloodbank', 'BloodBank'),
        ('mixed', 'Mixed'),
    ]
    CLOSURE_REASON_CHOICES = [
        ('success', 'Success'),
        ('timeout', 'Timeout'),
        ('cancelled', 'Cancelled'),
    ]

    request_id = models.UUIDField(default=uuid.uuid4, editable=False, db_index=True, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    city = models.CharField(max_length=100, blank=True)
    state = models.CharField(max_length=100, blank=True)
    hospital_id = models.CharField(max_length=50, blank=True, db_index=True)
    patient_age = models.PositiveIntegerField(null=True, blank=True)
    blood_group = models.CharField(max_length=3, choices=BLOOD_GROUP_CHOICES)
    units_needed = models.PositiveIntegerField(default=1)
    units_required = models.PositiveIntegerField(default=1, null=True, blank=True)  # schema alias
    urgency = models.CharField(max_length=10, choices=URGENCY_CHOICES)
    urgency_level = models.CharField(max_length=20, blank=True)  # Critical / High / Normal
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES, default='app', blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='open', db_index=True)
    closed_at = models.DateTimeField(null=True, blank=True)
    closure_reason = models.CharField(max_length=20, choices=CLOSURE_REASON_CHOICES, blank=True)
    closure_type = models.CharField(max_length=20, choices=CLOSURE_TYPE_CHOICES, blank=True)
    sla_minutes = models.PositiveIntegerField(null=True, blank=True)
    note = models.TextField(blank=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    req_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    req_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    location_name = models.CharField(max_length=255, blank=True)
    radius_km = models.FloatField(default=5.0)

    def save(self, *args, **kwargs):
        if not self.urgency_level and self.urgency:
            self.urgency_level = self.urgency.capitalize()
        if self.units_required is None and self.units_needed is not None:
            self.units_required = self.units_needed
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.blood_group} - {self.urgency} ({self.created_at.strftime('%Y-%m-%d')})"

    class Meta:
        ordering = ['-created_at']


class Notification(models.Model):
    """Notification sent to matching donors when a blood request is created"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    blood_request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='notifications')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"Notification for {self.user.username} - Request #{self.blood_request.id}"
    
    class Meta:
        unique_together = ('user', 'blood_request')
        ordering = ['-created_at']


class DonorResponse(models.Model):
    """Donor's response (accept/reject) to a blood request"""
    RESPONSE_CHOICES = [
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
    ]
    
    blood_request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='responses')
    donor = models.ForeignKey(User, on_delete=models.CASCADE, related_name='donor_responses')
    response = models.CharField(max_length=10, choices=RESPONSE_CHOICES)
    responded_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.donor.username} - {self.response} (Request #{self.blood_request.id})"
    
    class Meta:
        unique_together = ('blood_request', 'donor')
        ordering = ['-responded_at']


class AdminNotification(models.Model):
    """Notifications for superuser/admin: request created or donor accepted."""
    TYPE_REQUEST_CREATED = 'request_created'
    TYPE_DONOR_ACCEPTED = 'donor_accepted'
    TYPE_CHOICES = [
        (TYPE_REQUEST_CREATED, 'Request Created'),
        (TYPE_DONOR_ACCEPTED, 'Donor Accepted'),
    ]
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    blood_request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='admin_notifications')
    donor = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='admin_notifications_as_donor')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        if self.notification_type == self.TYPE_DONOR_ACCEPTED and self.donor:
            return f"Donor {self.donor.username} accepted request #{self.blood_request_id}"
        return f"Request #{self.blood_request_id} created"

    class Meta:
        ordering = ['-created_at']


class RequestDonorPoolAssignment(models.Model):
    """
    Active vs Standby pool for a blood request. Donors are ranked by distance.
    When an active donor rejects/times out/drops, the nearest standby is promoted and standby is refilled.
    Does not replace existing Notification/DonorResponse flow; works alongside it.
    """
    POOL_TYPE_ACTIVE = 'ACTIVE'
    POOL_TYPE_STANDBY = 'STANDBY'
    POOL_TYPE_CHOICES = [
        (POOL_TYPE_ACTIVE, 'Active'),
        (POOL_TYPE_STANDBY, 'Standby'),
    ]
    STATE_PENDING = 'PENDING'
    STATE_ACCEPTED = 'ACCEPTED'
    STATE_REJECTED = 'REJECTED'
    STATE_TIMEOUT = 'TIMEOUT'
    STATE_DROPPED = 'DROPPED'
    STATE_CHOICES = [
        (STATE_PENDING, 'Pending'),
        (STATE_ACCEPTED, 'Accepted'),
        (STATE_REJECTED, 'Rejected'),
        (STATE_TIMEOUT, 'Timeout'),
        (STATE_DROPPED, 'Dropped'),
    ]
    id = models.AutoField(primary_key=True)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='pool_assignments', db_column='request_id')
    donor = models.ForeignKey(User, on_delete=models.CASCADE, related_name='pool_assignments')
    distance_km = models.FloatField(null=True, blank=True, help_text='Distance at assignment time')
    pool_type = models.CharField(max_length=10, choices=POOL_TYPE_CHOICES, default=POOL_TYPE_ACTIVE)
    state = models.CharField(max_length=10, choices=STATE_CHOICES, default=STATE_PENDING)
    rank = models.PositiveIntegerField(default=0, help_text='Order by distance; lower = closer')
    notified_at = models.DateTimeField(null=True, blank=True)
    responded_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['rank', 'id']
        unique_together = (('request', 'donor'),)
        verbose_name = 'Request donor pool assignment'

    def __str__(self):
        return f"Request #{self.request_id} {self.pool_type} donor {self.donor.username} ({self.state})"


class DonorOTP(models.Model):
    """OTP for donor mobile verification (one per phone, overwritten on resend)."""
    phone = models.CharField(max_length=15, unique=True)
    otp_code = models.CharField(max_length=8)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


# ---------------------------------------------------------------------------
# Request timeline, ETA, delays, donor master/assignment/movement, fallbacks
# ---------------------------------------------------------------------------

class RequestTimeline(models.Model):
    """Timeline events for a blood request (CREATED, SEARCH_STARTED, DONOR_ACCEPTED, etc.)."""
    EVENT_TYPES = [
        ('CREATED', 'Created'),
        ('SEARCH_STARTED', 'Search Started'),
        ('DONOR_ACCEPTED', 'Donor Accepted'),
        ('STANDBY_ACTIVATED', 'Standby Activated'),
        ('STANDBY_PROMOTED', 'Standby Promoted'),
        ('BANK_TRIGGERED', 'Bank Triggered'),
        ('FULFILLED', 'Fulfilled'),
    ]
    ACTOR_CHOICES = [
        ('SYSTEM', 'System'),
        ('ADMIN', 'Admin'),
        ('DONOR', 'Donor'),
        ('BANK', 'Bank'),
    ]
    timeline_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='timeline_events', db_column='request_id')
    event_type = models.CharField(max_length=30, choices=EVENT_TYPES)
    event_time = models.DateTimeField(auto_now_add=True)
    actor = models.CharField(max_length=20, choices=ACTOR_CHOICES, default='SYSTEM')
    metadata = models.JSONField(null=True, blank=True)

    class Meta:
        ordering = ['event_time']


class EtaTracking(models.Model):
    """ETA tracking for donor or blood bank arrival."""
    SOURCE_CHOICES = [('Donor', 'Donor'), ('BloodBank', 'BloodBank')]
    eta_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='eta_trackings', db_column='request_id')
    source = models.CharField(max_length=20, choices=SOURCE_CHOICES)
    committed_at = models.DateTimeField(null=True, blank=True)
    committed_eta_min = models.PositiveIntegerField(null=True, blank=True)
    actual_arrival_at = models.DateTimeField(null=True, blank=True)
    actual_duration_min = models.PositiveIntegerField(null=True, blank=True)
    eta_breached = models.BooleanField(default=False)
    breach_minutes = models.IntegerField(null=True, blank=True)

    class Meta:
        ordering = ['-committed_at']


class DelayReason(models.Model):
    """Delay reasons for a request (Search / Acceptance / Transit)."""
    STAGE_CHOICES = [
        ('Search', 'Search'),
        ('Acceptance', 'Acceptance'),
        ('Transit', 'Transit'),
    ]
    CATEGORY_CHOICES = [
        ('Supply', 'Supply'),
        ('Distance', 'Distance'),
        ('Ops', 'Ops'),
    ]
    delay_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='delay_reasons', db_column='request_id')
    reported_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='reported_delay_reasons')
    stage = models.CharField(max_length=30, choices=STAGE_CHOICES)
    delay_reason = models.CharField(max_length=100)
    delay_category = models.CharField(max_length=30, choices=CATEGORY_CHOICES, blank=True)
    delay_minutes = models.PositiveIntegerField(null=True, blank=True)
    identified_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolved = models.BooleanField(default=False)

    class Meta:
        ordering = ['-identified_at']


class DonorAssignment(models.Model):
    """Assignment of a donor to a request (Primary / Standby)."""
    DONOR_TYPE_CHOICES = [('Primary', 'Primary'), ('Standby', 'Standby')]
    STATUS_CHOICES = [
        ('Accepted', 'Accepted'),
        ('Dropped', 'Dropped'),
        ('Completed', 'Completed'),
    ]
    assignment_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='donor_assignments', db_column='request_id')
    donor = models.ForeignKey(User, on_delete=models.CASCADE, related_name='donor_assignments', null=True, blank=True)
    donor_master = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, null=True, blank=True, related_name='assignments')
    donor_type = models.CharField(max_length=20, choices=DONOR_TYPE_CHOICES, default='Primary')
    assigned_at = models.DateTimeField(auto_now_add=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    dropped_at = models.DateTimeField(null=True, blank=True)
    drop_reason = models.CharField(max_length=100, blank=True)
    eta_minutes = models.PositiveIntegerField(null=True, blank=True)
    distance_km = models.FloatField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Accepted')

    class Meta:
        ordering = ['-assigned_at']


class DonorMovement(models.Model):
    """Donor movement / location updates during assignment."""
    movement_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    assignment = models.ForeignKey(DonorAssignment, on_delete=models.CASCADE, related_name='movements', db_column='assignment_id')
    location_lat = models.FloatField(null=True, blank=True)
    location_long = models.FloatField(null=True, blank=True)
    recorded_at = models.DateTimeField(auto_now_add=True)
    distance_remaining_km = models.FloatField(null=True, blank=True)
    eta_remaining_min = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        ordering = ['-recorded_at']


class FallbackAction(models.Model):
    """Fallback actions (Radius, Standby, Bank, NGO) when no donors or SLA risk."""
    FALLBACK_TYPES = [
        ('Radius', 'Radius'),
        ('Standby', 'Standby'),
        ('Bank', 'Bank'),
        ('NGO', 'NGO'),
    ]
    fallback_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='fallback_actions', db_column='request_id')
    fallback_type = models.CharField(max_length=20, choices=FALLBACK_TYPES)
    trigger_reason = models.CharField(max_length=100, blank=True)
    trigger_stage = models.CharField(max_length=30, blank=True)
    trigger_level = models.PositiveSmallIntegerField(null=True, blank=True)
    triggered_at = models.DateTimeField(auto_now_add=True)
    resolved_at = models.DateTimeField(null=True, blank=True)
    success = models.BooleanField(default=False)

    class Meta:
        ordering = ['-triggered_at']


class RadiusExpansionLog(models.Model):
    """Log of radius expansion for a request."""
    radius_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='radius_expansions', db_column='request_id')
    old_radius_km = models.FloatField(null=True, blank=True)
    new_radius_km = models.FloatField(null=True, blank=True)
    expanded_at = models.DateTimeField(auto_now_add=True)
    success = models.BooleanField(default=False)

    class Meta:
        ordering = ['-expanded_at']


class StandbyAction(models.Model):
    """Standby donor activation for a request."""
    standby_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='standby_actions', db_column='request_id')
    donor = models.ForeignKey(User, on_delete=models.CASCADE, null=True, blank=True, related_name='standby_actions')
    donor_master = models.ForeignKey(DonorProfile, on_delete=models.CASCADE, null=True, blank=True, related_name='standby_actions')
    activated_at = models.DateTimeField(auto_now_add=True)
    used = models.BooleanField(default=False)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-activated_at']


class BloodBankMaster(models.Model):
    """Blood bank master: id, name, city, location, reliability."""
    blood_bank_id = models.CharField(max_length=50, primary_key=True)
    name = models.CharField(max_length=200)
    city = models.CharField(max_length=100, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    reliability_score = models.FloatField(null=True, blank=True)

    def __str__(self):
        return f"{self.name} ({self.city})"

    class Meta:
        ordering = ['name']


class BloodBankFallback(models.Model):
    """Blood bank fallback when donor path fails."""
    bank_fallback_id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(BloodRequest, on_delete=models.CASCADE, related_name='blood_bank_fallbacks', db_column='request_id')
    blood_bank = models.ForeignKey(BloodBankMaster, on_delete=models.CASCADE, related_name='fallbacks')
    units_requested = models.PositiveIntegerField(default=1)
    units_confirmed = models.PositiveIntegerField(null=True, blank=True)
    contacted_at = models.DateTimeField(null=True, blank=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    eta_minutes = models.PositiveIntegerField(null=True, blank=True)
    success = models.BooleanField(default=False)

    class Meta:
        ordering = ['-contacted_at']


class HospitalMaster(models.Model):
    """Hospital master: id, name, city, tier."""
    hospital_id = models.CharField(max_length=50, primary_key=True)
    hospital_name = models.CharField(max_length=200)
    city = models.CharField(max_length=100, blank=True)
    tier = models.CharField(max_length=30, blank=True)

    def __str__(self):
        return f"{self.hospital_name} ({self.city})"

    class Meta:
        ordering = ['hospital_name']


class HospitalMetrics(models.Model):
    """Daily metrics per hospital."""
    hospital = models.ForeignKey(HospitalMaster, on_delete=models.CASCADE, related_name='metrics')
    date = models.DateField()
    total_requests = models.PositiveIntegerField(default=0)
    fulfilled = models.PositiveIntegerField(default=0)
    failed = models.PositiveIntegerField(default=0)
    avg_fulfillment_time = models.FloatField(null=True, blank=True)
    sla_breach_pct = models.FloatField(null=True, blank=True)

    class Meta:
        ordering = ['-date', 'hospital_id']
        unique_together = ('hospital', 'date')


class DimDate(models.Model):
    """Date dimension for reporting."""
    date = models.DateField(primary_key=True)
    day = models.PositiveSmallIntegerField(null=True, blank=True)
    month = models.PositiveSmallIntegerField(null=True, blank=True)
    quarter = models.PositiveSmallIntegerField(null=True, blank=True)
    year = models.PositiveSmallIntegerField(null=True, blank=True)

    class Meta:
        ordering = ['-date']


class DimCity(models.Model):
    """City dimension: city, state, region."""
    city = models.CharField(max_length=100)
    state = models.CharField(max_length=100)
    region = models.CharField(max_length=100, blank=True)

    class Meta:
        ordering = ['city', 'state']
        unique_together = ('city', 'state')


# WhatsApp chat models (see whatsapp_models.py)
from .whatsapp_models import (  # noqa: E402, F401
    WhatsAppConversation,
    WhatsAppMessage,
    WhatsAppMessageLog,
)
