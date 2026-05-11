# Modus — Dynamic Productivity Engine

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?style=flat-square&logo=flutter)
![Dart](https://img.shields.io/badge/Dart-81%25-0175C2?style=flat-square&logo=dart)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Web-lightgrey?style=flat-square)
![License](https://img.shields.io/badge/License-Personal%20%2F%20Educational-green?style=flat-square)
![Release](https://img.shields.io/badge/Release-v1.0.0-brightgreen?style=flat-square)

> A minimalist, real-time productivity engine built for deep work. Design your routines as flowcharts, sync with your study group over LAN, and stay in the zone with a UI that gets out of your way.

---

## Overview

Modus is a Flutter application that rethinks what a productivity timer can be. Rather than a rigid list of tasks, it lets you model your work sessions as **node-based flowcharts** — complete with branching decisions, loop-back paths, and timed phases. Pair that with real-time LAN multiplayer, precision analytics, and a highly customisable visual language, and you have a tool built for focused, iterative work.

---

## Features

### Visual Flow Engine
Build routines as node-based flowcharts rather than static lists. Use **Decision Nodes** for conditional branching, **Jump Nodes** for loops and re-entry paths, and shape each session around how you actually think and work. The timer is tightly integrated with the flow engine — active nodes reflect live progress in real time.

### Modus Connect — LAN Multiplayer
Study with others without relying on any external infrastructure.
- **Zero-latency sync** via a custom WebSocket server for 1-to-many device synchronisation over a local network.
- **Real-time chat** built into the study room, no third-party dependencies.
- **Haptic nudging** — send and receive physical nudges and audio pings to keep your group on track.

### Task & Routine Management
- Save, load, overwrite, and delete routine templates from within the app.
- **CSV import/export** — design your study plans in Excel or Google Sheets and bring them straight in.
- Automatic Pomodoro-style phase transitions with global auto-start overrides.

### Analytics & Data Portability
- Focus time tracked to the second.
- Export your full study history to CSV for external analysis or personal records.

### Design & Customisation
- **Ayu Dark & OLED Pure Black** modes for maximum contrast and AMOLED battery efficiency.
- **Dynamic accent colours** — choose from a curated set of premium and pastel accents that tint the entire UI.
- **Nothing OS typography** — optional dot-matrix font style for a sleek, minimalist display.
- **Anti-Material UI** — translucent surfaces, subtle borders, soft glow active states, and a glassy visual language instead of generic card-based layouts.
- **Responsive architecture** — a single codebase that shifts from a compact mobile layout into a two-column desktop Command Centre.

### Physical Feedback
Haptic feedback throughout the app for tactile wheel scrubbing, completion events, and key interactions, giving the UI a grounded, physical feel.

---

## Tech Stack

| Area | Technology |
|---|---|
| Framework | Flutter 3.x |
| State Management | Provider (ChangeNotifier) |
| Networking | `dart:io` WebSockets & HttpServer |
| Storage | `shared_preferences` with JSON serialisation |
| Audio | `audioplayers` |

---

## Installation

### Prerequisites
- [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install)
- Dart SDK (bundled with Flutter)

### Clone & Run

```bash
git clone https://github.com/SamuelSmthSmth/modus.git
cd modus
flutter pub get
```

**Android**
```bash
flutter run
```

**Linux Desktop**
```bash
flutter run -d linux
```

**Windows Desktop**
```bash
flutter run -d windows
```

**macOS**
```bash
flutter run -d macos
```

**Web**
```bash
flutter run -d chrome
```

---

## Project Structure

```
modus/
├── lib/               # Dart source — flows, timer, state, UI
├── assets/            # Fonts, audio, and static assets
├── android/           # Android platform config
├── ios/               # iOS platform config
├── linux/             # Linux desktop platform config
├── windows/           # Windows desktop platform config
├── macos/             # macOS platform config
├── web/               # Web platform config
└── pubspec.yaml       # Dependencies and asset declarations
```

---

## Notes for Developers

- State is managed through `Provider`-backed `ChangeNotifier` objects. The flow engine, timer, and UI layer are each independently stateful and communicate through shared notifiers.
- Routine templates and timer settings are persisted locally with `shared_preferences` using JSON serialisation.
- The WebSocket server for Modus Connect is spun up directly from `dart:io` — no backend service required.
- The UI is designed to scale from mobile to desktop while keeping the flow editor as the primary interaction surface.

---

## Roadmap

- [ ] Cloud sync for routines and history
- [ ] Global (internet) multiplayer via relay server
- [ ] Plugin system for custom node types
- [ ] Theme import/export

---

## License

Personal use / Educational. Built for focused work sessions and iterative productivity workflows.