"""WebSocket consumers for live WhatsApp chat."""
import json

from channels.generic.websocket import AsyncJsonWebsocketConsumer
from channels.db import database_sync_to_async


class WhatsAppAdminConsumer(AsyncJsonWebsocketConsumer):
    """Admin/staff: all conversations + typing."""

    async def connect(self):
        user = self.scope.get('user')
        if not user or not user.is_authenticated or not user.is_staff:
            await self.close()
            return
        await self.channel_layer.group_add('whatsapp_admin', self.channel_name)
        await self.accept()
        await self.send_json({'type': 'connected', 'role': 'admin'})

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard('whatsapp_admin', self.channel_name)

    async def receive_json(self, content, **kwargs):
        action = content.get('action')
        if action == 'typing':
            conv_id = content.get('conversation_id')
            if conv_id:
                await self.channel_layer.group_send(
                    f'whatsapp_chat_{conv_id}',
                    {
                        'type': 'typing_indicator',
                        'conversation_id': conv_id,
                        'admin_typing': content.get('typing', False),
                    },
                )
        elif action == 'subscribe' and content.get('conversation_id'):
            await self.channel_layer.group_add(
                f'whatsapp_chat_{content["conversation_id"]}',
                self.channel_name,
            )

    async def chat_message(self, event):
        await self.send_json(event)

    async def message_status(self, event):
        await self.send_json(event)

    async def blood_response(self, event):
        await self.send_json(event)

    async def typing_indicator(self, event):
        await self.send_json(event)


class WhatsAppDonorConsumer(AsyncJsonWebsocketConsumer):
    """Donor: own conversation only."""

    async def connect(self):
        user = self.scope.get('user')
        if not user or not user.is_authenticated or user.is_staff:
            await self.close()
            return
        conv = await self._get_donor_conversation(user)
        if not conv:
            await self.close()
            return
        self.conversation_id = conv.id
        await self.channel_layer.group_add(
            f'whatsapp_chat_{conv.id}',
            self.channel_name,
        )
        await self.accept()
        await self.send_json({
            'type': 'connected',
            'role': 'donor',
            'conversation_id': conv.id,
        })

    async def disconnect(self, close_code):
        if hasattr(self, 'conversation_id'):
            await self.channel_layer.group_discard(
                f'whatsapp_chat_{self.conversation_id}',
                self.channel_name,
            )

    @database_sync_to_async
    def _get_donor_conversation(self, user):
        from careapp.whatsapp_models import WhatsAppConversation
        return WhatsAppConversation.objects.filter(donor_user=user).order_by('-last_message_at').first()

    async def chat_message(self, event):
        await self.send_json(event)

    async def message_status(self, event):
        await self.send_json(event)

    async def typing_indicator(self, event):
        await self.send_json(event)
