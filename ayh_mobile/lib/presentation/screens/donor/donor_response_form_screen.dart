import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/notification.dart';

/// Donor Response form: select blood request, donor prefilled, Response (Accepted/Rejected), date.
class DonorResponseFormScreen extends StatefulWidget {
  const DonorResponseFormScreen({super.key});

  @override
  State<DonorResponseFormScreen> createState() => _DonorResponseFormScreenState();
}

class _DonorResponseFormScreenState extends State<DonorResponseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedNotificationId; // use id so dropdown/picker works reliably
  String? _response; // 'accepted' or 'rejected'
  DateTime _respondedAt = DateTime.now();
  bool _showSuccessCard = false;
  String? _successResponse; // 'accepted' or 'rejected'
  String _successRequestLabel = '';

  NotificationModel? _getSelectedNotification(List<NotificationModel> pending) {
    if (_selectedNotificationId == null) return null;
    try {
      return pending.firstWhere((n) => n.id == _selectedNotificationId);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
    });
  }

  Future<void> _refreshNotifications(BuildContext context) async {
    await Provider.of<NotificationProvider>(context, listen: false).loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Response'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshNotifications(context),
            tooltip: 'Refresh blood requests',
          ),
        ],
      ),
      body: Consumer2<NotificationProvider, AuthProvider>(
        builder: (context, notifProvider, authProvider, _) {
          final pendingRequests = notifProvider.notifications
              .where((n) => !n.hasResponded)
              .toList();

          if (_showSuccessCard) {
            return _buildSuccessCard(context);
          }

          final selectedNotif = _getSelectedNotification(pendingRequests);
          final selectedLabel = selectedNotif != null
              ? '${selectedNotif.bloodRequest.bloodGroup} - ${selectedNotif.bloodRequest.unitsNeeded} unit(s) - ${selectedNotif.bloodRequest.urgencyDisplay}'
              : null;

          return RefreshIndicator(
            onRefresh: () => _refreshNotifications(context),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (notifProvider.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const Text(
                    'Submit your response to a blood request',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Blood Request picker (tap to open list)
                  InkWell(
                    onTap: () => _openBloodRequestPicker(
                      context,
                      pendingRequests,
                      notifProvider.isLoading,
                      notifProvider,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Blood Request *',
                        prefixIcon: const Icon(Icons.bloodtype),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selectedLabel ?? 'Tap to select a blood request',
                        style: TextStyle(
                          color: selectedLabel != null
                              ? Colors.black87
                              : Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  if (pendingRequests.isEmpty && !notifProvider.isLoading) ...[
                    const SizedBox(height: 8),
                    Text(
                      'No pending requests. You\'ll see requests here when someone needs your blood type.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Donor name (prefilled)
                  TextFormField(
                    initialValue: authProvider.user?.username ?? '',
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Donor',
                      prefixIcon: const Icon(Icons.person),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Response: Accepted / Rejected
                  const Text(
                    'Response *',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Accepted'),
                          value: 'accepted',
                          groupValue: _response,
                          onChanged: (v) => setState(() => _response = v),
                          activeColor: AppColors.success,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Rejected'),
                          value: 'rejected',
                          groupValue: _response,
                          onChanged: (v) => setState(() => _response = v),
                          activeColor: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date responded (display)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.info),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date responded',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _formatDate(_respondedAt),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Recorded when you submit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: notifProvider.isLoading ? null : () => _submit(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: notifProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Submit Response', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),

                  if (pendingRequests.isEmpty) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'No pending requests to respond to',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
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
  }

  void _openBloodRequestPicker(
    BuildContext context,
    List<NotificationModel> pendingRequests,
    bool isLoading,
    NotificationProvider notifProvider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select blood request',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        await notifProvider.loadNotifications();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (pendingRequests.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No pending blood requests',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You\'ll see requests here when someone needs your blood type. Tap Refresh to try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () async {
                          await notifProvider.loadNotifications();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pendingRequests.length,
                    itemBuilder: (ctx, index) {
                      final n = pendingRequests[index];
                      final r = n.bloodRequest;
                      final label =
                          '${r.bloodGroup} - ${r.unitsNeeded} unit(s) - ${r.urgencyDisplay}';
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.getBloodGroupColor(r.bloodGroup)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              r.bloodGroup,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.getBloodGroupColor(r.bloodGroup),
                              ),
                            ),
                          ),
                        ),
                        title: Text(label),
                        subtitle: r.note.isNotEmpty
                            ? Text(
                                r.note,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedNotificationId = n.id;
                            _respondedAt = DateTime.now();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSuccessCard(BuildContext context) {
    final isAccepted = _successResponse == 'accepted';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isAccepted ? AppColors.success : AppColors.info).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAccepted ? Icons.check_circle : Icons.info_outline,
                      size: 56,
                      color: isAccepted ? AppColors.success : AppColors.info,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_active, color: AppColors.primary, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        isAccepted ? 'You are accepted' : 'Response recorded',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isAccepted ? AppColors.success : AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _successRequestLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAccepted
                        ? 'This will reflect on the admin dashboard for this request.'
                        : 'Your response has been recorded.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home),
                      label: const Text('Back to home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    final pending = notifProvider.notifications.where((n) => !n.hasResponded).toList();
    final selectedNotif = _getSelectedNotification(pending);

    if (selectedNotif == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a blood request'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_response == null || _response!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Accepted or Rejected'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final result = await notifProvider.respondToRequest(
      bloodRequestId: selectedNotif.bloodRequest.id,
      response: _response!,
    );

    if (!mounted) return;

    if (result['success']) {
      await notifProvider.loadNotifications();
      if (!mounted) return;
      final r = selectedNotif.bloodRequest;
      setState(() {
        _showSuccessCard = true;
        _successResponse = _response;
        _successRequestLabel =
            '${r.bloodGroup} - ${r.unitsNeeded} unit(s) - ${r.urgencyDisplay}';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to submit'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
