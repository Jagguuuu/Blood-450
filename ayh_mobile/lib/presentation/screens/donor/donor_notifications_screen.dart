import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/donor_response_sheet.dart';
import '../../../data/models/notification.dart';

/// Full-screen list of all blood request notifications. Opened when user taps the bell.
class DonorNotificationsScreen extends StatefulWidget {
  const DonorNotificationsScreen({super.key});

  @override
  State<DonorNotificationsScreen> createState() => _DonorNotificationsScreenState();
}

class _DonorNotificationsScreenState extends State<DonorNotificationsScreen> {
  Future<void> _handleResponse(int requestId, String response) async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    final result = await notifProvider.respondToRequest(
      bloodRequestId: requestId,
      response: response,
    );
    if (!mounted) return;
    if (result['success']) {
      await notifProvider.loadNotifications();
      if (!mounted) return;
      if (response == 'accepted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are accepted for this blood request.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response recorded'), backgroundColor: AppColors.info),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to respond'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _openResponseSheet(NotificationModel notification) {
    DonorResponseSheet.show(
      context,
      notification: notification,
      onRespond: _handleResponse,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}/${time.year}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
      Provider.of<NotificationProvider>(context, listen: false).clearAcceptanceCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Requests'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
              if (mounted) {
                Provider.of<NotificationProvider>(context, listen: false).clearAcceptanceCount();
              }
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notifProvider, _) {
          if (notifProvider.isLoading && notifProvider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notifProvider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 72, color: Colors.grey[400]),
                  const SizedBox(height: 20),
                  Text(
                    'No blood requests yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'You\'ll see requests here when someone needs your blood type',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await notifProvider.loadNotifications();
              notifProvider.clearAcceptanceCount();
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifProvider.notifications.length,
              itemBuilder: (context, index) {
                final notification = notifProvider.notifications[index];
                final request = notification.bloodRequest;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: notification.isRead ? 1 : 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: InkWell(
                    onTap: () => _openResponseSheet(notification),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.getBloodGroupColor(request.bloodGroup).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.getUrgencyColor(request.urgency).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
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
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${request.unitsNeeded} unit(s) needed',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (request.locationName != null && request.locationName!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.place, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    request.locationName!,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (notification.distanceKm != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              ],
                            ),
                          ] else if (notification.distanceKm != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              alignment: Alignment.centerLeft,
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
                          if (request.note.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              request.note,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Requested ${_formatTime(request.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (notification.hasResponded) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: notification.responseStatus == 'accepted'
                                    ? AppColors.success.withOpacity(0.12)
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    notification.responseStatus == 'accepted'
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color: notification.responseStatus == 'accepted'
                                        ? AppColors.success
                                        : AppColors.warning,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    notification.responseStatus == 'accepted'
                                        ? 'You accepted this request'
                                        : 'You declined this request',
                                    style: TextStyle(
                                      color: notification.responseStatus == 'accepted'
                                          ? AppColors.success
                                          : Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.touch_app_rounded, size: 18, color: AppColors.accent),
                                const SizedBox(width: 6),
                                Text(
                                  'Tap to respond (Accept or Can\'t Donate)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
