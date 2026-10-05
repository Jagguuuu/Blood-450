/// Parse API datetimes correctly for Django `USE_TZ=True` (stored as UTC).
///
/// DRF used to emit naive `"YYYY-MM-DD HH:MM:SS"` UTC. Dart treats that as
/// *local*, so India (UTC+5:30) showed brand-new requests as "~5h ago".
DateTime parseApiDateTime(dynamic value, {DateTime? fallback}) {
  final fb = fallback ?? DateTime.now();
  if (value == null) return fb;

  var s = value.toString().trim();
  if (s.isEmpty) return fb;

  // Normalize space separator used by older DRF DATETIME_FORMAT.
  if (s.contains(' ') && !s.contains('T')) {
    s = s.replaceFirst(' ', 'T');
  }

  final parsed = DateTime.tryParse(s);
  if (parsed == null) return fb;

  final hasZone = s.endsWith('Z') ||
      s.endsWith('z') ||
      RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);

  if (!hasZone && !parsed.isUtc) {
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  return parsed.toLocal();
}

DateTime? tryParseApiDateTime(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  return parseApiDateTime(value);
}

const _monthAbbr = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Absolute date like `Oct 1, 2026`.
String formatApiDate(DateTime time) {
  final local = time.toLocal();
  return '${_monthAbbr[local.month - 1]} ${local.day}, ${local.year}';
}

/// Relative time with date, e.g. `7m ago · Oct 1, 2026`.
String formatRequestedAt(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  String relative;
  if (diff.inMinutes < 1) {
    relative = 'just now';
  } else if (diff.inMinutes < 60) {
    relative = '${diff.inMinutes}m ago';
  } else if (diff.inHours < 24) {
    relative = '${diff.inHours}h ago';
  } else if (diff.inDays < 7) {
    relative = '${diff.inDays}d ago';
  } else {
    return formatApiDate(local);
  }
  return '$relative · ${formatApiDate(local)}';
}
