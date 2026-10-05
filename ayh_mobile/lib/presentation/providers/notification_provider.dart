import 'package:flutter/foundation.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/models/notification.dart';
import '../../data/services/storage_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationRepository _repository = NotificationRepository();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _acceptanceCount = 0;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  int get acceptanceCount => _acceptanceCount;
  /// Bell badge: unread notifications + acceptance count (increases when donor accepts)
  int get badgeCount => unreadCount + _acceptanceCount;
  List<NotificationModel> get unreadNotifications => 
      _notifications.where((n) => !n.isRead).toList();

  Future<void> loadNotifications() async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _repository.getMyNotifications();
      _error = null;
      _acceptanceCount = await StorageService().getAcceptanceCount();
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearAcceptanceCount() async {
    await StorageService().clearAcceptanceCount();
    _acceptanceCount = 0;
    notifyListeners();
  }

  Future<bool> markAsRead(int id) async {
    final success = await _repository.markAsRead(id);
    if (success) {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          bloodRequest: _notifications[index].bloodRequest,
          isRead: true,
          createdAt: _notifications[index].createdAt,
          hasResponded: _notifications[index].hasResponded,
          responseStatus: _notifications[index].responseStatus,
          respondedAt: _notifications[index].respondedAt,
        );
        notifyListeners();
      }
    }
    return success;
  }

  Future<bool> markAllAsRead() async {
    final success = await _repository.markAllAsRead();
    if (success) {
      await loadNotifications();
    }
    return success;
  }

  Future<Map<String, dynamic>> respondToRequest({
    required int bloodRequestId,
    required String response,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.respondToRequest(
        bloodRequestId: bloodRequestId,
        response: response,
      );
      
      if (result['success']) {
        if (response == 'accepted') {
          await StorageService().incrementAcceptanceCount();
          _acceptanceCount = await StorageService().getAcceptanceCount();
        }
        await loadNotifications();
      } else {
        _error = result['error'];
      }
      
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': e.toString()};
    }
  }
}
