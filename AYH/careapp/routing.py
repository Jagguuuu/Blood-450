from django.urls import re_path

from . import consumers

websocket_urlpatterns = [
    re_path(r'ws/whatsapp/admin/$', consumers.WhatsAppAdminConsumer.as_asgi()),
    re_path(r'ws/whatsapp/donor/$', consumers.WhatsAppDonorConsumer.as_asgi()),
]
