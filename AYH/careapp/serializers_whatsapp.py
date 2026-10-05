from rest_framework import serializers

from careapp.whatsapp_models import WhatsAppConversation, WhatsAppMessage, WhatsAppMessageLog


class WhatsAppMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = WhatsAppMessage
        fields = [
            'id', 'direction', 'sender_type', 'body', 'message_type',
            'whatsapp_message_id', 'status', 'media_url', 'media_mime_type',
            'blood_request_id', 'created_at', 'delivered_at', 'read_at',
        ]


class WhatsAppConversationSerializer(serializers.ModelSerializer):
    donor_name = serializers.SerializerMethodField()
    blood_group = serializers.SerializerMethodField()

    class Meta:
        model = WhatsAppConversation
        fields = [
            'id', 'phone', 'display_name', 'donor_name', 'blood_group',
            'unread_admin_count', 'unread_donor_count', 'last_message_at',
            'last_message_preview', 'is_online', 'admin_typing', 'donor_typing',
            'active_blood_request_id', 'created_at',
        ]

    def get_donor_name(self, obj):
        if obj.donor_user:
            return obj.donor_user.get_full_name() or obj.donor_user.username
        return obj.display_name

    def get_blood_group(self, obj):
        if obj.donor_profile:
            return obj.donor_profile.blood_group
        return None


class WhatsAppMessageLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = WhatsAppMessageLog
        fields = [
            'id', 'phone', 'message_type', 'message', 'status', 'provider',
            'provider_message_id', 'failed_reason', 'retry_count',
            'sent_at', 'delivered_at', 'read_at',
        ]
