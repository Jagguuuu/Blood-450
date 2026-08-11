import 'user.dart';

class BloodRequest {
  final int id;
  final String bloodGroup;
  final int unitsNeeded;
  final String urgency;
  final String urgencyDisplay;
  final String note;
  final int? createdBy;
  final String? createdByUsername;
  final bool isActive;
  final String status;
  final String statusDisplay;
  final DateTime? closedAt;
  final String? closureReason;
  final String? closureType;
  final DateTime createdAt;
  final int notifiedCount;
  final int acceptedCount;
  final User? createdByUser;
  final List<NotifiedDonor>? notifiedDonors;
  final List<AcceptedDonor>? acceptedDonors;
  /// Request location for distance-based matching
  final double? reqLat;
  final double? reqLng;
  final String? locationName;
  final double radiusKm;

  BloodRequest({
    required this.id,
    required this.bloodGroup,
    required this.unitsNeeded,
    required this.urgency,
    required this.urgencyDisplay,
    required this.note,
    this.createdBy,
    this.createdByUsername,
    required this.isActive,
    this.status = 'open',
    this.statusDisplay = 'Open',
    this.closedAt,
    this.closureReason,
    this.closureType,
    required this.createdAt,
    required this.notifiedCount,
    required this.acceptedCount,
    this.createdByUser,
    this.notifiedDonors,
    this.acceptedDonors,
    this.reqLat,
    this.reqLng,
    this.locationName,
    this.radiusKm = 5.0,
  });

  bool get isFulfilled => status == 'fulfilled' || acceptedCount > 0;

  static int? _parseCreatedBy(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is Map && v['id'] != null) {
      return v['id'] is int ? v['id'] as int : int.tryParse(v['id'].toString());
    }
    return null;
  }

  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    return BloodRequest(
      id: json['id'] ?? 0,
      bloodGroup: json['blood_group'] ?? '',
      unitsNeeded: json['units_needed'] is int
          ? json['units_needed'] as int
          : int.tryParse(json['units_needed']?.toString() ?? '1') ?? 1,
      urgency: json['urgency'] ?? '',
      urgencyDisplay: json['urgency_display'] ?? json['urgency'] ?? '',
      note: json['note'] ?? '',
      createdBy: _parseCreatedBy(json['created_by']),
      createdByUsername: json['created_by_username']?.toString() ??
          (json['created_by'] is Map
              ? (json['created_by'] as Map)['username']?.toString()
              : null),
      isActive: json['is_active'] ?? true,
      status: json['status']?.toString() ?? 'open',
      statusDisplay:
          json['status_display']?.toString() ?? json['status']?.toString() ?? 'Open',
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'].toString())
          : null,
      closureReason: json['closure_reason']?.toString(),
      closureType: json['closure_type']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      notifiedCount: json['notified_count'] ?? 0,
      acceptedCount: json['accepted_count'] ?? 0,
      createdByUser: json['created_by'] != null && json['created_by'] is Map
          ? User.fromJson(json['created_by'])
          : null,
      notifiedDonors: json['notified_donors'] != null
          ? (json['notified_donors'] as List)
              .map((d) => NotifiedDonor.fromJson(d))
              .toList()
          : null,
      acceptedDonors: json['accepted_donors'] != null
          ? (json['accepted_donors'] as List)
              .map((d) => AcceptedDonor.fromJson(d))
              .toList()
          : null,
      reqLat: _toDouble(json['req_lat']),
      reqLng: _toDouble(json['req_lng']),
      locationName: json['location_name']?.toString(),
      radiusKm: _toDouble(json['radius_km']) ?? 5.0,
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
      'blood_group': bloodGroup,
      'units_needed': unitsNeeded,
      'urgency': urgency,
      'note': note,
      'is_active': isActive,
      'status': status,
    };
    if (reqLat != null) m['req_lat'] = reqLat;
    if (reqLng != null) m['req_lng'] = reqLng;
    if (locationName != null && locationName!.isNotEmpty) {
      m['location_name'] = locationName;
    }
    m['radius_km'] = radiusKm;
    return m;
  }
}

class NotifiedDonor {
  final int id;
  final String username;
  final String? bloodGroup;
  final DateTime notifiedAt;
  /// Distance in km from request location (when request has location)
  final double? distanceKm;

  NotifiedDonor({
    required this.id,
    required this.username,
    this.bloodGroup,
    required this.notifiedAt,
    this.distanceKm,
  });

  factory NotifiedDonor.fromJson(Map<String, dynamic> json) {
    return NotifiedDonor(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      bloodGroup: json['blood_group'],
      notifiedAt: json['notified_at'] != null
          ? DateTime.parse(json['notified_at'])
          : DateTime.now(),
      distanceKm: BloodRequest._toDouble(json['distance_km']),
    );
  }
}

class AcceptedDonor {
  final int id;
  final String username;
  final String? fullName;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? bloodGroup;
  final DateTime respondedAt;
  final double? distanceKm;

  AcceptedDonor({
    required this.id,
    required this.username,
    this.fullName,
    this.firstName,
    this.lastName,
    this.phone,
    this.bloodGroup,
    required this.respondedAt,
    this.distanceKm,
  });

  String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    final composed =
        '${(firstName ?? '').trim()} ${(lastName ?? '').trim()}'.trim();
    if (composed.isNotEmpty) return composed;
    return username;
  }

  factory AcceptedDonor.fromJson(Map<String, dynamic> json) {
    return AcceptedDonor(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      fullName: json['full_name']?.toString(),
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      phone: json['phone'],
      bloodGroup: json['blood_group'],
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'])
          : DateTime.now(),
      distanceKm: BloodRequest._toDouble(json['distance_km']),
    );
  }
}

/// Matched donor with distance returned when admin creates a request with location
class MatchedDonor {
  final int id;
  final String username;
  final String? bloodGroup;
  final double? distanceKm;

  MatchedDonor({
    required this.id,
    required this.username,
    this.bloodGroup,
    this.distanceKm,
  });

  factory MatchedDonor.fromJson(Map<String, dynamic> json) {
    return MatchedDonor(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      bloodGroup: json['blood_group'],
      distanceKm: BloodRequest._toDouble(json['distance_km']),
    );
  }
}
