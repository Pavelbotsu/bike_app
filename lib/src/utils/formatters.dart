/// Centralised number / duration formatting for the whole app.
///
/// Goal: clean, human-readable values everywhere — never raw 6-decimal
/// doubles. Speed shows up to 2 decimals, elevation up to 1 decimal, and
/// trailing zeros are trimmed so `24.50` reads as `24.5` and `24.00` as `24`.
library;

/// Trims trailing zeros (and a dangling decimal point) from a fixed string.
/// `"24.50" -> "24.5"`, `"24.00" -> "24"`, `"0.05" -> "0.05"`.
String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceFirst(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

/// Speed in km/h, up to 2 decimals, trailing zeros trimmed.
String fmtSpeed(double kmh) {
  if (kmh.isNaN || kmh.isInfinite || kmh < 0) return '0';
  return _trimZeros(kmh.toStringAsFixed(2));
}

/// Elevation / altitude in metres, up to 1 decimal, trailing zero trimmed.
String fmtElevation(double m) {
  if (m.isNaN || m.isInfinite) return '0';
  return _trimZeros(m.toStringAsFixed(1));
}

/// Distance in km, always 2 decimals (e.g. `12.40 km`).
String fmtDistance(double km) {
  if (km.isNaN || km.isInfinite || km < 0) return '0.00';
  return km.toStringAsFixed(2);
}

/// Grade as a signed percentage with 1 decimal (e.g. `+6.2%`, `-3.0%`).
String fmtGrade(double pct) {
  if (pct.isNaN || pct.isInfinite) return '0%';
  final sign = pct > 0 ? '+' : '';
  return '$sign${pct.toStringAsFixed(1)}%';
}

/// Duration as `h:mm:ss` when there are hours, otherwise `mm:ss`.
String fmtDuration(Duration d) {
  final h = d.inHours;
  final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
