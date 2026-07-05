import 'package:flutter/material.dart';
import 'models/ride.dart';
import 'services/active_ride_store.dart';
import 'theme/app_theme.dart';
import 'utils/formatters.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/live_ride_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/bottom_nav_bar.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Velocity',
      theme: AppTheme.theme,
      home: const MainScaffold(),
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  late final List<Widget> _pages = [
    HomeScreen(onStartRide: _startRecording),
    const HistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkActiveRide());
  }

  /// Detects a ride left in progress from a previous app session (closed or
  /// killed before STOP was tapped) and offers to resume or discard it.
  Future<void> _checkActiveRide() async {
    final snapshot = await ActiveRideStore.load();
    if (snapshot == null || !mounted) return;

    final preview = Ride(
      id: '',
      startTime: snapshot.startTime,
      endTime: DateTime.now(),
      points: snapshot.points,
    );
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Unfinished ride found'),
        content: Text(
          'Velocity closed while a ride was recording '
          '(${fmtDuration(DateTime.now().difference(snapshot.startTime))} · '
          '${fmtDistance(preview.distanceKm)} km). Resume it or discard?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('DISCARD',
                style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('RESUME',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );

    if (resume == true) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RideRecordingScreen(resumeSnapshot: snapshot),
        ),
      );
    } else {
      await ActiveRideStore.clear();
    }
  }

  /// Launches the recording flow as a full-screen route. Because it sits above
  /// the navigation Scaffold, the bottom bar is hidden and the ride can't be
  /// abandoned by tapping another tab.
  void _startRecording() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RideRecordingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: StyledBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        onRecord: _startRecording,
      ),
    );
  }
}
