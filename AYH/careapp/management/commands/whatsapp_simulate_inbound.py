"""
Simulate an inbound WhatsApp message locally (no Meta needed).

  python manage.py whatsapp_simulate_inbound 919876543210 "Hello from test"
"""
from django.core.management.base import BaseCommand

from careapp.services.whatsapp_messaging import receive_whatsapp_message


class Command(BaseCommand):
    help = 'Simulate donor WhatsApp inbound message for testing admin inbox'

    def add_arguments(self, parser):
        parser.add_argument('phone', help='Donor phone e.g. 919876543210')
        parser.add_argument('message', help='Message text')

    def handle(self, *args, **options):
        result = receive_whatsapp_message(
            options['phone'],
            options['message'],
            whatsapp_message_id='local-test',
        )
        self.stdout.write(self.style.SUCCESS(str(result)))
