import 'blood_request.dart';

class NotificationModel {
  final int id;
  final BloodRequest bloodRequest;
  final bool isRead;
  final DateTime createdAt;
  final bool hasResponded;
  final String? responseStatus;
  final DateTime? respondedAt;
  /// Distance in km from request location to donor's location (when both have location)
  final double? distanceKm;

  NotificationModel({
    required this.id,
    required this.bloodRequest,
    required this.isRead,
    required this.createdAt,
    required this.hasResponded,
    this.responseStatus,
    this.respondedAt,
    this.distanceKm,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      bloodRequest: BloodRequest.fromJson(json['blood_request'] ?? {}),
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      hasResponded: json['has_responded'] ?? false,
      responseStatus: json['response_status'],
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'])
          : null,
      distanceKm: _toDouble(json['distance_km']),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'is_read': isRead,
      'has_responded': hasResponded,
      'response_status': responseStatus,
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}
