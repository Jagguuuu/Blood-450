# Generated migration: allow blank phone for Google sign-in donors

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('careapp', '0003_alter_requesttimeline_event_type'),
    ]

    operations = [
        migrations.AlterField(
            model_name='donorprofile',
            name='phone',
            field=models.CharField(blank=True, max_length=15),
        ),
    ]
