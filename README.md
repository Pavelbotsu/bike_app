# Velocity

> A minimal, battery-smart cycling tracker — built by a rider, for riders.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue) ![Dart](https://img.shields.io/badge/Dart-3.9-blue) ![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green) ![License](https://img.shields.io/badge/License-GPL--3.0-lightgrey)

---

## Why Not Just Use Strava?

Strava is great — until it isn't. After using it for a while, a few things kept bothering me:

- **Cluttered UI** — too many features fighting for your attention when all you want is your speed and distance
- **Social pressure** — everything defaults to public, the feed is front and center, it feels more like Instagram than a ride tracker
- **Battery drain** — same GPS update rate whether you're stopped at a light or doing 40 km/h
- **No smart tracking** — it doesn't adapt to how fast you're actually moving

Velocity fixes these. Clean dark UI, no social feed to opt out of, and a GPS engine that actually adjusts to your ride.

---

## Features

### Live Ride Tracking

- Real-time speed, distance, elevation, and a customizable HUD grid
- Adaptive GPS: auto-switches to high-speed mode (500ms updates) above 20 km/h, backs off below 15 km/h
- Runs through a native Android foreground service so tracking survives the screen being off or the app backgrounded
- Crash/kill recovery — an interrupted ride can be resumed on next launch

### Smart Battery Management

- 3-tier GPS mode: Economy → Performance → High Speed
- Hysteresis-based auto-switching — no unnecessary toggling at the threshold

### Post-Ride Summary

- Interactive route map with speed-heatmap, elevation-gradient, and plain route views
- Elevation profile and speed-over-time charts
- Distance, duration, average/max speed, elevation gain, estimated calories
- Climb analysis (elevation gain/loss, max grade), lap splits, editable notes and ride name
- Export to GPX/TCX or share as an image

### History

- Full activity history, grouped by day/week/month, with search
- Weekly and all-time summary stats

### Profile

- Lifetime stats: total distance, elevation, ride count
- Recent activity at a glance

### Social Feed — *concept only, not implemented*

An opt-in activity feed was part of the original design (see `lib/design/`) but has not been built. If it ships, sharing will be a choice, not the default — never a public-by-default feed.

---

## Tech Stack

| Layer | Technology |
| --- | --- |
| Framework | Flutter (Dart ^3.9.0) |
| Location | geolocator ^14.0.2 + native Android foreground service |
| Maps | flutter_map ^7.0.2 (OpenStreetMap tiles) |
| Charts | fl_chart ^0.70.2 |
| Storage | sqflite ^2.3.3, shared_preferences ^2.3.2 |
| UI | Custom dark theme, Material 3 |
| Platforms | Android, iOS |

State management is intentionally plain `StatefulWidget` + `setState` — no Provider/Riverpod/Bloc. Velocity stays simple on purpose.

---

## Getting Started

```bash
git clone https://github.com/Pavelbotsu/bike_app.git
cd bike_app
flutter pub get
flutter run
```

Location permissions are required on the device. The app will prompt on first launch.

---

## Project Structure

```text
lib/
├── main.dart
└── src/
    ├── app.dart                      # Root widget, bottom-nav scaffold, navigation
    ├── models/
    │   ├── ride.dart                 # Ride + LapSplit, computed stats (distance, grade, elevation…)
    │   ├── gps_point.dart
    │   └── hud_config.dart
    ├── screens/
    │   ├── home_screen.dart
    │   ├── history_screen.dart
    │   ├── live_ride_screen.dart     # Active ride recording UI
    │   ├── post_ride_screen.dart     # Ride summary, charts, export
    │   ├── profile_screen.dart
    │   ├── settings_screen.dart
    │   ├── hud_settings_screen.dart
    │   ├── hud_grid_editor_screen.dart
    │   └── share_card_screen.dart
    ├── services/
    │   ├── location_service.dart     # Adaptive GPS tracking
    │   ├── ride_tracking_service.dart
    │   ├── active_ride_store.dart    # Crash-recovery snapshotting
    │   ├── database_service.dart     # sqflite persistence
    │   ├── ride_history_service.dart
    │   ├── records_service.dart      # Personal bests
    │   └── export_service.dart       # GPX/TCX export
    ├── theme/
    │   └── app_theme.dart
    ├── utils/
    │   ├── formatters.dart
    │   ├── map_tiles.dart
    │   └── path_interpolation.dart
    └── widgets/
        ├── bottom_nav_bar.dart
        ├── rounded_card.dart
        └── stat_tile.dart
```

---

## Roadmap

### Done

- [x] Ride recording and save to history
- [x] Post-ride summary screen
- [x] Adaptive GPS with battery-aware modes
- [x] HUD customization

### In progress

- [ ] Deeper single-ride insights — grade histogram + effort score
- [ ] Trends over time — weekly volume chart + streak
- [ ] Achievements/badges
- [ ] Route creation (CRUD) — draw and save routes on the map
- [ ] Route live overlay — follow a saved route during a ride
- [ ] Route-based comparisons — personal bests per route

### Not started

- [ ] Social interactions (opt-in)
- [ ] Offline map support

---

## License

Velocity is free software, licensed under the [GNU General Public License v3.0](LICENSE) or later.
