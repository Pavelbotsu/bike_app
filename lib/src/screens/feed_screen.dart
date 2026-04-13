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
            _buildHeader(),
            const SizedBox(height: 24),
            const _TopPerformersSection(),
            const SizedBox(height: 24),
            Expanded(child: _buildFeedList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'TOP PERFORMERS',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildFeedList() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: const [
        _FeedPostCard(
          author: 'Sarah Jenkins',
          title: 'MORNING CANYON SPRINT',
          time: '2 HOURS AGO',
          distance: '42.8 km',
          duration: '1:24 hr',
          metricLabel: 'ELEVATION',
          metricValue: '840 m',
          likes: 128,
          comments: 14,
        ),
        SizedBox(height: 18),
        _FeedPostCard(
          author: "Tom 'Wheels' Brooks",
          title: 'COASTAL RECOVERY ROLL',
          time: '5 HOURS AGO',
          distance: '22.1 km',
          duration: '0:52 hr',
          metricLabel: 'AVG WATTS',
          metricValue: '185 w',
          likes: 45,
          comments: 3,
        ),
      ],
    );
  }
}

class _TopPerformersSection extends StatelessWidget {
  const _TopPerformersSection();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _TopPerformerCard(
          position: '1st',
          name: 'Marcus V.',
          distance: '428.5 km',
          accentColor: AppColors.highlight,
        ),
        SizedBox(width: 12),
        Expanded(
          child: _TopPerformerCard(
            position: '2nd',
            name: 'Elena R.',
            distance: '392.1 km',
            accentColor: AppColors.accent,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _TopPerformerCard(
            position: '3rd',
            name: 'David S.',
            distance: '385.0 km',
            accentColor: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _TopPerformerCard extends StatelessWidget {
  final String position;
  final String name;
  final String distance;
  final Color accentColor;

  const _TopPerformerCard({
    required this.position,
    required this.name,
    required this.distance,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: accentColor.withOpacity(0.24),
            child: Text(
              position,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            distance,
            style: const TextStyle(
              color: AppColors.highlight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  final String author;
  final String title;
  final String time;
  final String distance;
  final String duration;
  final String metricLabel;
  final String metricValue;
  final int likes;
  final int comments;

  const _FeedPostCard({
    required this.author,
    required this.title,
    required this.time,
    required this.distance,
    required this.duration,
    required this.metricLabel,
    required this.metricValue,
    required this.likes,
    required this.comments,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surface,
                child: Icon(Icons.person, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetricColumn(label: 'DISTANCE', value: distance),
              _MetricColumn(label: 'TIME', value: duration),
              _MetricColumn(
                label: metricLabel,
                value: metricValue,
                accent: AppColors.highlight,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1220),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.photo,
                size: 42,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_border, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    '$likes',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$comments',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Icon(Icons.share, color: AppColors.highlight),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MetricColumn({
    required this.label,
    required this.value,
    this.accent = AppColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ],
    );
  }
}
