import json
from channels.generic.websocket import AsyncWebsocketConsumer


class CallConsumer(AsyncWebsocketConsumer):
    """每个登录用户一个 WebSocket 连接，用于接来电"""

    async def connect(self):
        self.user_id = self.scope['url_route']['kwargs']['user_id']
        self.group_name = f'call_{self.user_id}'

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        print(f'✅ WebSocket connected: user {self.user_id}')

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)
        print(f'❌ WebSocket disconnected: user {self.user_id}')

    async def receive(self, text_data):
        # 客户端不需要主动发消息
        pass

    async def call_notify(self, event):
        """收到 group_send 的来电事件，推给客户端"""
        await self.send(text_data=json.dumps({
            'type': 'incoming_call',
            'caller_id': event['caller_id'],
            'caller_name': event['caller_name'],
            'caller_avatar': event['caller_avatar'],
            'call_type': event['call_type'],
            'peer_id': event['peer_id'],
        }))

    async def call_sfx(self, event):
        await self.send(text_data=json.dumps({
            'type': 'call_sfx',
            'sfx': event['sfx'],
        }))