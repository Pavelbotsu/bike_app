import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/map_tiles.dart';
import '../widgets/rounded_card.dart';
import 'hud_settings_screen.dart';

const _kWeightKey = 'prefs_weight_kg';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _weightKg = 75.0;
  MapStyle _mapStyle = MapStyle.standard;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _weightKg = prefs.getDouble(_kWeightKey) ?? 75.0;
      });
    }
    final style = await loadMapStyle();
    if (mounted) setState(() => _mapStyle = style);
  }

  Future<void> _editWeight() async {
    final controller =
        TextEditingController(text: _weightKg.round().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Body weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            suffixText: 'kg',
            hintText: '75',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2A2D3E)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.of(context).pop(v);
            },
            child: const Text('SAVE',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && result < 300) {
      setState(() => _weightKg = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kWeightKey, result);
    }
  }

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
          _SectionHeader(label: 'RIDER'),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.monitor_weight_outlined,
            label: 'Body weight',
            subtitle: '${_weightKg.round()} kg  ·  used for calorie estimates',
            onTap: _editWeight,
          ),
          const SizedBox(height: 24),
          _SectionHeader(label: 'MAP'),
          const SizedBox(height: 10),
          RoundedCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tile style',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 10),
                SegmentedButton<MapStyle>(
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.background,
                    selectedBackgroundColor: AppColors.accent,
                    selectedForegroundColor: Colors.white,
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Color(0xFF2A2D3E)),
                  ),
                  segments: MapStyle.values
                      .map((s) => ButtonSegment<MapStyle>(
                            value: s,
                            label: Text(mapStyleLabel(s),
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  selected: {_mapStyle},
                  onSelectionChanged: (sel) async {
                    final style = sel.first;
                    setState(() => _mapStyle = style);
                    await saveMapStyle(style);
                  },
                ),
              ],
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
