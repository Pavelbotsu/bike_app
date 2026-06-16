import 'package:flutter/material.dart';
import '../models/hud_config.dart';
import '../theme/app_theme.dart';
import '../widgets/rounded_card.dart';
import 'hud_grid_editor_screen.dart';

class HudSettingsScreen extends StatefulWidget {
  const HudSettingsScreen({super.key});

  @override
  State<HudSettingsScreen> createState() => _HudSettingsScreenState();
}

class _HudSettingsScreenState extends State<HudSettingsScreen> {
  List<HudConfig> _configs = [];
  int _activeIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configs = await HudConfigService.instance.loadAll();
    final active = await HudConfigService.instance.getActiveIndex();
    if (mounted) {
      setState(() {
        _configs = configs;
        _activeIndex = active.clamp(0, configs.length - 1);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    await HudConfigService.instance.saveAll(_configs);
    await HudConfigService.instance.setActiveIndex(_activeIndex);
  }

  void _setActive(int index) {
    setState(() => _activeIndex = index);
    _save();
  }

  void _editConfig(int index) async {
    final updated = await Navigator.of(context).push<HudConfig>(
      MaterialPageRoute(
        builder: (_) => _EditHudScreen(config: _configs[index]),
      ),
    );
    if (updated != null) {
      setState(() => _configs[index] = updated);
      _save();
    }
  }

  void _editGridLayout(int index) async {
    final updated = await Navigator.of(context).push<HudConfig>(
      MaterialPageRoute(
        builder: (_) => HudGridEditorScreen(config: _configs[index]),
      ),
    );
    if (updated != null) {
      setState(() => _configs[index] = updated);
      _save();
    }
  }

  void _addConfig() async {
    final newConfig = HudConfig(
      name: 'Config ${_configs.length + 1}',
      primary: [HudMetric.speed],
      secondary: [HudMetric.distance, HudMetric.time],
    );
    final updated = await Navigator.of(context).push<HudConfig>(
      MaterialPageRoute(builder: (_) => _EditHudScreen(config: newConfig)),
    );
    if (updated != null) {
      setState(() => _configs.add(updated));
      _save();
    }
  }

  void _deleteConfig(int index) {
    if (_configs.length <= 1) return;
    setState(() {
      _configs.removeAt(index);
      if (_activeIndex >= _configs.length) {
        _activeIndex = _configs.length - 1;
      }
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'HUD LAYOUTS',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addConfig,
            tooltip: 'Add layout',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _configs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _ConfigTile(
                config: _configs[i],
                isActive: i == _activeIndex,
                onActivate: () => _setActive(i),
                onEdit: () => _editConfig(i),
                onGridEdit: () => _editGridLayout(i),
                onDelete: _configs.length > 1 ? () => _deleteConfig(i) : null,
              ),
            ),
    );
  }
}

class _ConfigTile extends StatelessWidget {
  final HudConfig config;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onEdit;
  final VoidCallback onGridEdit;
  final VoidCallback? onDelete;

  const _ConfigTile({
    required this.config,
    required this.isActive,
    required this.onActivate,
    required this.onEdit,
    required this.onGridEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return RoundedCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onActivate,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? AppColors.accent : AppColors.textSecondary,
                  width: 2,
                ),
                color: isActive ? AppColors.accent : Colors.transparent,
              ),
              child: isActive
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _metricSummary(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.grid_view_rounded,
              color: config.hasGridLayout
                  ? AppColors.accent
                  : AppColors.textSecondary,
              size: 18,
            ),
            tooltip: 'Grid layout editor',
            onPressed: onGridEdit,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textSecondary, size: 18),
            tooltip: 'Edit metrics list',
            onPressed: onEdit,
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 18),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  String _metricSummary() {
    if (config.hasGridLayout) {
      final names = config.placements.map((p) => p.metric.label).join(' · ');
      return 'Grid layout  ·  $names';
    }
    final all = [...config.primary, ...config.secondary];
    return all.map((m) => m.label).join(' · ');
  }
}

class _EditHudScreen extends StatefulWidget {
  final HudConfig config;

  const _EditHudScreen({required this.config});

  @override
  State<_EditHudScreen> createState() => _EditHudScreenState();
}

class _EditHudScreenState extends State<_EditHudScreen> {
  late String _name;
  late List<HudMetric> _primary;
  late List<HudMetric> _secondary;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _name = widget.config.name;
    _primary = List.from(widget.config.primary);
    _secondary = List.from(widget.config.secondary);
    _nameCtrl = TextEditingController(text: _name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _inPrimary(HudMetric m) => _primary.contains(m);
  bool _inSecondary(HudMetric m) => _secondary.contains(m);

  void _toggle(HudMetric m) {
    setState(() {
      if (_inPrimary(m)) {
        _primary.remove(m);
      } else if (_inSecondary(m)) {
        _secondary.remove(m);
      } else if (_primary.length < 2) {
        _primary.add(m);
      } else if (_secondary.length < 4) {
        _secondary.add(m);
      }
    });
  }

  String _slotLabel(HudMetric m) {
    if (_inPrimary(m)) return 'PRIMARY';
    if (_inSecondary(m)) return 'SECONDARY';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'EDIT LAYOUT',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              final updated = HudConfig(
                name: _nameCtrl.text.trim().isEmpty ? 'Layout' : _nameCtrl.text.trim(),
                primary: _primary,
                secondary: _secondary,
              );
              Navigator.of(context).pop(updated);
            },
            child: const Text(
              'SAVE',
              style: TextStyle(
                  color: AppColors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Layout name',
                labelStyle:
                    const TextStyle(color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF2A2D3E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'TAP TO ADD/REMOVE METRICS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Primary (large): max 2  ·  Secondary (small): max 4',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: HudMetric.values
                  .map((m) => _MetricChip(
                        metric: m,
                        slotLabel: _slotLabel(m),
                        onTap: () => _toggle(m),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final HudMetric metric;
  final String slotLabel;
  final VoidCallback onTap;

  const _MetricChip({
    required this.metric,
    required this.slotLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = slotLabel.isNotEmpty;
    final isPrimary = slotLabel == 'PRIMARY';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.accent.withValues(alpha: 0.2)
              : active
                  ? AppColors.highlight.withValues(alpha: 0.15)
                  : const Color(0xFF181C28),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? AppColors.accent
                : active
                    ? AppColors.highlight
                    : const Color(0xFF2A2D3E),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              metric.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            if (slotLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                slotLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? AppColors.accent : AppColors.highlight,
                  letterSpacing: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
