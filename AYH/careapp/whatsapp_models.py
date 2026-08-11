"""
WhatsApp chat models — linked to existing DonorProfile/User, not duplicated.
"""
from django.conf import settings
from django.db import models
from django.utils import timezone


class WhatsAppConversation(models.Model):
    """One thread per donor phone ↔ base business number."""

    donor_profile = models.ForeignKey(
        'careapp.DonorProfile',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='whatsapp_conversations',
    )
    donor_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='whatsapp_conversations',
    )
    phone = models.CharField(max_length=20, db_index=True, help_text='Normalized E.164 digits')
    display_name = models.CharField(max_length=120, blank=True)
    is_support = models.BooleanField(default=True)
    active_blood_request = models.ForeignKey(
        'careapp.BloodRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='whatsapp_conversations',
    )
    unread_admin_count = models.PositiveIntegerField(default=0)
    unread_donor_count = models.PositiveIntegerField(default=0)
    last_message_at = models.DateTimeField(null=True, blank=True)
    last_message_preview = models.CharField(max_length=255, blank=True)
    is_online = models.BooleanField(default=False)
    admin_typing = models.BooleanField(default=False)
    donor_typing = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-last_message_at', '-updated_at']
        indexes = [
            models.Index(fields=['-last_message_at']),
            models.Index(fields=['phone']),
        ]

    def __str__(self):
        return self.display_name or self.phone


class WhatsAppMessage(models.Model):
    DIRECTION_INBOUND = 'inbound'
    DIRECTION_OUTBOUND = 'outbound'
    DIRECTION_CHOICES = [
        (DIRECTION_INBOUND, 'Inbound'),
        (DIRECTION_OUTBOUND, 'Outbound'),
    ]

    SENDER_DONOR = 'donor'
    SENDER_ADMIN = 'admin'
    SENDER_SYSTEM = 'system'
    SENDER_CHOICES = [
        (SENDER_DONOR, 'Donor'),
        (SENDER_ADMIN, 'Admin'),
        (SENDER_SYSTEM, 'System'),
    ]

    MSG_TEXT = 'text'
    MSG_IMAGE = 'image'
    MSG_DOCUMENT = 'document'
    MSG_TEMPLATE = 'template'
    MSG_TYPE_CHOICES = [
        (MSG_TEXT, 'Text'),
        (MSG_IMAGE, 'Image'),
        (MSG_DOCUMENT, 'Document'),
        (MSG_TEMPLATE, 'Template'),
    ]

    STATUS_PENDING = 'pending'
    STATUS_SENT = 'sent'
    STATUS_DELIVERED = 'delivered'
    STATUS_READ = 'read'
    STATUS_FAILED = 'failed'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_SENT, 'Sent'),
        (STATUS_DELIVERED, 'Delivered'),
        (STATUS_READ, 'Read'),
        (STATUS_FAILED, 'Failed'),
    ]

    conversation = models.ForeignKey(
        WhatsAppConversation,
        on_delete=models.CASCADE,
        related_name='messages',
    )
    direction = models.CharField(max_length=10, choices=DIRECTION_CHOICES)
    sender_type = models.CharField(max_length=10, choices=SENDER_CHOICES)
    body = models.TextField(blank=True)
    message_type = models.CharField(max_length=20, choices=MSG_TYPE_CHOICES, default=MSG_TEXT)
    whatsapp_message_id = models.CharField(max_length=128, blank=True, db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    media_url = models.URLField(max_length=500, blank=True)
    media_mime_type = models.CharField(max_length=100, blank=True)
    blood_request = models.ForeignKey(
        'careapp.BloodRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='whatsapp_messages',
    )
    sent_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='whatsapp_messages_sent',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    failed_reason = models.TextField(blank=True)

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', 'created_at']),
            models.Index(fields=['whatsapp_message_id']),
        ]

    def mark_delivered(self):
        if self.status not in (self.STATUS_DELIVERED, self.STATUS_READ):
            self.status = self.STATUS_DELIVERED
            self.delivered_at = timezone.now()
            self.save(update_fields=['status', 'delivered_at'])

    def mark_read(self):
        self.status = self.STATUS_READ
        self.read_at = timezone.now()
        if not self.delivered_at:
            self.delivered_at = self.read_at
        self.save(update_fields=['status', 'read_at', 'delivered_at'])


class WhatsAppMessageLog(models.Model):
    """Provider/API audit log (templates, alerts, OTP, etc.)."""

    TYPE_TEXT = 'text'
    TYPE_TEMPLATE = 'template'
    TYPE_BLOOD_ALERT = 'blood_alert'
    TYPE_OTP = 'otp'
    TYPE_ACCEPTANCE = 'acceptance'
    TYPE_REJECTION = 'rejection'
    TYPE_EMERGENCY = 'emergency'
    TYPE_CHOICES = [
        (TYPE_TEXT, 'Text'),
        (TYPE_TEMPLATE, 'Template'),
        (TYPE_BLOOD_ALERT, 'Blood alert'),
        (TYPE_OTP, 'OTP'),
        (TYPE_ACCEPTANCE, 'Acceptance'),
        (TYPE_REJECTION, 'Rejection'),
        (TYPE_EMERGENCY, 'Emergency'),
    ]

    STATUS_PENDING = 'pending'
    STATUS_SENT = 'sent'
    STATUS_DELIVERED = 'delivered'
    STATUS_READ = 'read'
    STATUS_FAILED = 'failed'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_SENT, 'Sent'),
        (STATUS_DELIVERED, 'Delivered'),
        (STATUS_READ, 'Read'),
        (STATUS_FAILED, 'Failed'),
    ]

    phone = models.CharField(max_length=20, db_index=True)
    message_type = models.CharField(max_length=30, choices=TYPE_CHOICES, default=TYPE_TEXT)
    message = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    provider = models.CharField(max_length=30, blank=True)
    provider_message_id = models.CharField(max_length=128, blank=True, db_index=True)
    provider_response = models.JSONField(default=dict, blank=True)
    conversation = models.ForeignKey(
        WhatsAppConversation,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='message_logs',
    )
    blood_request = models.ForeignKey(
        'careapp.BloodRequest',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='whatsapp_logs',
    )
    sent_at = models.DateTimeField(auto_now_add=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    failed_reason = models.TextField(blank=True)
    retry_count = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['-sent_at']
