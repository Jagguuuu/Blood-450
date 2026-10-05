# Generated manually for Active/Standby donor pool

from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('careapp', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='RequestDonorPoolAssignment',
            fields=[
                ('id', models.AutoField(primary_key=True, serialize=False)),
                ('distance_km', models.FloatField(blank=True, help_text='Distance at assignment time', null=True)),
                ('pool_type', models.CharField(choices=[('ACTIVE', 'Active'), ('STANDBY', 'Standby')], default='ACTIVE', max_length=10)),
                ('state', models.CharField(choices=[('PENDING', 'Pending'), ('ACCEPTED', 'Accepted'), ('REJECTED', 'Rejected'), ('TIMEOUT', 'Timeout'), ('DROPPED', 'Dropped')], default='PENDING', max_length=10)),
                ('rank', models.PositiveIntegerField(default=0, help_text='Order by distance; lower = closer')),
                ('notified_at', models.DateTimeField(blank=True, null=True)),
                ('responded_at', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('donor', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='pool_assignments', to=settings.AUTH_USER_MODEL)),
                ('request', models.ForeignKey(db_column='request_id', on_delete=django.db.models.deletion.CASCADE, related_name='pool_assignments', to='careapp.bloodrequest')),
            ],
            options={
                'verbose_name': 'Request donor pool assignment',
                'ordering': ['rank', 'id'],
                'unique_together': {('request', 'donor')},
            },
        ),
    ]
