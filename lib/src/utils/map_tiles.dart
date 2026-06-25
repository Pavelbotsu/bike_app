import 'package:shared_preferences/shared_preferences.dart';

const _kMapStyleKey = 'prefs_map_style';

enum MapStyle { standard, cycling, satellite }

String mapTileUrl(MapStyle style) => switch (style) {
      MapStyle.standard =>
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      MapStyle.cycling =>
        'https://tile.waymarkedtrails.org/cycling/{z}/{x}/{y}.png',
      MapStyle.satellite =>
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    };

String mapStyleLabel(MapStyle style) => switch (style) {
      MapStyle.standard => 'Standard',
      MapStyle.cycling => 'Cycling',
      MapStyle.satellite => 'Satellite',
    };

Future<MapStyle> loadMapStyle() async {
  final prefs = await SharedPreferences.getInstance();
  final idx = prefs.getInt(_kMapStyleKey) ?? 0;
  return MapStyle.values[idx.clamp(0, MapStyle.values.length - 1)];
}

Future<void> saveMapStyle(MapStyle style) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_kMapStyleKey, style.index);
}
