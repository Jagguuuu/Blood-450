"""
Meta WhatsApp Cloud API webhook — GET verify, POST inbound + statuses.

Flow: donor personal WhatsApp → Meta test business number → this webhook →
receive_whatsapp_message() → auto-reply via Cloud API (same business number).

POST /api/whatsapp/webhook/
"""
import json
import logging

from django.conf import settings
from django.http import HttpResponse, JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from careapp.services.whatsapp_messaging import receive_whatsapp_message
from careapp.services.whatsapp_service import whatsapp_service
from careapp.services.whatsapp_utils import verify_webhook_signature

logger = logging.getLogger(__name__)


def _expected_phone_number_id() -> str:
    return str(getattr(settings, 'WHATSAPP_PHONE_NUMBER_ID', '') or '').strip()


def _webhook_phone_number_id(value: dict) -> str:
    meta = value.get('metadata') or {}
    return str(meta.get('phone_number_id') or '').strip()


def _should_process_value(value: dict) -> bool:
    """Only process events for our configured Meta business phone_number_id."""
    if not getattr(settings, 'WHATSAPP_VALIDATE_PHONE_NUMBER_ID', True):
        return True
    expected = _expected_phone_number_id()
    if not expected:
        return True
    incoming = _webhook_phone_number_id(value)
    if not incoming:
        return True
    if incoming != expected:
        print(
            f'[WEBHOOK] Ignoring event for phone_number_id={incoming} '
            f'(expected {expected})'
        )
        logger.warning(
            'Webhook ignored: phone_number_id %s != WHATSAPP_PHONE_NUMBER_ID %s',
            incoming,
            expected,
        )
        return False
    return True


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def whatsapp_webhook(request):
    remote = request.META.get('HTTP_X_FORWARDED_FOR') or request.META.get('REMOTE_ADDR', '?')
    print(f'[WEBHOOK] {request.method} from {remote} path={request.path}')
    logger.info('WhatsApp webhook %s from %s', request.method, remote)

    if request.method == 'GET':
        mode = request.GET.get('hub.mode')
        token = request.GET.get('hub.verify_token')
        challenge = request.GET.get('hub.challenge')
        verify = getattr(settings, 'WHATSAPP_VERIFY_TOKEN', '')
        if mode == 'subscribe' and token == verify:
            print('[WEBHOOK] Meta verification OK')
            return HttpResponse(challenge, content_type='text/plain')
        print(f'[WEBHOOK] Verify FAILED mode={mode} token_match={token == verify}')
        return HttpResponse('Forbidden', status=403)

    raw = request.body or b''
    sig = request.META.get('HTTP_X_HUB_SIGNATURE_256')
    skip_sig = getattr(settings, 'WHATSAPP_WEBHOOK_SKIP_SIGNATURE', settings.DEBUG)
    if not skip_sig and not verify_webhook_signature(raw, sig):
        logger.warning('WhatsApp webhook signature invalid')
        print('[WEBHOOK] POST rejected: invalid signature')
        return HttpResponse('Invalid signature', status=403)

    try:
        payload = json.loads(raw.decode('utf-8'))
    except (json.JSONDecodeError, UnicodeDecodeError):
        print('[WEBHOOK] POST rejected: bad JSON')
        return HttpResponse('Bad JSON', status=400)

    print(f'[WEBHOOK] POST object={payload.get("object")} entries={len(payload.get("entry", []))}')
    _process_webhook_payload(payload)
    return JsonResponse({'status': 'ok'})


def _process_webhook_payload(payload: dict):
    obj = payload.get('object', '')
    if obj and obj != 'whatsapp_business_account':
        logger.warning('Webhook unexpected object: %s', obj)
        print(f'[WEBHOOK] Unexpected object={obj}')

    for entry in payload.get('entry', []):
        for change in entry.get('changes', []):
            field = change.get('field', '')
            value = change.get('value', {}) or {}
            if not _should_process_value(value):
                continue
            if field and field != 'messages':
                logger.debug('Webhook change field=%s', field)

            for status_obj in value.get('statuses', []):
                whatsapp_service.handle_status_update(
                    status_obj.get('id', ''),
                    status_obj.get('status', ''),
                    status_obj.get('errors'),
                )

            contacts = value.get('contacts') or []
            profile_name = ''
            if contacts:
                profile_name = (contacts[0].get('profile') or {}).get('name', '') or ''

            for msg in value.get('messages', []):
                _handle_inbound_message(msg, profile_name=profile_name)


def _handle_inbound_message(msg: dict, profile_name: str = ''):
    # Donor personal number — NOT a WABA number. Meta puts it in `from`.
    msg_type = msg.get('type', 'text')
    phone = msg.get('from', '')
    wa_id = msg.get('id', '')
    body = ''
    media_url = ''

    if not phone:
        print('[WEBHOOK] Inbound message missing `from` — skipped')
        return

    if msg_type == 'text':
        body = (msg.get('text') or {}).get('body', '')
    elif msg_type in ('image', 'document', 'audio', 'video'):
        body = f'[{msg_type}]'
        media = msg.get(msg_type) or {}
        media_url = media.get('id', '')
    else:
        body = f'[{msg_type}]'

    print(f'[WEBHOOK] IN from={phone} type={msg_type} id={wa_id} text={body[:80]!r}')
    receive_whatsapp_message(
        phone,
        body,
        whatsapp_message_id=wa_id,
        message_type=msg_type if msg_type in ('text', 'image', 'document') else 'text',
        media_url=media_url,
        profile_name=profile_name,
    )
