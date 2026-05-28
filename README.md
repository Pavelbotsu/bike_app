# Velocity

> A minimal, battery-smart cycling tracker — built by a rider, for riders.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue) ![Dart](https://img.shields.io/badge/Dart-3.9-blue) ![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green)

---

## Why Not Just Use Strava?

Strava is great — until it isn't. After using it for a while, a few things kept bothering me:

- **Cluttered UI** — too many features fighting for your attention when all you want is your speed and distance
- **Social pressure** — everything defaults to public, the feed is front and center, it feels more like Instagram than a ride tracker
- **Battery drain** — same GPS update rate whether you're stopped at a light or doing 40 km/h
- **No smart tracking** — it doesn't adapt to how fast you're actually moving

Velocity fixes these. Clean dark UI, social as an opt-in, and a GPS engine that actually adjusts to your ride.

---

## Features

### Live Ride Tracking

- Real-time speed, distance, elevation, and calories
- Adaptive GPS: auto-switches to high-speed mode (500ms updates) above 20 km/h, backs off below 15 km/h

### Smart Battery Management

- 3-tier GPS mode: Economy (5s) → Performance (1s) → High Speed (500ms)
- Hysteresis-based auto-switching — no unnecessary toggling at the threshold

### Home Dashboard

- Daily goal progress with distance and time
- Recent rides at a glance
- Curated route exploration

### Social Feed (opt-in)

- Community leaderboard
- Activity feed showing rides from people you follow
- Sharing is a choice, not the default

### Profile & Achievements

- Lifetime stats: total distance, elevation, ride count
- Achievement badges and goal tracking
- Full activity history

---

## Tech Stack

| Layer | Technology |
| --- | --- |
| Framework | Flutter (Dart ^3.9.0) |
| Location | geolocator ^14.0.2 |
| UI | Custom dark theme, Material 3 |
| Platforms | Android, iOS |

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
    ├── app.dart                    # Root widget and navigation
    ├── screens/
    │   ├── home_screen.dart
    │   ├── live_ride_screen.dart
    │   ├── feed_screen.dart
    │   └── profile_screen.dart
    ├── services/
    │   └── location_service.dart   # Adaptive GPS tracking
    ├── theme/
    │   └── app_theme.dart
    └── widgets/
        ├── bottom_nav_bar.dart
        ├── rounded_card.dart
        └── stat_tile.dart
```

---

## Roadmap

- [ ] Ride recording and save to history
- [ ] Post-ride summary screen
- [ ] Route navigation
- [ ] Social interactions (likes, comments)
- [ ] Offline support
