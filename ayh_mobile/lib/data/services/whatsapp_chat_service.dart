import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';

class WhatsAppChatService {
  final ApiClient _api = ApiClient();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

  Future<int> fetchUnreadCount() async {
    final r = await _api.get(ApiConstants.whatsappUnread);
    return (r.data['unread'] as int?) ?? 0;
  }

  Future<List<dynamic>> fetchConversations() async {
    final r = await _api.get(ApiConstants.whatsappConversations);
    return r.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> fetchMessages(int conversationId, {int page = 1}) async {
    final r = await _api.get(
      ApiConstants.whatsappMessages(conversationId),
      queryParameters: {'page': page, 'page_size': 50},
    );
    return r.data as Map<String, dynamic>;
  }

  Future<void> sendMessage(int conversationId, String body) async {
    try {
      await _api.post(
        ApiConstants.whatsappSend(conversationId),
        data: {'body': body},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      throw Exception(e.message ?? 'Failed to send message');
    }
  }

  void connectWebSocket(String accessToken) {
    disconnectWebSocket();
    final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/$'), '');
    final host = base.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$host/ws/whatsapp/donor/?token=$accessToken');
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      (raw) {
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          _eventController.add(data);
        } catch (_) {}
      },
      onError: (_) => _eventController.add({'type': 'ws_error'}),
    );
  }

  void disconnectWebSocket() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnectWebSocket();
    _eventController.close();
  }
}
