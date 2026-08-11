"""
Central WhatsApp service — conversations, messages, outbound API, real-time broadcast.
"""
import logging
from typing import Any, Dict, List, Optional

try:
    from asgiref.sync import async_to_sync
    from channels.layers import get_channel_layer
except ImportError:
    async_to_sync = None
    get_channel_layer = lambda: None
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import F
from django.utils import timezone

from careapp.models import BloodRequest, DonorProfile, DonorResponse, Notification
from careapp.whatsapp_models import (
    WhatsAppConversation,
    WhatsAppMessage,
    WhatsAppMessageLog,
)
from careapp.services.whatsapp_providers import get_whatsapp_provider
from careapp.services.whatsapp_utils import (
    format_whatsapp_api_error,
    normalize_phone,
    parse_reply_keyword,
)

logger = logging.getLogger(__name__)
User = get_user_model()


class WhatsAppService:
    def __init__(self):
        self.provider = get_whatsapp_provider()

    # ------------------------------------------------------------------
    # Conversations
    # ------------------------------------------------------------------

    def get_or_create_conversation(
        self,
        phone: str,
        donor_profile: Optional[DonorProfile] = None,
        donor_user=None,
    ) -> WhatsAppConversation:
        normalized = normalize_phone(phone)
        conv, created = WhatsAppConversation.objects.get_or_create(
            phone=normalized,
            defaults={
                'donor_profile': donor_profile,
                'donor_user': donor_user or (donor_profile.user if donor_profile else None),
                'display_name': self._display_name(donor_profile, normalized),
            },
        )
        if not created:
            updated = []
            if donor_profile and conv.donor_profile_id != donor_profile.id:
                conv.donor_profile = donor_profile
                updated.append('donor_profile')
            if donor_user and conv.donor_user_id != donor_user.id:
                conv.donor_user = donor_user
                updated.append('donor_user')
            if updated:
                conv.save(update_fields=updated)
        return conv

    def _display_name(self, donor_profile: Optional[DonorProfile], phone: str) -> str:
        if donor_profile and donor_profile.user:
            name = donor_profile.user.get_full_name() or donor_profile.user.username
            return f'{name} ({phone[-10:]})'
        return phone

    def find_donor_by_phone(self, phone: str) -> Optional[DonorProfile]:
        normalized = normalize_phone(phone)
        if not normalized:
            return None
        tail = normalized[-10:]
        for dp in DonorProfile.objects.select_related('user').filter(phone__isnull=False).exclude(phone=''):
            if normalize_phone(dp.phone).endswith(tail) or normalize_phone(dp.phone) == normalized:
                return dp
        return None

    # ------------------------------------------------------------------
    # Outbound API
    # ------------------------------------------------------------------

    def send_text_message(
        self,
        phone: str,
        message: str,
        *,
        message_type: str = WhatsAppMessageLog.TYPE_TEXT,
        conversation: Optional[WhatsAppConversation] = None,
        blood_request: Optional[BloodRequest] = None,
        sender_type: str = WhatsAppMessage.SENDER_SYSTEM,
        sent_by=None,
        save_chat: bool = True,
        outbound_kind: str = 'admin',
    ) -> Dict[str, Any]:
        """
        outbound_kind: 'session' (auto-reply after donor messaged us), 'admin', 'proactive'.
        Proactive (welcome, blood alerts) is gated by WHATSAPP_PROACTIVE_OUTBOUND in dev.
        """
        from django.conf import settings as django_settings

        if outbound_kind == 'proactive' and not getattr(
            django_settings, 'WHATSAPP_PROACTIVE_OUTBOUND', False
        ):
            logger.info(
                'WhatsApp proactive send skipped (WHATSAPP_PROACTIVE_OUTBOUND=false) to %s',
                phone,
            )
            return {
                'ok': False,
                'skipped': True,
                'error': (
                    'Proactive WhatsApp outbound is disabled. Donor must message the '
                    'business number first; use auto-reply after inbound.'
                ),
            }

        normalized = normalize_phone(phone)
        if not normalized:
            return {'ok': False, 'error': 'Invalid phone number'}

        log = WhatsAppMessageLog.objects.create(
            phone=normalized,
            message_type=message_type,
            message=message,
            status=WhatsAppMessageLog.STATUS_PENDING,
            provider=self.provider.__class__.__name__,
            conversation=conversation,
            blood_request=blood_request,
        )

        result = self.provider.send_text(normalized, message)
        chat_msg = None

        if result.get('ok'):
            log.status = WhatsAppMessageLog.STATUS_SENT
            log.provider_message_id = result.get('message_id', '')
            log.provider_response = result
            log.save(update_fields=['status', 'provider_message_id', 'provider_response'])

            if save_chat:
                if not conversation:
                    donor = self.find_donor_by_phone(normalized)
                    conversation = self.get_or_create_conversation(
                        normalized,
                        donor_profile=donor,
                        donor_user=donor.user if donor else None,
                    )
                chat_msg = self._save_outbound_message(
                    conversation,
                    message,
                    result.get('message_id', ''),
                    sender_type=sender_type,
                    sent_by=sent_by,
                    blood_request=blood_request,
                )
            return {'ok': True, 'log_id': log.id, 'message_id': result.get('message_id'), 'chat_message_id': chat_msg.id if chat_msg else None}

        err_text = format_whatsapp_api_error(result.get('error'))
        log.status = WhatsAppMessageLog.STATUS_FAILED
        log.failed_reason = err_text
        log.provider_response = result if isinstance(result, dict) else {'error': result}
        log.save(update_fields=['status', 'failed_reason', 'provider_response'])
        if save_chat and conversation:
            self._save_outbound_message(
                conversation,
                message,
                '',
                sender_type=sender_type,
                sent_by=sent_by,
                blood_request=blood_request,
                status=WhatsAppMessage.STATUS_FAILED,
                failed_reason=err_text,
            )
        logger.error('WhatsApp send failed to %s: %s', normalized, err_text)
        return {'ok': False, 'error': err_text, 'log_id': log.id}

    def send_template_message(
        self,
        phone: str,
        template_name: str,
        variables: Optional[List[str]] = None,
        **kwargs,
    ) -> Dict[str, Any]:
        normalized = normalize_phone(phone)
        log = WhatsAppMessageLog.objects.create(
            phone=normalized,
            message_type=WhatsAppMessageLog.TYPE_TEMPLATE,
            message=f'Template:{template_name} {variables or []}',
            status=WhatsAppMessageLog.STATUS_PENDING,
            provider=self.provider.__class__.__name__,
        )
        result = self.provider.send_template(normalized, template_name, variables)
        if result.get('ok'):
            log.status = WhatsAppMessageLog.STATUS_SENT
            log.provider_message_id = result.get('message_id', '')
            log.provider_response = result
            log.save(update_fields=['status', 'provider_message_id', 'provider_response'])
            return {'ok': True, 'log_id': log.id}
        log.status = WhatsAppMessageLog.STATUS_FAILED
        log.failed_reason = str(result.get('error'))
        log.save(update_fields=['status', 'failed_reason', 'provider_response'])
        return result

    def send_otp(self, phone: str, otp: str) -> Dict[str, Any]:
        return self.send_text_message(
            phone,
            f'Your Blood450 verification code is {otp}. Valid for 10 minutes.',
            message_type=WhatsAppMessageLog.TYPE_OTP,
            save_chat=False,
        )

    def send_blood_request_alert(
        self,
        blood_request: BloodRequest,
        donor_profile: DonorProfile,
    ) -> Dict[str, Any]:
        phone = donor_profile.phone
        if not phone:
            return {'ok': False, 'error': 'Donor has no phone'}
        hospital = blood_request.hospital_id or 'Hospital'
        city = blood_request.city or ''
        msg = (
            f'🩸 *Emergency Blood Request*\n'
            f'Blood group: *{blood_request.blood_group}*\n'
            f'Units: {blood_request.units_needed}\n'
            f'Urgency: {blood_request.urgency}\n'
            f'Location: {hospital} {city}\n\n'
            f'Reply *YES* to accept or *NO* to decline.\n'
            f'Request ID: {blood_request.request_id or blood_request.id}'
        )
        donor = donor_profile
        conv = self.get_or_create_conversation(phone, donor_profile=donor, donor_user=donor.user)
        conv.active_blood_request = blood_request
        conv.save(update_fields=['active_blood_request', 'updated_at'])
        return self.send_text_message(
            phone,
            msg,
            message_type=WhatsAppMessageLog.TYPE_BLOOD_ALERT,
            conversation=conv,
            blood_request=blood_request,
            outbound_kind='proactive',
        )

    def send_acceptance_message(self, phone: str, blood_request: BloodRequest) -> Dict[str, Any]:
        msg = (
            f'✅ Thank you! Your acceptance for blood request '
            f'{blood_request.request_id or blood_request.id} ({blood_request.blood_group}) '
            f'has been recorded. Our team will contact you shortly.'
        )
        return self.send_text_message(
            phone,
            msg,
            message_type=WhatsAppMessageLog.TYPE_ACCEPTANCE,
            blood_request=blood_request,
            outbound_kind='session',
        )

    def send_rejection_message(self, phone: str, blood_request: BloodRequest) -> Dict[str, Any]:
        msg = (
            f'Thank you for responding. Your decline for request '
            f'{blood_request.request_id or blood_request.id} has been noted.'
        )
        return self.send_text_message(
            phone,
            msg,
            message_type=WhatsAppMessageLog.TYPE_REJECTION,
            blood_request=blood_request,
            outbound_kind='session',
        )

    def send_admin_reply(
        self,
        conversation: WhatsAppConversation,
        body: str,
        admin_user,
    ) -> Dict[str, Any]:
        return self.send_text_message(
            conversation.phone,
            body,
            conversation=conversation,
            sender_type=WhatsAppMessage.SENDER_ADMIN,
            sent_by=admin_user,
        )

    # ------------------------------------------------------------------
    # Inbound webhook
    # ------------------------------------------------------------------

    @transaction.atomic
    def handle_inbound_text(
        self,
        phone: str,
        body: str,
        whatsapp_message_id: str = '',
        media_url: str = '',
        message_type: str = WhatsAppMessage.MSG_TEXT,
        profile_name: str = '',
    ) -> WhatsAppMessage:
        donor = self.find_donor_by_phone(phone)
        conv = self.get_or_create_conversation(
            phone,
            donor_profile=donor,
            donor_user=donor.user if donor else None,
        )
        if profile_name and profile_name.strip():
            label = f'{profile_name.strip()} ({normalize_phone(phone)[-10:]})'
            if conv.display_name != label:
                conv.display_name = label
                conv.save(update_fields=['display_name', 'updated_at'])
        msg = WhatsAppMessage.objects.create(
            conversation=conv,
            direction=WhatsAppMessage.DIRECTION_INBOUND,
            sender_type=WhatsAppMessage.SENDER_DONOR,
            body=body,
            message_type=message_type,
            whatsapp_message_id=whatsapp_message_id,
            status=WhatsAppMessage.STATUS_DELIVERED,
            media_url=media_url or '',
            delivered_at=timezone.now(),
        )
        preview = (body or '[media]')[:255]
        WhatsAppConversation.objects.filter(pk=conv.pk).update(
            last_message_at=timezone.now(),
            last_message_preview=preview,
            unread_admin_count=F('unread_admin_count') + 1,
            is_online=True,
        )
        conv.refresh_from_db()
        self._broadcast_message(conv, msg)
        self._handle_blood_reply(conv, body, donor)
        return msg

    def handle_status_update(
        self,
        whatsapp_message_id: str,
        status: str,
        errors: Optional[list] = None,
    ):
        if not whatsapp_message_id:
            return
        msg = WhatsAppMessage.objects.filter(whatsapp_message_id=whatsapp_message_id).first()
        log = WhatsAppMessageLog.objects.filter(provider_message_id=whatsapp_message_id).first()
        status = (status or '').lower()
        if msg:
            if status in ('delivered',):
                msg.mark_delivered()
            elif status in ('read',):
                msg.mark_read()
            elif status in ('failed',):
                msg.status = WhatsAppMessage.STATUS_FAILED
                msg.failed_reason = str(errors or 'failed')
                msg.save(update_fields=['status', 'failed_reason'])
            self._broadcast_status(msg.conversation_id, msg)
        if log:
            if status == 'delivered':
                log.status = WhatsAppMessageLog.STATUS_DELIVERED
                log.delivered_at = timezone.now()
            elif status == 'read':
                log.status = WhatsAppMessageLog.STATUS_READ
                log.read_at = timezone.now()
            elif status == 'failed':
                log.status = WhatsAppMessageLog.STATUS_FAILED
                log.failed_reason = str(errors or 'failed')
            log.save()

    def _handle_blood_reply(
        self,
        conv: WhatsAppConversation,
        body: str,
        donor: Optional[DonorProfile],
    ):
        keyword = parse_reply_keyword(body)
        if not keyword or not conv.active_blood_request_id or not donor:
            return
        blood_request = conv.active_blood_request
        user = donor.user
        DonorResponse.objects.update_or_create(
            blood_request=blood_request,
            donor=user,
            defaults={'response': keyword},
        )
        Notification.objects.filter(user=user, blood_request=blood_request).update(is_read=True)
        try:
            from careapp.donor_pool_service import handle_donor_response_for_pool
            handle_donor_response_for_pool(
                blood_request.id,
                user.id,
                keyword == 'accepted',
            )
        except Exception:
            logger.exception('WhatsApp pool update failed')
        if keyword == 'accepted':
            self.send_acceptance_message(conv.phone, blood_request)
        else:
            self.send_rejection_message(conv.phone, blood_request)
        self._broadcast_event('blood_response', {
            'conversation_id': conv.id,
            'blood_request_id': blood_request.id,
            'response': keyword,
        })

    def _save_outbound_message(
        self,
        conversation: WhatsAppConversation,
        body: str,
        wa_id: str,
        *,
        sender_type: str,
        sent_by=None,
        blood_request=None,
        status: str = WhatsAppMessage.STATUS_SENT,
        failed_reason: str = '',
    ) -> WhatsAppMessage:
        msg = WhatsAppMessage.objects.create(
            conversation=conversation,
            direction=WhatsAppMessage.DIRECTION_OUTBOUND,
            sender_type=sender_type,
            body=body,
            whatsapp_message_id=wa_id or '',
            status=status,
            failed_reason=failed_reason or '',
            sent_by=sent_by,
            blood_request=blood_request,
        )
        WhatsAppConversation.objects.filter(pk=conversation.pk).update(
            last_message_at=timezone.now(),
            last_message_preview=body[:255],
            unread_donor_count=F('unread_donor_count') + 1,
        )
        conversation.refresh_from_db()
        self._broadcast_message(conversation, msg)
        return msg

    def mark_conversation_read(self, conversation_id: int, *, by_admin: bool):
        conv = WhatsAppConversation.objects.filter(pk=conversation_id).first()
        if not conv:
            return
        if by_admin:
            conv.unread_admin_count = 0
            conv.save(update_fields=['unread_admin_count'])
        else:
            conv.unread_donor_count = 0
            conv.save(update_fields=['unread_donor_count'])

    # ------------------------------------------------------------------
    # WebSocket broadcast
    # ------------------------------------------------------------------

    def _broadcast_message(self, conv: WhatsAppConversation, msg: WhatsAppMessage):
        payload = {
            'type': 'chat_message',
            'conversation_id': conv.id,
            'message': self._serialize_message(msg),
            'unread_admin_count': conv.unread_admin_count,
            'unread_donor_count': conv.unread_donor_count,
        }
        self._broadcast_event('chat_message', payload, conversation_id=conv.id)

    def _broadcast_status(self, conversation_id: int, msg: WhatsAppMessage):
        self._broadcast_event('message_status', {
            'conversation_id': conversation_id,
            'message_id': msg.id,
            'status': msg.status,
        }, conversation_id=conversation_id)

    def _broadcast_event(
        self,
        event_type: str,
        payload: dict,
        conversation_id: Optional[int] = None,
    ):
        if not async_to_sync or not get_channel_layer:
            return
        layer = get_channel_layer()
        if not layer:
            return
        data = {'type': event_type, **payload}
        try:
            async_to_sync(layer.group_send)('whatsapp_admin', data)
            if conversation_id:
                async_to_sync(layer.group_send)(f'whatsapp_chat_{conversation_id}', data)
        except Exception:
            logger.exception('WebSocket broadcast failed')

    def _serialize_message(self, msg: WhatsAppMessage) -> dict:
        return {
            'id': msg.id,
            'direction': msg.direction,
            'sender_type': msg.sender_type,
            'body': msg.body,
            'message_type': msg.message_type,
            'status': msg.status,
            'media_url': msg.media_url,
            'created_at': msg.created_at.isoformat(),
            'whatsapp_message_id': msg.whatsapp_message_id,
        }


whatsapp_service = WhatsAppService()
