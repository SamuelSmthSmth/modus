# Modus
**A Minimalist, Real-Time Multiplayer Study Engine.**

A nice, aesthetic productivity timer I developed for a lot of platforms. It's made more to be out of the way to let you focus on studying

![GitHub last commit](https://img.shields.io/github/last-commit/SamuelSmthSmthSmth/modus?color=B8CC52&style=flat-square)
![Flutter Version](https://img.shields.io/badge/Flutter-v3.x-blue?style=flat-square&logo=flutter)

---

## Key Features

### Modus Connect (LAN Multiplayer)
- **Zero-Latency Sync:** Custom WebSocket server allows 1-to-many device synchronization over local networks.
- **Real-Time Chat:** Integrated study-room chat with no external server dependencies.
- **Haptic Nudging:** Send and receive physical nudges and audio pings to keep your study group focused.

### Design & Customization
- **Ayu Dark & OLED Modes:** Native support for the Ayu Dark palette and a "Pure Black" mode for AMOLED power savings.
- **Dynamic Accents:** Choose from a curated list of premium and pastel accent colors.
- **Nothing UI Typography:** Supports "Nothing OS" style dot-matrix fonts and sleek minimalist displays.
- **Responsive Architecture:** A single codebase that transforms from a mobile app into a two-column Desktop "Command Center."

### Task & Routine Management
- **Routine Templates:** Save, load, and manage complex study routines as reusable templates.
- **CSV Import/Export:** Build your study plans in Excel/Google Sheets and import them directly into the app.
- **Pomodoro Progression:** Automatic phase transitions with global auto-start overrides.

### Analytics
- **Precision Tracking:** Focus time tracked down to the second.
- **Data Portability:** Export your entire study history to CSV for external analysis.

---

## Tech Stack
- **Framework:** Flutter
- **State Management:** Provider (ChangeNotifier Architecture)
- **Networking:** `dart:io` WebSockets & HttpServers
- **Storage:** `shared_preferences` with JSON serialization
- **Audio:** `audioplayers`

---

## How to Run
1. **Clone the repo:**
   ```bash
   git clone https://github.com/SamuelSmthSmthSmth/modus.git
   cd modus
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   # For Android
   flutter run

   # For Linux Desktop
   flutter run -d linux
   ```

---

## 📜 License
Personal use / Educational. Built with ❤️ for the ultimate study grind.