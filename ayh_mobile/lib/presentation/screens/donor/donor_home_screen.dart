import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/notification_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/donor_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';
import 'donor_my_responses_screen.dart';
import 'donor_profile_screen.dart';
import 'donor_notifications_screen.dart';
import '../support/support_chat_screen.dart';
import '../../providers/whatsapp_chat_provider.dart';
import '../../../data/models/notification.dart';

/// Donation record derived from accepted notification (respondedAt = donation date).
class _DonationRecord {
  final DateTime date;
  final String urgency; // critical, high, medium → used as "type" for pie

  _DonationRecord({required this.date, required this.urgency});
}

/// Donor Home: dashboard (metrics, charts, eligibility) + notifications list.
class DonorHomeScreen extends StatefulWidget {
  const DonorHomeScreen({super.key});

  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen>
    with SingleTickerProviderStateMixin {
  static const int eligibilityDays = 90;
  late final AnimationController _emergencyPulseController;
  late final Animation<double> _emergencyPulse;

  @override
  void initState() {
    super.initState();
    _emergencyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _emergencyPulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _emergencyPulseController,
        curve: Curves.easeInOut,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).loadNotifications();
      Provider.of<WhatsAppChatProvider>(context, listen: false).loadUnread();
    });
  }

  @override
  void dispose() {
    _emergencyPulseController.dispose();
    super.dispose();
  }

  List<_DonationRecord> _getDonations(List<NotificationModel> notifications) {
    return notifications
        .where(
          (n) =>
              n.hasResponded &&
              n.responseStatus == 'accepted' &&
              n.respondedAt != null,
        )
        .map(
          (n) => _DonationRecord(
            date: n.respondedAt!,
            urgency: n.bloodRequest.urgency,
          ),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  int _thisMonthCount(List<_DonationRecord> donations) {
    final now = DateTime.now();
    return donations
        .where((d) => d.date.month == now.month && d.date.year == now.year)
        .length;
  }

  DateTime? _lastDonationDate(List<_DonationRecord> donations) {
    if (donations.isEmpty) return null;
    return donations.last.date;
  }

  int _daysUntilEligible(DateTime? lastDate) {
    if (lastDate == null) return 0;
    final daysSince = DateTime.now().difference(lastDate).inDays;
    if (daysSince >= eligibilityDays) return 0;
    return eligibilityDays - daysSince;
  }

  double _eligibilityProgress(DateTime? lastDate) {
    if (lastDate == null) return 0;
    final daysSince = DateTime.now().difference(lastDate).inDays;
    if (daysSince >= eligibilityDays) return 1.0;
    return (daysSince / eligibilityDays).clamp(0.0, 1.0);
  }

  /// Donations per month, last 12 months.
  List<({String label, int count})> _donationsByMonthLast12(
    List<_DonationRecord> donations,
  ) {
    final now = DateTime.now();
    final months = <({String label, int count})>[];
    for (var i = 11; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final count = donations
          .where((x) => x.date.month == d.month && x.date.year == d.year)
          .length;
      months.add((
        label: '${_monthShort(d.month)}\n\'${d.year % 100}',
        count: count,
      ));
    }
    return months;
  }

  String _monthShort(int month) {
    const m = [
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
    return m[month - 1];
  }

  int _currentStreak(List<_DonationRecord> donations) {
    if (donations.isEmpty) return 0;
    final monthsWithDonation = <int>{};
    for (final d in donations) {
      monthsWithDonation.add(d.date.year * 12 + d.date.month);
    }
    final sorted = monthsWithDonation.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    final now = DateTime.now();
    int current = now.year * 12 + now.month;
    for (final m in sorted) {
      if (m == current) {
        streak++;
        current--;
      } else if (m < current)
        break;
    }
    return streak;
  }

  List<bool> _badgesUnlocked(int lifetimeCount) {
    return [
      lifetimeCount >= 1,
      lifetimeCount >= 5,
      lifetimeCount >= 10,
      lifetimeCount >= 25,
    ];
  }

  int _urgencyRank(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical':
        return 3;
      case 'high':
        return 2;
      case 'medium':
        return 1;
      default:
        return 0;
    }
  }

  NotificationModel? _nearestOpenRequest(
    List<NotificationModel> notifications,
  ) {
    final candidates = notifications
        .where((n) => n.bloodRequest.isActive && !n.hasResponded)
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final urgencyCmp = _urgencyRank(
        b.bloodRequest.urgency,
      ).compareTo(_urgencyRank(a.bloodRequest.urgency));
      if (urgencyCmp != 0) return urgencyCmp;
      final aDist = a.distanceKm ?? double.infinity;
      final bDist = b.distanceKm ?? double.infinity;
      final distCmp = aDist.compareTo(bDist);
      if (distCmp != 0) return distCmp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return candidates.first;
  }

  bool _hasCriticalOpenRequest(List<NotificationModel> notifications) {
    return notifications.any(
      (n) =>
          n.bloodRequest.isActive &&
          !n.hasResponded &&
          n.bloodRequest.urgency.toLowerCase() == 'critical',
    );
  }

  Future<void> _handleRefresh() async {
    final notifProvider = Provider.of<NotificationProvider>(
      context,
      listen: false,
    );
    await notifProvider.loadNotifications();
    await notifProvider.clearAcceptanceCount();
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _toggleAvailabilityQuick() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final donorProvider = Provider.of<DonorProvider>(context, listen: false);
    final profile = authProvider.donorProfile;

    if (profile == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create donor profile first.')),
      );
      return;
    }

    final nextValue = !profile.isAvailable;
    final updated = await donorProvider.updateProfile(isAvailable: nextValue);
    if (!mounted) return;

    if (updated && donorProvider.profile != null) {
      authProvider.updateDonorProfile(donorProvider.profile!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue
                ? 'You are now marked as Available'
                : 'You are now marked as Busy',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(donorProvider.error ?? 'Unable to update status'),
        ),
      );
    }
  }

  void _showQuickActionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    'Quick Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Fast shortcuts for donor workflow'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_active_rounded,
                    color: _crimsonRed,
                  ),
                  title: const Text('Open Notifications'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DonorNotificationsScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: _crimsonRed,
                  ),
                  title: const Text('My Responses'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DonorMyResponsesScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: _crimsonRed),
                  title: const Text('My Profile'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DonorProfileScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.toggle_on_rounded,
                    color: _crimsonRed,
                  ),
                  title: const Text('Toggle Availability'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _toggleAvailabilityQuick();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5), // Off-white/cream background
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text(
          'Blood450',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFDC143C), // Crimson red
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              final count = notifProvider.badgeCount;
              if (count > 0) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_rounded),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DonorNotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF8E1), // Light cream
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Color(0xFFDC143C),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return IconButton(
                icon: const Icon(Icons.notifications_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DonorNotificationsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DonorProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer2<NotificationProvider, AuthProvider>(
        builder: (context, notifProvider, authProvider, _) {
          if (notifProvider.isLoading && notifProvider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final donations = _getDonations(notifProvider.notifications);
          final thisMonth = _thisMonthCount(donations);
          final lastDate = _lastDonationDate(donations);
          final lifetime = donations.length;
          final daysUntil = _daysUntilEligible(lastDate);
          final progress = _eligibilityProgress(lastDate);
          final byMonth = _donationsByMonthLast12(donations);
          final streak = _currentStreak(donations);
          final badges = _badgesUnlocked(lifetime);
          final nearestRequest = _nearestOpenRequest(
            notifProvider.notifications,
          );
          final hasCriticalOpen = _hasCriticalOpenRequest(
            notifProvider.notifications,
          );

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFFDC143C),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Section with Gradient
                  _buildHeroSection(context, authProvider),
                  const SizedBox(height: 16),

                  // Main Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasCriticalOpen) ...[
                          _buildEmergencyBanner(),
                          const SizedBox(height: 12),
                        ],
                        if (nearestRequest != null) ...[
                          _buildNearestRequestCard(nearestRequest),
                          const SizedBox(height: 20),
                        ],
                        _buildMetricCards(
                          thisMonth,
                          lastDate,
                          lifetime,
                          daysUntil,
                        ),
                        const SizedBox(height: 20),
                        _buildTodayStatusCard(
                          authProvider: authProvider,
                          notifProvider: notifProvider,
                          daysUntil: daysUntil,
                          thisMonth: thisMonth,
                        ),
                        const SizedBox(height: 20),
                        _buildEligibilityProgress(
                          progress,
                          daysUntil,
                          lastDate,
                        ),
                        const SizedBox(height: 24),
                        _buildCtaSection(context),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Donation Stats',
                          Icons.bar_chart_rounded,
                          const Color(0xFFDC143C),
                        ),
                        const SizedBox(height: 8),
                        _buildBarChart(byMonth),
                        const SizedBox(height: 24),
                        _buildStreakAndBadges(streak, badges, lifetime),
                        const SizedBox(height: 24),
                        _buildSectionTitle(
                          'Your Responses',
                          Icons.check_circle_outline_rounded,
                          const Color(0xFFDC143C),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Accepted & rejected requests',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildResponsesList(notifProvider),
                        SizedBox(
                          height: 16 + MediaQuery.of(context).padding.bottom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Consumer<WhatsAppChatProvider>(
            builder: (context, wa, _) {
              return FloatingActionButton(
                heroTag: 'wa_support',
                backgroundColor: const Color(0xFF25D366),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupportChatScreen(),
                    ),
                  );
                },
                child: Badge(
                  isLabelVisible: wa.unread > 0,
                  label: Text('${wa.unread}'),
                  child: const Icon(Icons.chat, color: Colors.white),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'quick_actions',
            onPressed: _showQuickActionsSheet,
            backgroundColor: _crimsonRed,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('Quick Actions'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, AuthProvider authProvider) {
    final user = authProvider.user;
    final profile = authProvider.donorProfile;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDC143C), // Crimson red
            Color(0xFFB91C1C), // Darker red
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFFFF8E1),
                      child: Text(
                        user?.username.isNotEmpty == true
                            ? user!.username.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC143C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Color(0xFFFFF8E1),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.displayName ?? user?.username ?? 'Donor',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (profile != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bloodtype_rounded,
                            color: Color(0xFFDC143C),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile.bloodGroup,
                            style: const TextStyle(
                              color: Color(0xFFDC143C),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        color: Color(0xFFDC143C),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Every drop counts!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Your donation can save up to 3 lives',
                            style: TextStyle(
                              color: Color(0xFFFFF8E1),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, [Color? color]) {
    final c = color ?? AppColors.primary;
    return Row(
      children: [
        Icon(icon, color: c, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // Updated color scheme: Off-white, cream, and red
  static const Color _crimsonRed = Color(0xFFDC143C);
  static const Color _lightCream = Color(0xFFFFF8E1);
  static const Color _softCream = Color(0xFFFFF3E0);
  static const Color _paleRed = Color(0xFFFFEBEE);
  static const Color _offWhite = Color(0xFFFAF8F5);

  Widget _buildTodayStatusCard({
    required AuthProvider authProvider,
    required NotificationProvider notifProvider,
    required int daysUntil,
    required int thisMonth,
  }) {
    final donorProfile = authProvider.donorProfile;
    final available = donorProfile?.isAvailable ?? false;
    final statusText = available ? 'Available for donation' : 'Busy right now';
    final statusColor = available
        ? const Color(0xFF059669)
        : const Color(0xFFD97706);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.verified_rounded, color: statusColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                Icons.notifications_rounded,
                '${notifProvider.unreadCount} unread',
              ),
              _statusChip(
                Icons.bloodtype_rounded,
                '$thisMonth donations this month',
              ),
              _statusChip(
                Icons.schedule_rounded,
                daysUntil == 0 ? 'Eligible now' : 'Eligible in $daysUntil days',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _offWhite,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _crimsonRed),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyBanner() {
    return AnimatedBuilder(
      animation: _emergencyPulse,
      builder: (context, child) {
        return Transform.scale(scale: _emergencyPulse.value, child: child);
      },
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DonorNotificationsScreen()),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFFB91C1C), Color(0xFFDC143C)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC143C).withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: const Row(
            children: [
              Icon(Icons.emergency_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Emergency request nearby. Tap to respond quickly.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNearestRequestCard(NotificationModel notification) {
    final request = notification.bloodRequest;
    final urgencyColor = AppColors.getUrgencyColor(request.urgency);
    final distance = notification.distanceKm;
    final location = (request.locationName ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DonorNotificationsScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_rounded,
                      color: _crimsonRed,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Nearest Request',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        request.urgencyDisplay.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: urgencyColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statusChip(
                      Icons.bloodtype_rounded,
                      '${request.bloodGroup} needed',
                    ),
                    _statusChip(
                      Icons.opacity_rounded,
                      '${request.unitsNeeded} unit(s)',
                    ),
                    _statusChip(
                      Icons.location_on_rounded,
                      distance != null
                          ? '${distance.toStringAsFixed(1)} km away'
                          : (location.isNotEmpty
                                ? location
                                : 'Distance unavailable'),
                    ),
                  ],
                ),
                if (request.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    request.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Requested ${_formatTime(request.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCards(
    int thisMonth,
    DateTime? lastDate,
    int lifetime,
    int daysUntil,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'This Month',
                '$thisMonth',
                Icons.bloodtype_rounded,
                _crimsonRed,
                _paleRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                'Last Donation',
                lastDate != null ? _formatDate(lastDate) : '—',
                Icons.event_rounded,
                const Color(0xFFB91C1C),
                _softCream,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Lifetime',
                '$lifetime',
                Icons.favorite_rounded,
                _crimsonRed,
                _lightCream,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                'Eligible In',
                daysUntil == 0 ? 'Now' : '$daysUntil days',
                Icons.schedule_rounded,
                daysUntil == 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFD97706),
                daysUntil == 0
                    ? const Color(0xFFD1FAE5)
                    : const Color(0xFFFEF3C7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color backgroundColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const Color _chartText = Color(0xFF374151);

  Widget _buildEligibilityProgress(
    double progress,
    int daysUntil,
    DateTime? lastDate,
  ) {
    final isEligible = daysUntil == 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: isEligible ? 1.0 : progress,
                    strokeWidth: 8,
                    backgroundColor: _offWhite,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isEligible ? const Color(0xFF059669) : _crimsonRed,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEligible ? '✓' : '$daysUntil',
                        style: TextStyle(
                          fontSize: isEligible ? 32 : 26,
                          fontWeight: FontWeight.bold,
                          color: isEligible
                              ? const Color(0xFF059669)
                              : _crimsonRed,
                        ),
                      ),
                      if (!isEligible)
                        const Text(
                          'days',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEligible ? 'Ready to Donate!' : 'Eligibility Status',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEligible
                        ? 'You are eligible to donate blood now'
                        : 'You can donate again in $daysUntil days',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (lastDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last donation: ${_formatDate(lastDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(Map<int, int> byDay) {
    final spots = byDay.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();
    if (spots.every((s) => s.y == 0)) {
      return _emptyChart('No donations this month', const Color(0xFFDBEAFE));
    }
    final maxY = byDay.values.isEmpty
        ? 1.0
        : byDay.values.reduce(math.max).toDouble();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFEFF6FF),
        border: Border.all(color: const Color(0xFFBFDBFE).withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.info.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 36,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'No. of donations',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _chartText,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 160,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: const Color(0xFF94A3B8).withOpacity(0.3),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _chartText,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              interval: 5,
                              getTitlesWidget: (v, _) => Text(
                                '${v.toInt()}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _chartText,
                                ),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 1,
                        maxX: 31,
                        minY: 0,
                        maxY: maxY < 1 ? 1 : maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: const Color(0xFF2563EB),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, data, index) =>
                                  FlDotCirclePainter(
                                    radius: 3.5,
                                    color: const Color(0xFF2563EB),
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF2563EB).withOpacity(0.12),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 250),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Day of month',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _chartText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<({String label, int count})> byMonth) {
    if (byMonth.every((e) => e.count == 0)) {
      return _emptyChart('No donations in last 12 months', _softCream);
    }
    final maxY = byMonth.map((e) => e.count).reduce(math.max).toDouble();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 36,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'No. of donations',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _chartText,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 188,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY < 1 ? 1 : maxY,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) => Text(
                                v.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _chartText,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 52,
                              getTitlesWidget: (v, meta) {
                                final i = v.toInt();
                                if (i < 0 || i >= byMonth.length) {
                                  return const SizedBox();
                                }
                                final count = byMonth[i].count;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        byMonth[i].label,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: _chartText,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _chartText,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: const Color(0xFF94A3B8).withOpacity(0.3),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(
                          byMonth.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: byMonth[i].count.toDouble(),
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xFFDC143C),
                                    Color(0xFFB91C1C),
                                  ],
                                ),
                                width: 14,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                            ],
                            showingTooltipIndicators: [],
                          ),
                        ),
                      ),
                      duration: const Duration(milliseconds: 250),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Month',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _chartText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(List<({String label, int count, Color color})> byType) {
    final total = byType.fold<int>(0, (s, e) => s + e.count);
    if (total == 0) {
      return _emptyChart('No donations yet', const Color(0xFFFEF3C7));
    }

    final sections = byType
        .where((e) => e.count > 0)
        .map(
          (e) => PieChartSectionData(
            value: e.count.toDouble(),
            title: '${e.count}',
            color: e.color,
            radius: 44,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        )
        .toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFCD34D).withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 28,
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: byType
                    .where((e) => e.count > 0)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: e.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${e.label}: ${e.count}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyChart(String message, [Color? cardColor]) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakAndBadges(int streak, List<bool> badges, int lifetime) {
    final labels = ['First', '5', '10', '25'];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: streak > 0 ? _lightCream : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    color: streak > 0 ? const Color(0xFFD97706) : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak Month Streak',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      streak > 0 ? 'Keep it up!' : 'Start your streak',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Achievements',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              runAlignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: List.generate(4, (i) {
                final unlocked = badges[i];
                return SizedBox(
                  width: 56,
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: unlocked ? _paleRed : _offWhite,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: unlocked
                                ? _crimsonRed.withOpacity(0.3)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          unlocked
                              ? Icons.emoji_events_rounded
                              : Icons.lock_rounded,
                          color: unlocked ? _crimsonRed : Colors.grey,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: unlocked
                              ? _crimsonRed
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ctaCard(
            context,
            title: 'Notifications',
            subtitle: 'View requests',
            icon: Icons.notifications_active_rounded,
            color: _crimsonRed,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DonorNotificationsScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ctaCard(
            context,
            title: 'My Profile',
            subtitle: 'Update details',
            icon: Icons.person_rounded,
            color: const Color(0xFFB91C1C),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DonorProfileScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _ctaCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCouponCards() {
    final coupons = [
      (
        title: 'Free Health Check',
        offer: 'Complimentary health screening on your next donation',
        code: 'B450HEALTH',
        gradient: [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
        icon: Icons.medical_services_rounded,
      ),
      (
        title: 'Snack Voucher',
        offer: 'Refreshments & snack after donation',
        code: 'B450SNACK',
        gradient: [const Color(0xFFF59E0B), const Color(0xFFE85D75)],
        icon: Icons.restaurant_rounded,
      ),
      (
        title: 'Donor Thank You',
        offer: 'Exclusive donor appreciation gift',
        code: 'B450THANKS',
        gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
        icon: Icons.card_giftcard_rounded,
      ),
      (
        title: 'Refer a Donor',
        offer: 'Reward when your friend donates',
        code: 'B450REFER',
        gradient: [const Color(0xFF10B981), const Color(0xFF059669)],
        icon: Icons.people_rounded,
      ),
    ];
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _couponCard(coupons[0])),
            const SizedBox(width: 12),
            Expanded(child: _couponCard(coupons[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _couponCard(coupons[2])),
            const SizedBox(width: 12),
            Expanded(child: _couponCard(coupons[3])),
          ],
        ),
      ],
    );
  }

  Widget _couponCard(
    ({
      String title,
      String offer,
      String code,
      List<Color> gradient,
      IconData icon,
    })
    c,
  ) {
    final primaryColor = c.gradient[0];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: c.gradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    primaryColor.withOpacity(0.2),
                                    (c.gradient.length > 1
                                            ? c.gradient[1]
                                            : primaryColor)
                                        .withOpacity(0.15),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                c.icon,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                c.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          c.offer,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'Use code',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.12),
                                      primaryColor.withOpacity(0.06),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  c.code,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                    letterSpacing: 0.8,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsesList(NotificationProvider notifProvider) {
    final responded = notifProvider.notifications
        .where((n) => n.hasResponded)
        .toList();
    if (responded.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lightCream,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 48,
                  color: _crimsonRed.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No responses yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your accepted or rejected requests will appear here',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DonorNotificationsScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _crimsonRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.notifications_rounded, size: 20),
                label: const Text('View blood requests'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: responded.length,
      itemBuilder: (context, index) {
        final notification = responded[index];
        final request = notification.bloodRequest;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonorNotificationsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.getBloodGroupColor(
                              request.bloodGroup,
                            ).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            request.bloodGroup,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.getBloodGroupColor(
                                request.bloodGroup,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.getUrgencyColor(
                              request.urgency,
                            ).withOpacity(0.2),
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
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${request.unitsNeeded} unit(s) needed',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (request.note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        request.note,
                        style: const TextStyle(color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                    ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: notification.responseStatus == 'accepted'
                              ? AppColors.success.withOpacity(0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
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
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notification.responseStatus == 'accepted'
                                  ? 'You accepted this request'
                                  : 'You rejected this request',
                              style: TextStyle(
                                color: notification.responseStatus == 'accepted'
                                    ? AppColors.success
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _formatDate(time);
  }

  Widget _buildDrawer(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final profile = authProvider.donorProfile;

    return Drawer(
      backgroundColor: _offWhite,
      child: SafeArea(
        bottom: true,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFDC143C), Color(0xFFB91C1C)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: _lightCream,
                      child: Text(
                        user?.username.isNotEmpty == true
                            ? user!.username.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC143C),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? user?.username ?? 'Donor',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (profile != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Blood Group: ${profile.bloodGroup}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _drawerTile(
              icon: Icons.notifications_rounded,
              title: 'Blood Requests',
              subtitle: 'View notifications',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonorNotificationsScreen(),
                  ),
                );
              },
            ),
            _drawerTile(
              icon: Icons.person_rounded,
              title: 'My Profile',
              subtitle: 'View your details',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DonorProfileScreen()),
                );
              },
            ),
            _drawerTile(
              icon: Icons.history_rounded,
              title: 'My Responses',
              subtitle: 'View response history',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DonorMyResponsesScreen(),
                  ),
                );
              },
            ),
            _drawerTile(
              icon: Icons.chat_rounded,
              title: 'WhatsApp Chats',
              subtitle: 'Support & admin messages',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SupportChatScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 32),
            _drawerTile(
              icon: Icons.logout_rounded,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              color: _crimsonRed,
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    final tileColor = color ?? const Color(0xFF1F2937);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tileColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tileColor, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: tileColor),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
