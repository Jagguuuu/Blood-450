import '../models/leaderboard_model.dart';
import '../services/leaderboard_service.dart';

class LeaderboardRepository {
  final LeaderboardService _service = LeaderboardService();

  Future<LeaderboardData> getLeaderboard() async {
    final data = await _service.getLeaderboard();
    if (data == null) {
      throw Exception('Unable to load leaderboard');
    }
    return data;
  }
}
