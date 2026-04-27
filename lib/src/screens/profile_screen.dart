import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            const _LifetimeMetricsCard(),
            const SizedBox(height: 24),
            _buildSectionTitle('ACHIEVEMENTS GALLERY', actionText: 'VIEW ALL'),
            const SizedBox(height: 16),
            _buildAchievementsGallery(),
            const SizedBox(height: 24),
            _buildSectionTitle('ACTIVITY HISTORY'),
            const SizedBox(height: 16),
            Expanded(child: _buildActivityHistory()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.accent,
          child: Icon(Icons.person, size: 32, color: AppColors.background),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Elena Rodriguez',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 6),
              Text(
                'location_on BARCELONA, SPAIN',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {},
          child: const Text(
            'EDIT',
            style: TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
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

  Widget _buildAchievementsGallery() {
    return SizedBox(
      height: 98,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: const [
          _AchievementBadge(
            label: 'PR EARNED',
            subtitle: 'Fastest 40km',
            color: AppColors.accent,
          ),
          SizedBox(width: 12),
          _AchievementBadge(
            label: 'STREAK',
            subtitle: 'Climb King',
            color: AppColors.highlight,
          ),
          SizedBox(width: 12),
          _AchievementBadge(
            label: 'RIDE MASTER',
            subtitle: '1000 km',
            color: Color(0xFF8C6BFF),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityHistory() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: const [
        _HistoryTile(
          date: 'OCT 12, 2023 • 07:15 AM',
          title: 'Morning Coastal Sprint',
          stats: '42.8 km • 1:24:12 • 32.4 avg km/h',
        ),
        SizedBox(height: 14),
        _HistoryTile(
          date: 'OCT 09, 2023 • 09:30 AM',
          title: 'Tibidabo Summit Climb',
          stats: '28.5 km • 2:05:33 • 850 elev gain',
        ),
        SizedBox(height: 14),
        _HistoryTile(
          date: 'OCT 07, 2023 • 05:45 PM',
          title: 'Rest Day Recovery Ride',
          stats: '15.2 km • 0:45:00 • 20.1 avg km/h',
        ),
      ],
    );
  }
}

class _LifetimeMetricsCard extends StatelessWidget {
  const _LifetimeMetricsCard();

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LIFETIME METRICS',
            style: TextStyle(
              color: AppColors.textSecondary,
              letterSpacing: 1.8,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '12,482',
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'KM',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          const _MetricRow(label: 'RIDES COMPLETED', value: '412 units'),
          const SizedBox(height: 14),
          const _MetricRow(
            label: 'ELEVATION GAIN',
            value: '84.2 k meters',
            valueColor: AppColors.highlight,
          ),
          const SizedBox(height: 24),
          const LinearProgressIndicator(
            value: 0.78,
            color: AppColors.accent,
            backgroundColor: Color(0xFF1A1D28),
          ),
          const SizedBox(height: 10),
          const Text(
            'GOAL: 15,000 KM • 78% COMPLETE',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, color: valueColor),
        ),
      ],
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;

  const _AchievementBadge({
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      width: 160,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String date;
  final String title;
  final String stats;

  const _HistoryTile({
    required this.date,
    required this.title,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              date,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              stats,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
