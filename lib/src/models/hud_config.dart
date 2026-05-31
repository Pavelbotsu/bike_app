import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HudMetric { speed, distance, time, avgSpeed, maxSpeed, elevation }

extension HudMetricLabel on HudMetric {
  String get label {
    switch (this) {
      case HudMetric.speed:     return 'SPEED';
      case HudMetric.distance:  return 'DISTANCE';
      case HudMetric.time:      return 'TIME';
      case HudMetric.avgSpeed:  return 'AVG SPEED';
      case HudMetric.maxSpeed:  return 'MAX SPEED';
      case HudMetric.elevation: return 'ELEVATION';
    }
  }

  String get unit {
    switch (this) {
      case HudMetric.speed:
      case HudMetric.avgSpeed:
      case HudMetric.maxSpeed: return 'km/h';
      case HudMetric.distance: return 'km';
      case HudMetric.time:     return '';
      case HudMetric.elevation: return 'm';
    }
  }
}

class HudConfig {
  final String name;
  final List<HudMetric> primary;    // shown large, max 2
  final List<HudMetric> secondary;  // shown small, max 4

  const HudConfig({
    required this.name,
    required this.primary,
    required this.secondary,
  });

  static const HudConfig defaultConfig = HudConfig(
    name: 'Default',
    primary: [HudMetric.speed],
    secondary: [HudMetric.distance, HudMetric.time],
  );

  static const HudConfig raceConfig = HudConfig(
    name: 'Race',
    primary: [HudMetric.speed, HudMetric.avgSpeed],
    secondary: [HudMetric.distance, HudMetric.time, HudMetric.maxSpeed],
  );

  Map<String, dynamic> toJson() => {
        'name': name,
        'primary': primary.map((m) => m.name).toList(),
        'secondary': secondary.map((m) => m.name).toList(),
      };

  factory HudConfig.fromJson(Map<String, dynamic> json) => HudConfig(
        name: json['name'] as String,
        primary: (json['primary'] as List<dynamic>)
            .map((s) => HudMetric.values.byName(s as String))
            .toList(),
        secondary: (json['secondary'] as List<dynamic>)
            .map((s) => HudMetric.values.byName(s as String))
            .toList(),
      );

  HudConfig copyWith({
    String? name,
    List<HudMetric>? primary,
    List<HudMetric>? secondary,
  }) =>
      HudConfig(
        name: name ?? this.name,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
      );
}

class HudConfigService extends ChangeNotifier {
  static final HudConfigService instance = HudConfigService._();
  HudConfigService._();

  static const _key = 'hud_configs';
  static const _activeKey = 'hud_active';

  Future<List<HudConfig>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);
    if (raw == null || raw.isEmpty) {
      return [HudConfig.defaultConfig, HudConfig.raceConfig];
    }
    return raw
        .map((s) => HudConfig.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<HudConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      configs.map((c) => jsonEncode(c.toJson())).toList(),
    );
    notifyListeners();
  }

  Future<int> getActiveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeKey) ?? 0;
  }

  Future<void> setActiveIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeKey, index);
    notifyListeners();
  }

  Future<HudConfig> getActive() async {
    final configs = await loadAll();
    final idx = await getActiveIndex();
    return configs[idx.clamp(0, configs.length - 1)];
  }
}
