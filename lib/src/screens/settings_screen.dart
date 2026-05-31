import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';
import 'hud_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'SETTINGS',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _SectionHeader(label: 'DISPLAY'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.dashboard_outlined,
            label: 'HUD Layouts',
            subtitle: 'Customize live ride metrics',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HudSettingsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'ABOUT'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.info_outline,
            label: 'Version',
            subtitle: '0.1.0',
            onTap: null,
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            label: 'Open-source licenses',
            subtitle: 'Third-party libraries',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Velocity',
              applicationVersion: '0.1.0',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: RoundedCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
