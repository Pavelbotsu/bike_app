import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
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
      title: 'Velocity Bike App',
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
