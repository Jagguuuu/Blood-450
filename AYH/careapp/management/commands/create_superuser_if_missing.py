"""
Create a superuser from environment variables (for Supabase/Vercel setup).
Usage:
  Set SUPERUSER_USERNAME and SUPERUSER_PASSWORD (and optionally SUPERUSER_EMAIL), then:
  python manage.py create_superuser_if_missing
"""
import os
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User


class Command(BaseCommand):
    help = "Create a superuser from env SUPERUSER_USERNAME, SUPERUSER_PASSWORD, SUPERUSER_EMAIL (optional)."

    def add_arguments(self, parser):
        parser.add_argument(
            '--username',
            type=str,
            help='Override username (default: from SUPERUSER_USERNAME env)',
        )
        parser.add_argument(
            '--password',
            type=str,
            help='Override password (default: from SUPERUSER_PASSWORD env)',
        )

    def handle(self, *args, **options):
        username = options.get('username') or os.environ.get('SUPERUSER_USERNAME', 'admin')
        password = options.get('password') or os.environ.get('SUPERUSER_PASSWORD')
        email = os.environ.get('SUPERUSER_EMAIL', '')

        if not password:
            self.stderr.write(
                'Set SUPERUSER_PASSWORD in .env or pass --password. Example: '
                'SUPERUSER_USERNAME=admin SUPERUSER_PASSWORD=YourPass python manage.py create_superuser_if_missing'
            )
            return

        username = username.strip().lower()
        if not username:
            self.stderr.write('Username cannot be empty.')
            return

        if User.objects.filter(username=username).exists():
            user = User.objects.get(username=username)
            user.set_password(password)
            user.is_staff = True
            user.is_superuser = True
            user.is_active = True
            user.save()
            self.stdout.write(self.style.SUCCESS(f'Superuser "{username}" updated (password reset).'))
        else:
            User.objects.create_superuser(
                username=username,
                email=email or f'{username}@example.com',
                password=password,
            )
            self.stdout.write(self.style.SUCCESS(f'Superuser "{username}" created. You can now log in.'))
