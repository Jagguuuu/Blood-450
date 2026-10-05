import '../services/notification_service.dart';
import '../services/response_service.dart';
import '../models/notification.dart';

/// Notifications via Django API (Vercel). Supabase is the database on the server only.
class NotificationRepository {
  final NotificationService _notificationService = NotificationService();
  final ResponseService _responseService = ResponseService();

  Future<List<NotificationModel>> getMyNotifications() async {
    return await _notificationService.getMyNotifications();
  }

  Future<NotificationModel?> getNotificationDetail(int id) async {
    return await _notificationService.getNotificationDetail(id);
  }

  Future<bool> markAsRead(int id) async {
    return await _notificationService.markAsRead(id);
  }

  Future<bool> markAllAsRead() async {
    return await _notificationService.markAllAsRead();
  }

  Future<Map<String, dynamic>> respondToRequest({
    required int bloodRequestId,
    required String response,
  }) async {
    return await _responseService.respondToRequest(
      bloodRequestId: bloodRequestId,
      response: response,
    );
  }
}
