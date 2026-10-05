"""Ensure default admin user (admin/admin) exists after migrations."""
from django.db.models.signals import post_migrate
from django.dispatch import receiver
from django.contrib.auth.models import User


@receiver(post_migrate)
def ensure_admin_user(sender, **kwargs):
    """Create or reset admin user (username: admin, password: admin) after migrations."""
    if sender.name != "careapp":
        return
    try:
        if User.objects.filter(username="admin").exists():
            user = User.objects.get(username="admin")
            user.set_password("admin")
            user.is_staff = True
            user.is_superuser = True
            user.is_active = True
            user.save()
        else:
            User.objects.create_superuser(
                username="admin",
                email="admin@example.com",
                password="admin",
            )
    except Exception:
        pass
