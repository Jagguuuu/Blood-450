import 'user.dart';
import '../../core/utils/date_time_utils.dart';

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
  /// Readable place (display only; matching uses lastLat/lastLng)
  final String? city;
  final String? state;
  final String? locationDisplay;

  /// Canonical clinical last donation date (YYYY-MM-DD from Django).
  final DateTime? lastDonationDate;

  /// Backend eligibility: eligible | cooling_off | unknown
  final String eligibilityStatus;
  final int? daysSinceLastDonation;
  final int? daysUntilEligible;

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
    this.city,
    this.state,
    this.locationDisplay,
    this.lastDonationDate,
    this.eligibilityStatus = 'unknown',
    this.daysSinceLastDonation,
    this.daysUntilEligible,
  });

  bool get hasCoordinates => lastLat != null && lastLng != null;

  bool get isEligible => eligibilityStatus == 'eligible';
  bool get isCoolingOff => eligibilityStatus == 'cooling_off';
  bool get eligibilityUnknown =>
      eligibilityStatus == 'unknown' || eligibilityStatus.isEmpty;

  /// Prefer API location_display; else City, State; else Location available.
  String get readableLocation {
    final fromApi = (locationDisplay ?? '').trim();
    if (fromApi.isNotEmpty) return fromApi;
    final c = (city ?? '').trim();
    final s = (state ?? '').trim();
    if (c.isNotEmpty && s.isNotEmpty) return '$c, $s';
    if (c.isNotEmpty) return c;
    if (s.isNotEmpty) return s;
    if (hasCoordinates) return 'Location available';
    return '';
  }

  factory DonorProfile.fromJson(Map<String, dynamic> json) {
    return DonorProfile(
      id: json['id'] ?? 0,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      username: json['username'] ?? '',
      phone: json['phone'] ?? '',
      bloodGroup: json['blood_group'] ?? '',
      isAvailable: json['is_available'] ?? true,
      createdAt: parseApiDateTime(json['created_at']),
      lastLat: _toDouble(json['last_lat']),
      lastLng: _toDouble(json['last_lng']),
      locationUpdatedAt: tryParseApiDateTime(json['location_updated_at']),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      locationDisplay: json['location_display']?.toString(),
      lastDonationDate: _parseDateOnly(json['last_donation_date']),
      eligibilityStatus: (json['eligibility_status'] ?? 'unknown').toString(),
      daysSinceLastDonation: _toInt(json['days_since_last_donation']),
      daysUntilEligible: _toInt(json['days_until_eligible']),
    );
  }

  static DateTime? _parseDateOnly(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    // Prefer date-only (YYYY-MM-DD) to avoid timezone shifts.
    if (s.length >= 10 && s[4] == '-' && s[7] == '-') {
      final y = int.tryParse(s.substring(0, 4));
      final m = int.tryParse(s.substring(5, 7));
      final d = int.tryParse(s.substring(8, 10));
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.tryParse(s);
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
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
      'eligibility_status': eligibilityStatus,
    };
    if (lastLat != null) m['last_lat'] = lastLat;
    if (lastLng != null) m['last_lng'] = lastLng;
    if (locationUpdatedAt != null) {
      m['location_updated_at'] = locationUpdatedAt!.toIso8601String();
    }
    if (city != null) m['city'] = city;
    if (state != null) m['state'] = state;
    if (locationDisplay != null) m['location_display'] = locationDisplay;
    if (lastDonationDate != null) {
      m['last_donation_date'] =
          '${lastDonationDate!.year.toString().padLeft(4, '0')}-'
          '${lastDonationDate!.month.toString().padLeft(2, '0')}-'
          '${lastDonationDate!.day.toString().padLeft(2, '0')}';
    }
    if (daysSinceLastDonation != null) {
      m['days_since_last_donation'] = daysSinceLastDonation;
    }
    if (daysUntilEligible != null) {
      m['days_until_eligible'] = daysUntilEligible;
    }
    return m;
  }
}
