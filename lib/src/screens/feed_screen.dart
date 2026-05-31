import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ROUTES',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: const [
                  _RouteCard(
                    name: 'Coastal Loop',
                    distance: '34.2 km',
                    elevation: '210m gain',
                    terrain: _Terrain.road,
                    difficulty: _Difficulty.moderate,
                  ),
                  SizedBox(height: 14),
                  _RouteCard(
                    name: 'Misty Ridge Trail',
                    distance: '15.4 km',
                    elevation: '420m gain',
                    terrain: _Terrain.gravel,
                    difficulty: _Difficulty.hard,
                  ),
                  SizedBox(height: 14),
                  _RouteCard(
                    name: 'City Circuit',
                    distance: '12.5 km',
                    elevation: '65m gain',
                    terrain: _Terrain.road,
                    difficulty: _Difficulty.easy,
                  ),
                  SizedBox(height: 14),
                  _RouteCard(
                    name: 'Forest Switchbacks',
                    distance: '22.8 km',
                    elevation: '680m gain',
                    terrain: _Terrain.trail,
                    difficulty: _Difficulty.hard,
                  ),
                  SizedBox(height: 14),
                  _RouteCard(
                    name: 'Riverside Path',
                    distance: '8.3 km',
                    elevation: '30m gain',
                    terrain: _Terrain.road,
                    difficulty: _Difficulty.easy,
                  ),
                  SizedBox(height: 14),
                  _RouteCard(
                    name: 'Mountain Pass',
                    distance: '45.0 km',
                    elevation: '1,240m gain',
                    terrain: _Terrain.gravel,
                    difficulty: _Difficulty.hard,
                  ),
                  SizedBox(height: 14),
                  _RouteCard(
                    name: 'Old Town Classic',
                    distance: '18.6 km',
                    elevation: '120m gain',
                    terrain: _Terrain.road,
                    difficulty: _Difficulty.moderate,
                  ),
                  SizedBox(height: 14),
                  _RouteCard(
                    name: 'Valley Gravel Loop',
                    distance: '28.4 km',
                    elevation: '380m gain',
                    terrain: _Terrain.gravel,
                    difficulty: _Difficulty.moderate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Terrain { road, gravel, trail }

enum _Difficulty { easy, moderate, hard }

class _RouteCard extends StatelessWidget {
  final String name;
  final String distance;
  final String elevation;
  final _Terrain terrain;
  final _Difficulty difficulty;

  const _RouteCard({
    required this.name,
    required this.distance,
    required this.elevation,
    required this.terrain,
    required this.difficulty,
  });

  Color get _terrainColor => switch (terrain) {
        _Terrain.road => AppColors.highlight,
        _Terrain.gravel => AppColors.accent,
        _Terrain.trail => const Color(0xFF8C6BFF),
      };

  String get _terrainLabel => switch (terrain) {
        _Terrain.road => 'ROAD',
        _Terrain.gravel => 'GRAVEL',
        _Terrain.trail => 'TRAIL',
      };

  Color get _difficultyColor => switch (difficulty) {
        _Difficulty.easy => AppColors.success,
        _Difficulty.moderate => AppColors.accent,
        _Difficulty.hard => Colors.redAccent,
      };

  String get _difficultyLabel => switch (difficulty) {
        _Difficulty.easy => 'EASY',
        _Difficulty.moderate => 'MODERATE',
        _Difficulty.hard => 'HARD',
      };

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF161826),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.route, color: AppColors.highlight, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$distance  •  $elevation',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Chip(label: _terrainLabel, color: _terrainColor),
                    const SizedBox(width: 8),
                    _Chip(label: _difficultyLabel, color: _difficultyColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
