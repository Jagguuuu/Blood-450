import 'package:flutter/foundation.dart';
import '../../data/models/leaderboard_model.dart';
import '../../data/repositories/leaderboard_repository.dart';

class LeaderboardProvider with ChangeNotifier {
  final LeaderboardRepository _repository = LeaderboardRepository();

  LeaderboardData? _data;
  bool _isLoading = false;
  String? _error;

  List<LeaderboardEntry> get topDonors => _data?.topDonors ?? [];
  LeaderboardCurrentUser? get currentUser => _data?.currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasData => _data != null;

  Future<void> loadLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _repository.getLeaderboard();
      _error = null;
    } catch (e) {
      _error = 'Unable to load leaderboard. Please try again.';
    }

    _isLoading = false;
    notifyListeners();
  }
}
