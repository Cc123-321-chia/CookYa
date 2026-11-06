import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../utils/url_helper.dart';

class CallWebSocketService {
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static Function(Map<String, dynamic>)? onIncomingCall;

  static void connect() {
    final userId = ApiService.currentUserId;
    if (userId == null) return;

    final wsUrl = '${UrlHelper.wsBaseUrl}/ws/call/$userId/';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    _subscription = _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data);
        if (msg['type'] == 'incoming_call') {
          onIncomingCall?.call(msg);
        }
      },
      onError: (e) => print('WS error: $e'),
      onDone: () {
        // 自动重连
        Future.delayed(const Duration(seconds: 2), connect);
      },
    );
  }

  static void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
  }
}