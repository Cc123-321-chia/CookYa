from django.urls import path
from . import consumers

websocket_urlpatterns = [
    path('ws/call/<str:user_id>/', consumers.CallConsumer.as_asgi()),
]