class LeaderboardEntry {
  final int rank;
  final String name;
  final String bloodGroup;
  final int donations;
  final String badge;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.bloodGroup,
    required this.donations,
    required this.badge,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int? ?? 0,
      name: json['name'] as String? ?? 'Donor',
      bloodGroup: json['blood_group'] as String? ?? '?',
      donations: json['donations'] as int? ?? 0,
      badge: json['badge'] as String? ?? '',
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (name.isEmpty) return '?';
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class LeaderboardCurrentUser extends LeaderboardEntry {
  final int livesImpacted;

  const LeaderboardCurrentUser({
    required super.rank,
    required super.name,
    required super.bloodGroup,
    required super.donations,
    required super.badge,
    required this.livesImpacted,
  });

  factory LeaderboardCurrentUser.fromJson(Map<String, dynamic> json) {
    return LeaderboardCurrentUser(
      rank: json['rank'] as int? ?? 0,
      name: json['name'] as String? ?? 'Donor',
      bloodGroup: json['blood_group'] as String? ?? '?',
      donations: json['donations'] as int? ?? 0,
      badge: json['badge'] as String? ?? '',
      livesImpacted: json['lives_impacted'] as int? ?? 0,
    );
  }
}

class LeaderboardData {
  final List<LeaderboardEntry> topDonors;
  final LeaderboardCurrentUser? currentUser;

  const LeaderboardData({
    required this.topDonors,
    this.currentUser,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) {
    final top = (json['top_donors'] as List<dynamic>? ?? [])
        .map((item) => LeaderboardEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    final currentJson = json['current_user'];
    return LeaderboardData(
      topDonors: top,
      currentUser: currentJson == null
          ? null
          : LeaderboardCurrentUser.fromJson(
              currentJson as Map<String, dynamic>,
            ),
    );
  }
}
