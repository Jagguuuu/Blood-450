from django.apps import AppConfig


class CareappConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'careapp'

    def ready(self):
        import careapp.signals  # noqa: F401 - register post_migrate to ensure admin user

def _ensure_admin_user():
    from django.contrib.auth.models import User
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
