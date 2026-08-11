import 'blood_request.dart';

class DashboardStats {
  final int totalRequests;
  final int activeRequests;
  final int totalDonors;
  final int availableDonors;
  final int totalAccepted;
  final int criticalRequests;
  final List<BloodRequest> recentRequests;

  DashboardStats({
    required this.totalRequests,
    required this.activeRequests,
    required this.totalDonors,
    required this.availableDonors,
    required this.totalAccepted,
    required this.criticalRequests,
    required this.recentRequests,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalRequests: json['total_requests'] ?? 0,
      activeRequests: json['active_requests'] ?? 0,
      totalDonors: json['total_donors'] ?? 0,
      availableDonors: json['available_donors'] ?? 0,
      totalAccepted: json['total_accepted'] ?? 0,
      criticalRequests: json['critical_requests'] ?? 0,
      recentRequests: json['recent_requests'] != null
          ? (json['recent_requests'] as List)
              .map((r) => BloodRequest.fromJson(r))
              .toList()
          : [],
    );
  }
}
