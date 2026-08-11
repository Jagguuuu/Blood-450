import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/notification.dart' as app;

/// Bottom sheet (offcanvas) for donor to respond to a blood request.
class DonorResponseSheet extends StatelessWidget {
  final app.NotificationModel notification;
  final Future<void> Function(int requestId, String response) onRespond;

  const DonorResponseSheet({
    super.key,
    required this.notification,
    required this.onRespond,
  });

  static Future<void> show(
    BuildContext context, {
    required app.NotificationModel notification,
    required Future<void> Function(int requestId, String response) onRespond,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          DonorResponseSheet(notification: notification, onRespond: onRespond),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = notification.bloodRequest;
    return Container(
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
          Text(
            'Blood Request',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
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
                  ).withOpacity(0.2),
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
                  ).withOpacity(0.2),
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
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${request.unitsNeeded} unit(s) needed',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (request.locationName != null &&
              request.locationName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.locationName!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (notification.distanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${notification.distanceKm!.toStringAsFixed(1)} km away',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ] else if (notification.distanceKm != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${notification.distanceKm!.toStringAsFixed(1)} km away',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          if (request.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.note,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Requested ${_formatTime(request.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          if (notification.hasResponded)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: notification.responseStatus == 'accepted'
                    ? AppColors.success.withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    notification.responseStatus == 'accepted'
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: notification.responseStatus == 'accepted'
                        ? AppColors.success
                        : Colors.grey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    notification.responseStatus == 'accepted'
                        ? 'You accepted this request'
                        : 'You declined this request',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: notification.responseStatus == 'accepted'
                          ? AppColors.success
                          : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _submit(context, 'accepted'),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept & Donate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submit(context, 'rejected'),
                    icon: const Icon(Icons.close),
                    label: const Text('Can\'t Donate'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context, String response) async {
    Navigator.of(context).pop();
    await onRespond(notification.bloodRequest.id, response);
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
