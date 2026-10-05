from django.contrib import admin
from .models import (
    DonorProfile, UserProfile, BloodRequest, Notification, DonorResponse,
    AdminNotification, RequestTimeline, EtaTracking, DelayReason, DonorAssignment,
    DonorMovement, FallbackAction, RadiusExpansionLog, StandbyAction,
    BloodBankMaster, BloodBankFallback, HospitalMaster, HospitalMetrics,
    DimDate, DimCity, RequestDonorPoolAssignment,
)
from .whatsapp_models import WhatsAppConversation, WhatsAppMessage, WhatsAppMessageLog


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'gender', 'state', 'city', 'preferred_language', 'created_at')
    list_filter = ('gender', 'preferred_language')
    search_fields = ('user__username', 'state', 'city', 'occupation')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(DonorProfile)
class DonorProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'blood_group', 'phone', 'is_available', 'created_at')
    list_filter = ('blood_group', 'is_available')
    search_fields = ('user__username', 'user__email', 'phone')
    list_editable = ('is_available',)


@admin.register(BloodRequest)
class BloodRequestAdmin(admin.ModelAdmin):
    list_display = ('id', 'request_id', 'blood_group', 'units_needed', 'urgency', 'status', 'hospital_id', 'is_active', 'created_by', 'created_at')
    list_filter = ('blood_group', 'urgency', 'status', 'source', 'is_active', 'created_at')
    search_fields = ('note', 'city', 'state', 'hospital_id')
    list_editable = ('is_active', 'status')
    readonly_fields = ('created_at', 'request_id')


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('user', 'blood_request', 'is_read', 'created_at')
    list_filter = ('is_read', 'created_at')
    search_fields = ('user__username',)
    list_editable = ('is_read',)


@admin.register(DonorResponse)
class DonorResponseAdmin(admin.ModelAdmin):
    list_display = ('donor', 'blood_request', 'response', 'responded_at')
    list_filter = ('response', 'responded_at')
    search_fields = ('donor__username',)
    readonly_fields = ('responded_at',)


@admin.register(AdminNotification)
class AdminNotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'notification_type', 'blood_request', 'donor', 'created_at')
    list_filter = ('notification_type', 'created_at')
    search_fields = ('blood_request__id', 'donor__username')
    readonly_fields = ('created_at',)


@admin.register(RequestTimeline)
class RequestTimelineAdmin(admin.ModelAdmin):
    list_display = ('timeline_id', 'request', 'event_type', 'actor', 'event_time')
    list_filter = ('event_type', 'actor')
    search_fields = ('request__id',)
    readonly_fields = ('timeline_id', 'event_time')


@admin.register(EtaTracking)
class EtaTrackingAdmin(admin.ModelAdmin):
    list_display = ('eta_id', 'request', 'source', 'committed_at', 'eta_breached', 'actual_arrival_at')
    list_filter = ('source', 'eta_breached')
    search_fields = ('request__id',)


@admin.register(DelayReason)
class DelayReasonAdmin(admin.ModelAdmin):
    list_display = ('delay_id', 'request', 'stage', 'delay_reason', 'delay_category', 'delay_minutes', 'resolved', 'identified_at')
    list_filter = ('stage', 'delay_category', 'resolved')
    search_fields = ('request__id', 'delay_reason')





@admin.register(RequestDonorPoolAssignment)
class RequestDonorPoolAssignmentAdmin(admin.ModelAdmin):
    list_display = ('id', 'request', 'donor', 'pool_type', 'state', 'rank', 'distance_km', 'responded_at')
    list_filter = ('pool_type', 'state')
    search_fields = ('request__id', 'donor__username')
    readonly_fields = ('created_at',)


@admin.register(DonorAssignment)
class DonorAssignmentAdmin(admin.ModelAdmin):
    list_display = ('assignment_id', 'request', 'donor', 'donor_type', 'status', 'assigned_at', 'eta_minutes', 'distance_km')
    list_filter = ('donor_type', 'status')
    search_fields = ('request__id',)


