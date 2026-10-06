"""Context processors for careapp."""


def admin_notifications(request):
    """Add admin notification count and list for staff users (for bell icon and modal)."""
    if not getattr(request, 'user', None) or not request.user.is_authenticated or not request.user.is_staff:
        return {
            'admin_notification_count': 0,
            'admin_notifications': [],
            'admin_unresolved_delay_count': 0,
        }
    # Keep initial render lightweight; JS will fetch live data on demand.
    return {
        'admin_notification_count': 0,
        'admin_notifications': [],
        'admin_unresolved_delay_count': 0,
    }


def donor_notification_count(request):
    """Unread donor notification count + donor-complete flag for SSR."""
    if not getattr(request, 'user', None) or not request.user.is_authenticated or request.user.is_staff:
        return {'donor_notification_count': 0, 'is_complete_donor': False}
    try:
        from .models import Notification, DonorProfile
        count = Notification.objects.filter(user=request.user, is_read=False).count()
        profile = DonorProfile.objects.filter(user=request.user).only('blood_group').first()
        is_complete = bool(profile and (profile.blood_group or '').strip())
    except Exception:
        count = 0
        is_complete = False
    return {
        'donor_notification_count': count,
        'is_complete_donor': is_complete,
    }
