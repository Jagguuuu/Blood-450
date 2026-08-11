import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/dashboard_stats.dart';

class DashboardService {
  final ApiClient _apiClient = ApiClient();

  Future<DashboardStats?> getDashboardStats() async {
    try {
      final response = await _apiClient.get(ApiConstants.dashboard);
      if (response.statusCode == 200) {
        return DashboardStats.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return null;
    }
  }
}
