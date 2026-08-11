"""
Verify WhatsApp dev flow configuration and optionally simulate inbound + auto-reply.

  python manage.py whatsapp_check_flow
  python manage.py whatsapp_check_flow --simulate 919876543210 "Hi Blood450"
"""
from django.conf import settings
from django.core.management.base import BaseCommand

from careapp.services.whatsapp_providers import get_whatsapp_provider
from careapp.services.whatsapp_messaging import receive_whatsapp_message


class Command(BaseCommand):
    help = 'Check Meta WhatsApp webhook/send configuration and optional inbound simulation'

    def add_arguments(self, parser):
        parser.add_argument(
            '--simulate',
            nargs=2,
            metavar=('PHONE', 'MESSAGE'),
            help='Simulate donor inbound e.g. 919876543210 "Hello"',
        )

    def handle(self, *args, **options):
        self.stdout.write('=== Blood450 WhatsApp flow check ===\n')

        provider = getattr(settings, 'WHATSAPP_PROVIDER', 'console')
        phone_id = getattr(settings, 'WHATSAPP_PHONE_NUMBER_ID', '') or ''
        token = bool(getattr(settings, 'WHATSAPP_ACCESS_TOKEN', None))
        verify = getattr(settings, 'WHATSAPP_VERIFY_TOKEN', '')
        display = getattr(settings, 'WHATSAPP_BASE_PHONE_DISPLAY', '') or '(set WHATSAPP_BASE_PHONE_DISPLAY)'
        auto = getattr(settings, 'WHATSAPP_AUTO_REPLY_ENABLED', True)
        proactive = getattr(settings, 'WHATSAPP_PROACTIVE_OUTBOUND', False)

        self.stdout.write(f'Provider:              {provider}')
        self.stdout.write(f'Phone number ID:       {phone_id or "MISSING"}')
        self.stdout.write(f'Access token set:      {token}')
        self.stdout.write(f'Verify token:          {verify}')
        self.stdout.write(f'Business display:      {display}')
        self.stdout.write(f'Auto-reply enabled:    {auto}')
        self.stdout.write(f'Proactive outbound:    {proactive}')
        self.stdout.write(f'Webhook path:          /api/whatsapp/webhook/')
        self.stdout.write(f'Active provider class: {get_whatsapp_provider().__class__.__name__}\n')

        self.stdout.write('Expected dev flow:')
        self.stdout.write('  1. Donor uses personal WhatsApp (NOT a Business API number).')
        self.stdout.write(f'  2. Donor messages Meta test business line {display}.')
        self.stdout.write('  3. Add donor phone in Meta > WhatsApp > API Setup > test recipients.')
        self.stdout.write('  4. Meta POSTs to your public webhook URL (ngrok/cloudflared -> Django).')
        self.stdout.write('  5. Django stores inbound + sends auto-reply via Cloud API.\n')

        if not phone_id or not token:
            self.stdout.write(self.style.WARNING('Configure WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_ACCESS_TOKEN in .env'))

        sim = options.get('simulate')
        if sim:
            phone, message = sim
            self.stdout.write(f'Simulating inbound from {phone}: {message!r}\n')
            result = receive_whatsapp_message(phone, message, whatsapp_message_id='check-flow-test')
            auto = result.get('auto_reply') or {}
            if auto.get('ok'):
                self.stdout.write(self.style.SUCCESS('Inbound + auto-reply OK'))
            elif auto:
                err = str(auto.get('error', 'unknown')).encode('ascii', 'replace').decode()
                self.stdout.write(self.style.WARNING(f'Inbound stored; auto-reply failed: {err}'))
            else:
                self.stdout.write(self.style.SUCCESS(f'Inbound stored: {result}'))

        self.stdout.write('\nMeta webhook test (replace HOST):')
        self.stdout.write(
            f'  GET https://HOST/api/whatsapp/webhook/?hub.mode=subscribe'
            f'&hub.verify_token={verify}&hub.challenge=12345'
        )
