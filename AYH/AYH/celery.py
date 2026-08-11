import os

from celery import Celery

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'AYH.settings')

app = Celery('AYH')
app.config_from_object('django.conf:settings', namespace='CELERY')
app.autodiscover_tasks(['careapp.tasks'])
