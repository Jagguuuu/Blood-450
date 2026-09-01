import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ayh_mobile/core/theme/app_theme.dart';
import 'package:ayh_mobile/data/models/leaderboard_model.dart';
import 'package:ayh_mobile/presentation/providers/leaderboard_provider.dart';
import 'package:ayh_mobile/presentation/screens/donor/leaderboard_screen.dart';

class _FakeLeaderboardProvider extends LeaderboardProvider {
  _FakeLeaderboardProvider({
    required LeaderboardData data,
    this.initialLoading = false,
    this.initialError,
  }) : _seed = data;

  final bool initialLoading;
  final String? initialError;
  final LeaderboardData _seed;

  @override
  bool get isLoading => initialLoading;

  @override
  String? get error => initialError;

  @override
  bool get hasData => initialError == null && !initialLoading;

  @override
  List<LeaderboardEntry> get topDonors => _seed.topDonors;

  @override
  LeaderboardCurrentUser? get currentUser => _seed.currentUser;

  @override
  Future<void> loadLeaderboard() async {}
}

LeaderboardData _sampleData({int topCount = 10}) {
  final donors = <LeaderboardEntry>[
    const LeaderboardEntry(
      rank: 1,
      name: 'Rahul Sharma',
      bloodGroup: 'O+',
      donations: 27,
      badge: '🏆 Life Saver',
    ),
    const LeaderboardEntry(
      rank: 2,
      name: 'Arjun Kumar',
      bloodGroup: 'B+',
      donations: 18,
      badge: '⭐ Hero Donor',
    ),
    const LeaderboardEntry(
      rank: 3,
      name: 'Priya Das',
      bloodGroup: 'A+',
      donations: 15,
      badge: '💎 Elite Donor',
    ),
    const LeaderboardEntry(
      rank: 4,
      name: 'Shiva Kumar',
      bloodGroup: 'O+',
      donations: 13,
      badge: '❤️ Community Hero',
    ),
    const LeaderboardEntry(
      rank: 5,
      name: 'Ananya Patel',
      bloodGroup: 'A+',
      donations: 11,
      badge: '🔥 Active Donor',
    ),
    const LeaderboardEntry(
      rank: 6,
      name: 'Rohan Das',
      bloodGroup: 'AB+',
      donations: 9,
      badge: '⭐ Hero Donor',
    ),
    const LeaderboardEntry(
      rank: 7,
      name: 'Sneha Rao',
      bloodGroup: 'B+',
      donations: 8,
      badge: '❤️ Community Hero',
    ),
    const LeaderboardEntry(
      rank: 8,
      name: 'Karthik Singh',
      bloodGroup: 'O-',
      donations: 7,
      badge: '🔥 Active Donor',
    ),
    const LeaderboardEntry(
      rank: 9,
      name: 'Neha Sharma',
      bloodGroup: 'A-',
      donations: 6,
      badge: '❤️ Community Hero',
    ),
    const LeaderboardEntry(
      rank: 10,
      name: 'Vikram Das',
      bloodGroup: 'B-',
      donations: 5,
      badge: '🔥 Active Donor',
    ),
  ];

  return LeaderboardData(
    topDonors: donors.take(topCount).toList(),
    currentUser: const LeaderboardCurrentUser(
      rank: 37,
      name: 'Demo Donor',
      bloodGroup: 'AB+',
      donations: 3,
      badge: '🔥 Active Donor',
      livesImpacted: 9,
    ),
  );
}

Future<void> pumpLeaderboard(
  WidgetTester tester,
  LeaderboardProvider provider, {
  Size size = const Size(360, 640),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ChangeNotifierProvider<LeaderboardProvider>.value(
        value: provider,
        child: const LeaderboardScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('Leaderboard screen renders API data without overflow', (
    tester,
  ) async {
    await pumpLeaderboard(
      tester,
      _FakeLeaderboardProvider(data: _sampleData()),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('Donor Leaderboard'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Arjun Kumar'), findsOneWidget);
    expect(find.text('Priya Das'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Become a Top Donor'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Shiva Kumar'), findsOneWidget);
    expect(find.text('Vikram Das'), findsOneWidget);
    expect(find.text('Your Impact'), findsOneWidget);
    expect(find.text('Be Among the Top Donors 🎁'), findsOneWidget);
    expect(find.text('MakeMyTrip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Leaderboard screen shows loading state', (tester) async {
    await pumpLeaderboard(
      tester,
      _FakeLeaderboardProvider(
        data: const LeaderboardData(topDonors: []),
        initialLoading: true,
      ),
      settle: false,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Leaderboard screen shows error state with retry', (tester) async {
    await pumpLeaderboard(
      tester,
      _FakeLeaderboardProvider(
        data: const LeaderboardData(topDonors: []),
        initialError: 'Unable to load leaderboard. Please try again.',
      ),
    );
    expect(find.text('Unable to load leaderboard. Please try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Leaderboard screen handles fewer than 10 donors', (tester) async {
    await pumpLeaderboard(
      tester,
      _FakeLeaderboardProvider(data: _sampleData(topCount: 3)),
    );
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Priya Das'), findsOneWidget);
    expect(find.text('Community Rankings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Leaderboard screen shows empty state', (tester) async {
    await pumpLeaderboard(
      tester,
      _FakeLeaderboardProvider(
        data: const LeaderboardData(
          topDonors: [],
          currentUser: LeaderboardCurrentUser(
            rank: 1,
            name: 'Solo Donor',
            bloodGroup: 'O+',
            donations: 0,
            badge: '🌱 New Donor',
            livesImpacted: 0,
          ),
        ),
      ),
    );
    expect(find.text('No rankings yet'), findsOneWidget);
    expect(find.text('Your Impact'), findsOneWidget);
  });

  testWidgets('Leaderboard screen fits a very small phone width', (tester) async {
    await pumpLeaderboard(
      tester,
      _FakeLeaderboardProvider(data: _sampleData()),
      size: const Size(320, 568),
    );
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Become a Top Donor'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
