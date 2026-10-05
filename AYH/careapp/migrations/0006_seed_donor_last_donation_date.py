# Generated manually for Sprint 2 — seed DonorProfile.last_donation_date
# from UserProfile when donor field is empty. No schema change.

from django.db import migrations


def copy_userprofile_dates_to_donor(apps, schema_editor):
    UserProfile = apps.get_model('careapp', 'UserProfile')
    DonorProfile = apps.get_model('careapp', 'DonorProfile')
    for up in UserProfile.objects.exclude(last_donation_date__isnull=True).iterator():
        DonorProfile.objects.filter(
            user_id=up.user_id,
            last_donation_date__isnull=True,
        ).update(last_donation_date=up.last_donation_date)


def noop_reverse(apps, schema_editor):
    # Do not wipe donor dates on reverse — they may have been set independently.
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('careapp', '0005_whatsapp_chat'),
    ]

    operations = [
        migrations.RunPython(copy_userprofile_dates_to_donor, noop_reverse),
    ]