@admin.register(DonorMovement)
class DonorMovementAdmin(admin.ModelAdmin):
    list_display = ('movement_id', 'assignment', 'recorded_at', 'distance_remaining_km', 'eta_remaining_min')
    list_filter = ('recorded_at',)
    search_fields = ('assignment__assignment_id',)


@admin.register(FallbackAction)
class FallbackActionAdmin(admin.ModelAdmin):
    list_display = ('fallback_id', 'request', 'fallback_type', 'trigger_reason', 'trigger_stage', 'triggered_at', 'success')
    list_filter = ('fallback_type', 'success')
    search_fields = ('request__id',)


@admin.register(RadiusExpansionLog)
class RadiusExpansionLogAdmin(admin.ModelAdmin):
    list_display = ('radius_id', 'request', 'old_radius_km', 'new_radius_km', 'expanded_at', 'success')
    list_filter = ('success',)
    search_fields = ('request__id',)


@admin.register(StandbyAction)
class StandbyActionAdmin(admin.ModelAdmin):
    list_display = ('standby_id', 'request', 'donor', 'activated_at', 'used', 'cancelled_at')
    list_filter = ('used',)
    search_fields = ('request__id',)


@admin.register(BloodBankMaster)
class BloodBankMasterAdmin(admin.ModelAdmin):
    list_display = ('blood_bank_id', 'name', 'city', 'reliability_score')
    list_filter = ('city',)
    search_fields = ('name', 'city')


@admin.register(BloodBankFallback)
class BloodBankFallbackAdmin(admin.ModelAdmin):
    list_display = ('bank_fallback_id', 'request', 'blood_bank', 'units_requested', 'units_confirmed', 'success', 'contacted_at')
    list_filter = ('success',)
    search_fields = ('request__id',)


@admin.register(HospitalMaster)
class HospitalMasterAdmin(admin.ModelAdmin):
    list_display = ('hospital_id', 'hospital_name', 'city', 'tier')
    list_filter = ('tier', 'city')
    search_fields = ('hospital_name', 'city')


@admin.register(HospitalMetrics)
class HospitalMetricsAdmin(admin.ModelAdmin):
    list_display = ('hospital', 'date', 'total_requests', 'fulfilled', 'failed', 'avg_fulfillment_time', 'sla_breach_pct')
    list_filter = ('date',)
    search_fields = ('hospital__hospital_name',)


@admin.register(DimDate)
class DimDateAdmin(admin.ModelAdmin):
    list_display = ('date', 'day', 'month', 'quarter', 'year')
    list_filter = ('year', 'quarter', 'month')


@admin.register(DimCity)
class DimCityAdmin(admin.ModelAdmin):
    list_display = ('city', 'state', 'region')
    list_filter = ('state', 'region')
    search_fields = ('city', 'state')


@admin.register(WhatsAppConversation)
class WhatsAppConversationAdmin(admin.ModelAdmin):
    list_display = ('phone', 'display_name', 'donor_user', 'unread_admin_count', 'last_message_at')
    search_fields = ('phone', 'display_name', 'donor_user__username')
    list_filter = ('is_support', 'is_online')


@admin.register(WhatsAppMessage)
class WhatsAppMessageAdmin(admin.ModelAdmin):
    list_display = ('conversation', 'direction', 'sender_type', 'status', 'created_at')
    list_filter = ('direction', 'sender_type', 'status')
    search_fields = ('body', 'whatsapp_message_id')


@admin.register(WhatsAppMessageLog)
class WhatsAppMessageLogAdmin(admin.ModelAdmin):
    list_display = ('phone', 'message_type', 'status', 'provider', 'sent_at', 'retry_count')
    list_filter = ('message_type', 'status', 'provider')
    search_fields = ('phone', 'message', 'provider_message_id')
    readonly_fields = ('provider_response',)
