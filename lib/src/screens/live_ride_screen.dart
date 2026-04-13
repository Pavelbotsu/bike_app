import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';

class LiveRideScreen extends StatelessWidget {
  const LiveRideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF090A0E), Color(0xFF0B1119)],
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Colors.white10, Colors.transparent],
                    center: Alignment.topCenter,
                    radius: 0.6,
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopChips(),
                const SizedBox(height: 28),
                const _SpeedCard(),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Expanded(
                      child: _MetricBubble(label: 'DISTANCE', value: '12.4 km'),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _MetricBubble(label: 'TIME', value: '24:18'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Expanded(
                      child: _MetricBubble(label: 'ELEVATION', value: '342 m'),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: _MetricBubble(
                        label: 'CALORIES',
                        value: '285 kcal',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const _ActionButtons(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopChips() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Chip(label: 'LIVE RIDE', color: AppColors.accent.withOpacity(0.22)),
        _Chip(
          label: 'SIGNAL STRONG',
          color: AppColors.highlight.withOpacity(0.18),
        ),
      ],
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard();

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Text(
            'SPEED',
            style: TextStyle(
              color: AppColors.textSecondary,
              letterSpacing: 1.6,
            ),
          ),
          SizedBox(height: 18),
          Text(
            '34.2',
            style: TextStyle(
              fontSize: 74,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'KM/H',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBubble extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBubble({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF181C28),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () {},
            icon: const Icon(Icons.pause, color: AppColors.textPrimary),
            label: const Text(
              'PAUSE',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () {},
            icon: const Icon(Icons.stop, color: Colors.white),
            label: const Text(
              'STOP',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
