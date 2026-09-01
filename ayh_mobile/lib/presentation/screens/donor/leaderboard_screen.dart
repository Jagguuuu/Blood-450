import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/leaderboard_model.dart';
import '../../providers/leaderboard_provider.dart';

/// Donor leaderboard — loads real rankings from GET /api/leaderboard/.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const Color _crimsonRed = Color(0xFFDC143C);
  static const Color _darkRed = Color(0xFFB91C1C);
  static const Color _offWhite = Color(0xFFFAF8F5);
  static const Color _lightCream = Color(0xFFFFF8E1);
  static const Color _gold = Color(0xFFD4A017);
  static const Color _silver = Color(0xFF6B7280);
  static const Color _bronze = Color(0xFFB45309);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LeaderboardProvider>().loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _offWhite,
      body: Consumer<LeaderboardProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildBody(context, provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, LeaderboardProvider provider) {
    if (provider.isLoading && !provider.hasData) {
      return const Center(
        child: CircularProgressIndicator(color: _crimsonRed),
      );
    }

    if (provider.error != null && !provider.hasData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                provider.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: provider.loadLeaderboard,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _crimsonRed,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final topDonors = provider.topDonors;
    final rest = topDonors.where((d) => d.rank > 3).toList();
    final currentUser = provider.currentUser;

    return RefreshIndicator(
      color: _crimsonRed,
      onRefresh: provider.loadLeaderboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (topDonors.isEmpty)
                _buildEmptyLeaderboard()
              else ...[
                _buildPodium(topDonors),
                if (rest.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    icon: Icons.format_list_numbered_rounded,
                    title: 'Community Rankings',
                  ),
                  const SizedBox(height: 10),
                  ...rest.map(_buildRankCard),
                ],
              ],
              if (currentUser != null) ...[
                const SizedBox(height: 22),
                _buildYourImpact(currentUser),
              ],
              const SizedBox(height: 22),
              _buildRewardsPanel(),
              const SizedBox(height: 22),
              _buildCta(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLeaderboard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text(
            'No rankings yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Be the first donor to accept a blood request and climb the leaderboard.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_crimsonRed, _darkRed],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40B91C1C),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Back',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFD54F),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Donor Leaderboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Celebrating the people who save lives.',
                            style: TextStyle(
                              color: Color(0xFFFFF8E1),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Every donation makes a difference. See who\'s leading the Blood450 community.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPodium(List<LeaderboardEntry> topDonors) {
    LeaderboardEntry? byRank(int rank) {
      for (final donor in topDonors) {
        if (donor.rank == rank) return donor;
      }
      return null;
    }

    final first = byRank(1);
    final second = byRank(2);
    final third = byRank(3);

    if (first == null) return const SizedBox.shrink();

    if (second == null && third == null) {
      return _PodiumCard(
        donor: first,
        accent: _gold,
        medalLabel: '#1',
        highlight: true,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 10,
          child: second != null
              ? _PodiumCard(
                  donor: second,
                  accent: _silver,
                  medalLabel: '#2',
                  highlight: false,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 12,
          child: _PodiumCard(
            donor: first,
            accent: _gold,
            medalLabel: '#1',
            highlight: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 10,
          child: third != null
              ? _PodiumCard(
                  donor: third,
                  accent: _bronze,
                  medalLabel: '#3',
                  highlight: false,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRankCard(LeaderboardEntry donor) {
    final bloodColor = AppColors.getBloodGroupColor(donor.bloodGroup);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '#${donor.rank}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: _crimsonRed.withValues(alpha: 0.12),
              child: Text(
                donor.initials,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _crimsonRed,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    donor.badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: bloodColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      donor.bloodGroup,
                      style: TextStyle(
                        color: bloodColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${donor.donations} donations',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourImpact(LeaderboardCurrentUser currentUser) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.favorite_rounded,
            title: 'Your Impact',
          ),
          const SizedBox(height: 8),
          const Text(
            'One donation can help save multiple lives.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ImpactTile(
                  value: '${currentUser.donations}',
                  label: 'Donations',
                  icon: Icons.bloodtype_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ImpactTile(
                  value: '${currentUser.livesImpacted}',
                  label: 'Potential Lives Impacted',
                  icon: Icons.volunteer_activism_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _offWhite,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.military_tech_rounded,
                  size: 18,
                  color: _crimsonRed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${currentUser.badge} • Rank #${currentUser.rank}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB91C1C), Color(0xFFDC143C)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _crimsonRed.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Be Among the Top Donors 🎁',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stay active, help save lives, and unlock exclusive community rewards.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          const _RewardCard(
            icon: Icons.hotel_rounded,
            brand: 'MakeMyTrip',
            title: 'Travel Rewards',
            subtitle: 'Top donors can unlock special travel offers.',
          ),
          const SizedBox(height: 8),
          const _RewardCard(
            icon: Icons.fitness_center_rounded,
            brand: 'Protein / Fitness Kit',
            title: 'Health & Fitness',
            subtitle: 'Exclusive wellness rewards for active donors.',
          ),
          const SizedBox(height: 8),
          const _RewardCard(
            icon: Icons.confirmation_number_rounded,
            brand: 'Partner Offers',
            title: 'Special Benefits',
            subtitle: 'Enjoy exclusive offers from Blood450 partners.',
          ),
        ],
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Keep donating. Keep saving lives.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        _LeaderboardCta(onPressed: () => _showCtaDialog(context)),
      ],
    );
  }

  void _showCtaDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keep saving lives'),
        content: const Text(
          'Stay active in the Blood450 community to climb the leaderboard and unlock exclusive rewards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _LeaderboardScreenState._crimsonRed),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final LeaderboardEntry donor;
  final Color accent;
  final String medalLabel;
  final bool highlight;

  const _PodiumCard({
    required this.donor,
    required this.accent,
    required this.medalLabel,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final bloodColor = AppColors.getBloodGroupColor(donor.bloodGroup);
    final avatarRadius = highlight ? 28.0 : 22.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        8,
        highlight ? 14 : 10,
        8,
        highlight ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlight
              ? _LeaderboardScreenState._gold.withValues(alpha: 0.55)
              : accent.withValues(alpha: 0.28),
          width: highlight ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? _LeaderboardScreenState._gold.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: highlight ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (highlight)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Icon(
                Icons.emoji_events_rounded,
                color: _LeaderboardScreenState._gold,
                size: 26,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              medalLabel,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: highlight ? 13 : 11,
              ),
            ),
          ),
          const SizedBox(height: 8),
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: highlight
                ? _LeaderboardScreenState._lightCream
                : _LeaderboardScreenState._crimsonRed.withValues(alpha: 0.10),
            child: Text(
              donor.initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _LeaderboardScreenState._crimsonRed,
                fontSize: highlight ? 16 : 13,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              donor.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: highlight ? 13 : 12,
                height: 1.2,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: bloodColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                donor.bloodGroup,
                style: TextStyle(
                  color: bloodColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${donor.donations} Donations',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: highlight ? 12 : 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              donor.badge,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImpactTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _ImpactTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: _LeaderboardScreenState._offWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: _LeaderboardScreenState._crimsonRed),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final IconData icon;
  final String brand;
  final String title;
  final String subtitle;

  const _RewardCard({
    required this.icon,
    required this.brand,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _LeaderboardScreenState._lightCream,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: _LeaderboardScreenState._crimsonRed,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: _LeaderboardScreenState._crimsonRed,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCta extends StatelessWidget {
  final VoidCallback onPressed;

  const _LeaderboardCta({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Become a Top Donor',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
