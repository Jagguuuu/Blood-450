#!/usr/bin/env python
"""
Script to reset admin password to 'admin'
Run: python reset_admin_password.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'AYH.settings')
django.setup()

from django.contrib.auth.models import User

try:
    user = User.objects.get(username='admin')
    user.set_password('admin')
    user.save()
    print(f'SUCCESS: Password for user "{user.username}" has been reset to "admin"')
    print(f'   You can now login with username: {user.username} and password: admin')
except User.DoesNotExist:
    print('ERROR: User "admin" does not exist')
    print('   Creating superuser "admin" with password "admin"...')
    user = User.objects.create_superuser('admin', '', 'admin')
    print(f'SUCCESS: Created superuser "{user.username}" with password "admin"')
