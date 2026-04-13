import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';
import '../widgets/stat_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            const _DailyGoalCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('Recent Rides', actionText: 'VIEW ALL'),
            const SizedBox(height: 16),
            _buildRecentRides(),
            const SizedBox(height: 24),
            _buildSectionTitle('Explore Routes'),
            const SizedBox(height: 16),
            const _ExploreRouteCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.surface,
          child: Icon(Icons.person, size: 28, color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MORNING, RIDER', style: theme.titleMedium),
              const SizedBox(height: 4),
              Text('VELOCITY', style: theme.displaySmall),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_none,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, {String? actionText}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (actionText != null)
          Text(
            actionText,
            style: const TextStyle(fontSize: 12, color: AppColors.accent),
          ),
      ],
    );
  }

  Widget _buildRecentRides() {
    return SizedBox(
      height: 210,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: const [
          _RecentRideCard(
            title: 'COASTAL LOOP',
            date: 'TUESDAY MORNING',
            distance: '34.2 km',
            image: 'assets/images/ride_map_1.png',
          ),
          SizedBox(width: 16),
          _RecentRideCard(
            title: 'CITY SPRING',
            date: 'YESTERDAY',
            distance: '12.5 km',
            image: 'assets/images/ride_map_2.png',
          ),
        ],
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard();

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              const _ProgressRing(value: 0.75),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '75%\nDAILY GOAL',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _MiniStat(label: 'DISTANCE', value: '42.8 km'),
                        _MiniStat(label: 'TIME', value: '1:45 hrs'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Expanded(
                child: StatTile(
                  label: 'CALORIES',
                  value: '1,240 kcal',
                  accent: AppColors.accent,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'ELEVATION',
                  value: '850 m',
                  accent: AppColors.highlight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () {},
              icon: const Icon(Icons.play_arrow),
              label: const Text('START RIDE'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double value;

  const _ProgressRing({required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value,
            strokeWidth: 12,
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            backgroundColor: const Color(0xFF1B1C27),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _RecentRideCard extends StatelessWidget {
  final String title;
  final String date;
  final String distance;
  final String image;

  const _RecentRideCard({
    required this.title,
    required this.date,
    required this.distance,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      width: 268,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFF161826),
            ),
            child: const Center(
              child: Icon(Icons.map, size: 48, color: AppColors.highlight),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            date,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          Text(
            distance,
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreRouteCard extends StatelessWidget {
  const _ExploreRouteCard();

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1C293F), Color(0xFF122123)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.explore, size: 64, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'MISTY RIDGES',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            '15.4 km • 420m gain',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _RouteChip(
                label: 'GRAVEL PATHS',
                accentColor: AppColors.highlight,
              ),
              _RouteChip(label: 'VELODROME', accentColor: AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _RouteChip({required this.label, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
