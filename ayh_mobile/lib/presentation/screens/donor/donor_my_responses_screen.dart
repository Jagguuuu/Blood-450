import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/donor_response_sheet.dart';

/// Screen showing donor's responses (requests they accepted or declined).
class DonorMyResponsesScreen extends StatelessWidget {
  const DonorMyResponsesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Responses'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, notifProvider, _) {
          final responded = notifProvider.notifications
              .where((n) => n.hasResponded)
              .toList();
          if (notifProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (responded.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No responses yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your accepted or declined requests will appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: responded.length,
            itemBuilder: (context, index) {
              final notification = responded[index];
              final request = notification.bloodRequest;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => DonorResponseSheet.show(
                    context,
                    notification: notification,
                    onRespond: (int requestId, String response) async {
                      await notifProvider.loadNotifications();
                    },
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.getBloodGroupColor(request.bloodGroup).withOpacity(0.2),
                    child: Text(
                      request.bloodGroup,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.getBloodGroupColor(request.bloodGroup),
                      ),
                    ),
                  ),
                  title: Text('${request.unitsNeeded} unit(s) - ${request.urgencyDisplay}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.responseStatus == 'accepted'
                            ? 'You accepted'
                            : 'You declined',
                        style: TextStyle(
                          color: notification.responseStatus == 'accepted'
                              ? AppColors.success
                              : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (notification.respondedAt != null)
                        Text(
                          'Responded: ${_formatDate(notification.respondedAt!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  trailing: Icon(
                    notification.responseStatus == 'accepted'
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: notification.responseStatus == 'accepted'
                        ? AppColors.success
                        : Colors.grey,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
