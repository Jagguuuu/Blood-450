import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../models/leaderboard_model.dart';

class LeaderboardService {
  final ApiClient _apiClient = ApiClient();

  Future<LeaderboardData?> getLeaderboard() async {
    try {
      final response = await _apiClient.get(ApiConstants.leaderboard);
      if (response.statusCode == 200) {
        return LeaderboardData.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
