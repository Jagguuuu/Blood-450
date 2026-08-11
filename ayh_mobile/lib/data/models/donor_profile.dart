import 'user.dart';

class DonorProfile {
  final int id;
  final User? user;
  final String username;
  final String phone;
  final String bloodGroup;
  final bool isAvailable;
  final DateTime createdAt;
  /// Last-known location for distance-based matching
  final double? lastLat;
  final double? lastLng;
  final DateTime? locationUpdatedAt;

  DonorProfile({
    required this.id,
    this.user,
    required this.username,
    required this.phone,
    required this.bloodGroup,
    required this.isAvailable,
    required this.createdAt,
    this.lastLat,
    this.lastLng,
    this.locationUpdatedAt,
  });

  factory DonorProfile.fromJson(Map<String, dynamic> json) {
    return DonorProfile(
      id: json['id'] ?? 0,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      username: json['username'] ?? '',
      phone: json['phone'] ?? '',
      bloodGroup: json['blood_group'] ?? '',
      isAvailable: json['is_available'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      lastLat: _toDouble(json['last_lat']),
      lastLng: _toDouble(json['last_lng']),
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.tryParse(json['location_updated_at'].toString())
          : null,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'id': id,
      'username': username,
      'phone': phone,
      'blood_group': bloodGroup,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
    };
    if (lastLat != null) m['last_lat'] = lastLat;
    if (lastLng != null) m['last_lng'] = lastLng;
    if (locationUpdatedAt != null) m['location_updated_at'] = locationUpdatedAt!.toIso8601String();
    return m;
  }
}
