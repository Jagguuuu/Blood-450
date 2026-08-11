import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/blood_request_provider.dart';
import '../../providers/donor_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/donor_profile.dart';
import '../../widgets/admin_request_detail_sheet.dart';
import '../auth/login_screen.dart';
import 'create_request_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _bloodFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).loadDashboardStats();
      Provider.of<DonorProvider>(context, listen: false).loadAllDonors();
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      Provider.of<DashboardProvider>(context, listen: false).loadDashboardStats(),
      Provider.of<DonorProvider>(context, listen: false).loadAllDonors(),
    ]);
  }

  Future<void> _openRequestDetail(BuildContext context, int requestId) async {
    final bloodRequestProvider = Provider.of<BloodRequestProvider>(context, listen: false);
    await bloodRequestProvider.loadRequestDetail(requestId);
    if (!context.mounted) return;
    final request = bloodRequestProvider.selectedRequest;
    if (request != null) {
      AdminRequestDetailSheet.show(
        context,
        request: request,
        acceptedDonors: request.acceptedDonors,
      );
    }
  }

  Future<void> _handleLogout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<DonorProfile> _filterDonors(List<DonorProfile> donors) {
    return donors.where((d) {
      final name = (d.user?.firstName ?? d.username).toString().toLowerCase();
      final phone = d.phone.toLowerCase();
      final bg = d.bloodGroup.toLowerCase();
      if (_bloodFilter != null && d.bloodGroup != _bloodFilter) return false;
      if (_searchQuery.isEmpty) return true;
      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          bg.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softWhite,
      appBar: AppBar(
        title: const Text('Blood450 Admin'),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
        actions: [
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _handleLogout),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CreateRequestScreen()))
              .then((_) => _handleRefresh());
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Request'),
      ),
      body: Consumer2<DashboardProvider, DonorProvider>(
        builder: (context, dashProvider, donorProvider, _) {
          if (dashProvider.isLoading && dashProvider.stats == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (dashProvider.stats == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(dashProvider.error ?? 'Failed to load dashboard'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _handleRefresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final stats = dashProvider.stats!;
          final donors = _filterDonors(donorProvider.allDonors);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _handleRefresh,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _PremiumStatCard(
                        title: 'Total Donors',
                        value: '${stats.totalDonors}',
                        icon: Icons.people_rounded,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PremiumStatCard(
                        title: 'Total Requests',
                        value: '${stats.totalRequests}',
                        icon: Icons.bloodtype_rounded,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PremiumStatCard(
                        title: 'Active Donors',
                        value: '${stats.availableDonors}',
                        icon: Icons.volunteer_activism_rounded,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PremiumStatCard(
                        title: 'Blood Banks',
                        value: '${stats.activeRequests}',
                        icon: Icons.local_hospital_rounded,
                        onTap: () {},
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Donors',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${donors.length} shown',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search name, phone, blood group...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _bloodFilter == null,
                        onTap: () => setState(() => _bloodFilter = null),
                      ),
                      ...['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map(
                        (bg) => _FilterChip(
                          label: bg,
                          selected: _bloodFilter == bg,
                          onTap: () => setState(() => _bloodFilter = bg),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (donorProvider.isLoading && donorProvider.allDonors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                else if (donors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No donors match your search', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                else
                  ...donors.map((d) => _DonorCard(donor: d)),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Requests',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton(onPressed: _handleRefresh, child: const Text('Refresh')),
                  ],
                ),
                const SizedBox(height: 12),
                if (stats.recentRequests.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No requests yet')),
                  )
                else
                  ...stats.recentRequests.map(
                    (request) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: InkWell(
                        onTap: () => _openRequestDetail(context, request.id),
                        borderRadius: BorderRadius.circular(20),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.getBloodGroupColor(request.bloodGroup)
                                .withValues(alpha: 0.15),
                            child: Text(
                              request.bloodGroup,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.getBloodGroupColor(request.bloodGroup),
                              ),
                            ),
                          ),
                          title: Text('${request.unitsNeeded} unit(s) - ${request.urgencyDisplay}'),
                          subtitle: Text(
                            request.locationName ?? request.note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (request.status == 'fulfilled' || request.isFulfilled)
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : request.isActive
                                      ? AppColors.info.withValues(alpha: 0.15)
                                      : AppColors.divider,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (request.status == 'fulfilled' || request.isFulfilled)
                                  ? 'FULFILLED'
                                  : request.isActive
                                      ? 'ACTIVE'
                                      : 'CLOSED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: (request.status == 'fulfilled' || request.isFulfilled)
                                    ? AppColors.success
                                    : request.isActive
                                        ? AppColors.info
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PremiumStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _PremiumStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_PremiumStatCard> createState() => _PremiumStatCardState();
}

class _PremiumStatCardState extends State<_PremiumStatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: Colors.white, size: 28),
              const SizedBox(height: 12),
              Text(
                widget.value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonorCard extends StatelessWidget {
  final DonorProfile donor;

  const _DonorCard({required this.donor});

  @override
  Widget build(BuildContext context) {
    final name = donor.user?.fullName ?? '';
    final displayName = name.isEmpty ? donor.username : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.lightRed,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        donor.lastLat != null
                            ? 'Location on file'
                            : 'Location not set',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Joined ${_formatDate(donor.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.getBloodGroupColor(donor.bloodGroup).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  donor.bloodGroup,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.getBloodGroupColor(donor.bloodGroup),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                donor.isAvailable ? Icons.check_circle : Icons.pause_circle,
                size: 18,
                color: donor.isAvailable ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.lightRed,
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primaryDark : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
