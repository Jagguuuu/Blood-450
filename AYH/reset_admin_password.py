#!/usr/bin/env python
"""
Script to ensure admin superuser exists and reset password to 'admin123'
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'AYH.settings')
django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()

try:
    user, created = User.objects.get_or_create(
        username='admin', 
        defaults={'email': 'admin@example.com'}
    )
    user.set_password('admin123')
    user.is_superuser = True
    user.is_staff = True
    user.save()
    
    action = "Created" if created else "Updated"
    print(f"SUCCESS: {action} user 'admin' with password 'admin123'")
except Exception as e:
    print(f"ERROR: Failed to reset admin password: {e}")