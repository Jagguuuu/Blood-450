import '../services/dashboard_service.dart';
import '../models/dashboard_stats.dart';

/// Dashboard stats via Django API (Vercel). Supabase is the database on the server only.
class DashboardRepository {
  final DashboardService _service = DashboardService();

  Future<DashboardStats?> getDashboardStats() async {
    return await _service.getDashboardStats();
  }
}
