import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bottom navigation with four visual slots: HOME · HISTORY · a raised central
/// RECORD button · PROFILE. The three tabs drive [onTap]; the central record
/// affordance is a separate action ([onRecord]) that launches the full-screen
/// recording flow — it is not a tab, so a ride can't be left by tapping around.
class StyledBottomNavBar extends StatelessWidget {
  /// Index of the active tab: 0 = Home, 1 = History, 2 = Profile.
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onRecord;

  const StyledBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavTab(
              icon: Icons.home_filled,
              label: 'HOME',
              selected: selectedIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavTab(
              icon: Icons.bar_chart_rounded,
              label: 'HISTORY',
              selected: selectedIndex == 1,
              onTap: () => onTap(1),
            ),
            _RecordButton(onTap: onRecord),
            _NavTab(
              icon: Icons.person,
              label: 'PROFILE',
              selected: selectedIndex == 2,
              onTap: () => onTap(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentSoft, AppColors.accent],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.directions_bike_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'RECORD',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
