import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/feed_screen.dart';
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
    HomeScreen(onStartRide: () => _onDestinationSelected(2)),
    const FeedScreen(),
    const LiveRideScreen(),
    const ProfileScreen(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: StyledBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onDestinationSelected,
      ),
    );
  }
}
