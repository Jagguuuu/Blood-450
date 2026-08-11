import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/blood_request.dart';

/// Bottom sheet showing blood request detail and accepted donors (for admin).
class AdminRequestDetailSheet extends StatelessWidget {
  final BloodRequest request;
  final List<AcceptedDonor>? acceptedDonors;

  const AdminRequestDetailSheet({
    super.key,
    required this.request,
    this.acceptedDonors,
  });

  static Future<void> show(
    BuildContext context, {
    required BloodRequest request,
    List<AcceptedDonor>? acceptedDonors,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminRequestDetailSheet(
        request: request,
        acceptedDonors: acceptedDonors ?? request.acceptedDonors,
      ),
    );
  }

  String _statusLabel() {
    if (request.status.isNotEmpty) {
      return request.statusDisplay.toUpperCase();
    }
    return request.isActive ? 'ACTIVE' : 'CLOSED';
  }

  Color _statusColor() {
    if (request.isFulfilled || request.status == 'fulfilled') {
      return AppColors.success;
    }
    if (!request.isActive) return Colors.grey.shade700;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final accepted = acceptedDonors ?? request.acceptedDonors ?? [];
    final primaryAccepted = accepted.isNotEmpty ? accepted.first : null;
    final fulfilled = request.isFulfilled || request.status == 'fulfilled';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (fulfilled) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        primaryAccepted != null
                            ? 'Donor accepted — request fulfilled'
                            : 'Request fulfilled',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getBloodGroupColor(
                      request.bloodGroup,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.bloodGroup,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.getBloodGroupColor(request.bloodGroup),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getUrgencyColor(
                      request.urgency,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.urgencyDisplay.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getUrgencyColor(request.urgency),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${request.unitsNeeded} unit(s) needed',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            if (request.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.note,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            if (request.locationName != null &&
                request.locationName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.locationName!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${request.notifiedCount} notified · ${request.acceptedCount} accepted'
              '${request.closedAt != null ? ' · closed ${_formatTime(request.closedAt!)}' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (primaryAccepted != null) ...[
              const SizedBox(height: 16),
              Text(
                'Accepted Donor',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                color: AppColors.success.withValues(alpha: 0.08),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.success.withValues(alpha: 0.2),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                    ),
                  ),
                  title: Text(
                    primaryAccepted.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    [
                      if (primaryAccepted.username.isNotEmpty)
                        '@${primaryAccepted.username}',
                      if (primaryAccepted.bloodGroup != null)
                        primaryAccepted.bloodGroup!,
                      if (primaryAccepted.phone != null &&
                          primaryAccepted.phone!.isNotEmpty)
                        primaryAccepted.phone!,
                      'Accepted ${_formatTime(primaryAccepted.respondedAt)}',
                    ].join(' · '),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Divider(),
            Text(
              'Notified Donors',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (request.notifiedDonors == null ||
                request.notifiedDonors!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No donors notified.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else
              ...(request.notifiedDonors!.map((d) {
                final parts = <String>[];
                if (d.bloodGroup != null) parts.add(d.bloodGroup!);
                if (d.distanceKm != null) {
                  parts.add('${d.distanceKm!.toStringAsFixed(1)} km');
                }
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.info.withValues(alpha: 0.2),
                      child: Icon(
                        Icons.person,
                        color: AppColors.info,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      d.username,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: parts.isEmpty
                        ? null
                        : Text(
                            parts.join(' · '),
                            style: const TextStyle(fontSize: 12),
                          ),
                  ),
                );
              })),
            if (accepted.length > 1) ...[
              const SizedBox(height: 16),
              Text(
                'All Accepted Donors',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...accepted.skip(1).map((d) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                    ),
                    title: Text(d.displayName),
                    subtitle: Text(
                      [
                        if (d.phone != null && d.phone!.isNotEmpty) d.phone!,
                        if (d.bloodGroup != null) d.bloodGroup!,
                        _formatTime(d.respondedAt),
                      ].join(' · '),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}
