"""Pluggable WhatsApp providers — Meta Cloud API (primary), Twilio (fallback)."""
import logging
import re
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional

import requests
from django.conf import settings

logger = logging.getLogger(__name__)


class BaseWhatsAppProvider(ABC):
    @abstractmethod
    def send_text(self, phone: str, message: str) -> Dict[str, Any]:
        pass

    @abstractmethod
    def send_template(
        self,
        phone: str,
        template_name: str,
        variables: Optional[List[str]] = None,
        language_code: str = 'en',
    ) -> Dict[str, Any]:
        pass


class ConsoleWhatsAppProvider(BaseWhatsAppProvider):
    """Development: log messages instead of sending."""

    def send_text(self, phone: str, message: str) -> Dict[str, Any]:
        logger.info('[WhatsApp console] to=%s body=%s', phone, message[:200])
        return {'ok': True, 'provider': 'console', 'message_id': f'console-{phone}'}

    def send_template(
        self,
        phone: str,
        template_name: str,
        variables: Optional[List[str]] = None,
        language_code: str = 'en',
    ) -> Dict[str, Any]:
        logger.info(
            '[WhatsApp console] template to=%s name=%s vars=%s',
            phone,
            template_name,
            variables,
        )
        return {'ok': True, 'provider': 'console', 'message_id': f'console-tpl-{phone}'}


class MetaCloudWhatsAppProvider(BaseWhatsAppProvider):
    """Meta WhatsApp Cloud API."""

    def __init__(self):
        self.token = settings.WHATSAPP_ACCESS_TOKEN
        self.phone_id = settings.WHATSAPP_PHONE_NUMBER_ID
        version = getattr(settings, 'WHATSAPP_API_VERSION', 'v20.0')
        self.base_url = f'https://graph.facebook.com/{version}/{self.phone_id}/messages'

    def _post(self, payload: dict) -> Dict[str, Any]:
        if not self.token or not self.phone_id:
            return {'ok': False, 'error': 'WhatsApp Cloud API not configured'}
        try:
            r = requests.post(
                self.base_url,
                headers={
                    'Authorization': f'Bearer {self.token}',
                    'Content-Type': 'application/json',
                },
                json=payload,
                timeout=30,
            )
            data = r.json() if r.content else {}
            if r.status_code >= 400:
                return {'ok': False, 'error': data, 'status_code': r.status_code}
            msg_id = ''
            messages = data.get('messages') or []
            if messages:
                msg_id = messages[0].get('id', '')
            return {'ok': True, 'provider': 'meta', 'message_id': msg_id, 'response': data}
        except requests.RequestException as exc:
            logger.exception('Meta WhatsApp send failed')
            return {'ok': False, 'error': str(exc)}

    def send_text(self, phone: str, message: str) -> Dict[str, Any]:
        to = re.sub(r'\D', '', str(phone or ''))
        if not to:
            return {'ok': False, 'error': 'Invalid recipient phone'}
        return self._post({
            'messaging_product': 'whatsapp',
            'recipient_type': 'individual',
            'to': to,
            'type': 'text',
            'text': {'body': message[:4096]},
        })

    def send_template(
        self,
        phone: str,
        template_name: str,
        variables: Optional[List[str]] = None,
        language_code: str = 'en',
    ) -> Dict[str, Any]:
        components = []
        if variables:
            components.append({
                'type': 'body',
                'parameters': [{'type': 'text', 'text': str(v)} for v in variables],
            })
        to = re.sub(r'\D', '', str(phone or ''))
        payload = {
            'messaging_product': 'whatsapp',
            'recipient_type': 'individual',
            'to': to,
            'type': 'template',
            'template': {
                'name': template_name,
                'language': {'code': language_code},
            },
        }
        if components:
            payload['template']['components'] = components
        return self._post(payload)


class TwilioWhatsAppProvider(BaseWhatsAppProvider):
    """Twilio WhatsApp fallback."""

    def __init__(self):
        self.sid = settings.TWILIO_ACCOUNT_SID
        self.token = settings.TWILIO_AUTH_TOKEN
        self.from_number = getattr(settings, 'TWILIO_WHATSAPP_FROM', None) or settings.TWILIO_FROM_NUMBER

    def send_text(self, phone: str, message: str) -> Dict[str, Any]:
        if not all([self.sid, self.token, self.from_number]):
            return {'ok': False, 'error': 'Twilio WhatsApp not configured'}
        try:
            from twilio.rest import Client
            client = Client(self.sid, self.token)
            to = phone if phone.startswith('whatsapp:') else f'whatsapp:+{phone}'
            frm = self.from_number
            if not frm.startswith('whatsapp:'):
                frm = f'whatsapp:{frm}' if frm.startswith('+') else f'whatsapp:+{frm}'
            msg = client.messages.create(body=message[:1600], from_=frm, to=to)
            return {'ok': True, 'provider': 'twilio', 'message_id': msg.sid}
        except Exception as exc:
            logger.exception('Twilio WhatsApp send failed')
            return {'ok': False, 'error': str(exc)}

    def send_template(
        self,
        phone: str,
        template_name: str,
        variables: Optional[List[str]] = None,
        language_code: str = 'en',
    ) -> Dict[str, Any]:
        body = f'[{template_name}] ' + ' | '.join(variables or [])
        return self.send_text(phone, body)


def get_whatsapp_provider() -> BaseWhatsAppProvider:
    backend = getattr(settings, 'WHATSAPP_PROVIDER', 'console').lower()
    if backend == 'meta' and settings.WHATSAPP_ACCESS_TOKEN and settings.WHATSAPP_PHONE_NUMBER_ID:
        return MetaCloudWhatsAppProvider()
    if backend == 'twilio' and settings.TWILIO_ACCOUNT_SID:
        return TwilioWhatsAppProvider()
    if settings.WHATSAPP_ACCESS_TOKEN and settings.WHATSAPP_PHONE_NUMBER_ID:
        return MetaCloudWhatsAppProvider()
    return ConsoleWhatsAppProvider()
