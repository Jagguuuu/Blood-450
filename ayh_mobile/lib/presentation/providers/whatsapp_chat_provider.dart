import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../data/services/whatsapp_chat_service.dart';

class WhatsAppChatProvider with ChangeNotifier {
  final WhatsAppChatService _service = WhatsAppChatService();

  int _unread = 0;
  bool _loading = false;
  String? _error;
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  int? _activeConversationId;
  String _chatTitle = 'Support';

  int get unread => _unread;
  bool get isLoading => _loading;
  String? get error => _error;
  List<dynamic> get messages => _messages;
  int? get activeConversationId => _activeConversationId;
  String get chatTitle => _chatTitle;

  Future<void> loadUnread() async {
    try {
      _unread = await _service.fetchUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> initChat() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final token = await ApiClient().getAccessToken();
      if (token != null && token.isNotEmpty) {
        _service.connectWebSocket(token);
        _service.events.listen((ev) {
          if (ev['type'] == 'chat_message') {
            if (ev['conversation_id'] == _activeConversationId) {
              loadMessages(_activeConversationId!);
            }
            loadUnread();
          }
        });
      }
      _conversations = await _service.fetchConversations();
      if (_conversations.isNotEmpty) {
        final id = _conversations.first['id'] as int;
        await loadMessages(id);
      }
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadMessages(int conversationId) async {
    _activeConversationId = conversationId;
    try {
      final data = await _service.fetchMessages(conversationId);
      _messages = data['messages'] as List<dynamic>? ?? [];
      final conv = data['conversation'] as Map<String, dynamic>?;
      _chatTitle = conv?['donor_name']?.toString() ?? 'Blood450 Support';
      await loadUnread();
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  Future<bool> send(String body) async {
    if (_activeConversationId == null || body.trim().isEmpty) return false;
    try {
      await _service.sendMessage(_activeConversationId!, body.trim());
      await loadMessages(_activeConversationId!);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
