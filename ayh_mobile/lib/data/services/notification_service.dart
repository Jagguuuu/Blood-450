import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/notification.dart';

class NotificationService {
  final ApiClient _apiClient = ApiClient();

  Future<List<NotificationModel>> getMyNotifications() async {
    try {
      final response = await _apiClient.get(ApiConstants.notifications);
      if (response.statusCode == 200) {
        // API may return paginated { "results": [...] } or direct list
        final data = response.data;
        List<dynamic> list;
        if (data is List) {
          list = data;
        } else if (data is Map && data['results'] != null) {
          list = data['results'] as List;
        } else {
          return [];
        }
        return list
            .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<NotificationModel?> getNotificationDetail(int id) async {
    try {
      final response = await _apiClient.get('${ApiConstants.notifications}$id/');
      if (response.statusCode == 200) {
        return NotificationModel.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error getting notification detail: $e');
      return null;
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      final response = await _apiClient.post('${ApiConstants.notifications}$id/mark_read/');
      return response.statusCode == 200;
    } catch (e) {
      print('Error marking as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiClient.post(ApiConstants.notificationMarkAllRead);
      return response.statusCode == 200;
    } catch (e) {
      print('Error marking all as read: $e');
      return false;
    }
  }
}
