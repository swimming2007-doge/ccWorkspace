# RideRecord 🚴

<p align="center">
  <strong>Smart Cycling Tracker - Auto Start/Stop with Motion Detection, Adventure Navigation</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#development">Development</a> •
  <a href="#contributing">Contributing</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-HarmonyOS%20NEXT-blue" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/version-0.1.0-orange" alt="Version">
</p>

---

## Overview

RideRecord is an intelligent cycling data tracking application running on the HarmonyOS ecosystem (Huawei Mate 70 phone + Huawei Watch 3 Pro).

### Key Highlights

- 🎯 **Auto Start/Stop with Motion Detection** - Automatically starts/pauses/stops recording by detecting cycling motions
- 🗺️ **Adventure Navigation Mode** - Supports road/adventure/hybrid navigation modes
- 📊 **Risk Index Alert** - Real-time route risk assessment (terrain, traffic, signal coverage)
- 🔄 **Multi-platform Sync** - Cloud storage, Web access, third-party platform sync

---

## Features

### 🚴 Smart Start/Stop

| Feature | Description |
|---------|-------------|
| Motion Detection | Identify cycling actions via sensor data |
| Auto Start/Stop | Automatically control recording based on detected motion |
| State Machine | IDLE → RIDING → PAUSED → ENDING |

### 📱 Multi-device Collaboration

| Platform | Function |
|----------|----------|
| Phone (HarmonyOS) | Main control center, navigation, data analysis |
| Watch (Watch OS) | Real-time display, motion detection, heart rate |
| Web | Dashboard, history view, route planning |
| Server | Data sync, authentication, third-party integration |

### 🗺️ Navigation System

| Mode | Description |
|------|-------------|
| Road Navigation | Standard road routing with voice guidance |
| Adventure Navigation | Support for dirt roads, village paths, mountain trails |
| Hybrid Navigation | Optimal combination of roads and trails |

### 📊 Data Display

- **Real-time Dashboard**: Speed, distance, time, heart rate, elevation
- **Statistics**: Daily/weekly/monthly/yearly stats, trend analysis
- **Ride Details**: Track map, speed/heart rate/elevation charts
- **Heart Rate Zones**: Z1-Z5 zone distribution visualization

### 🔄 Sync & Share

- **Cloud Sync**: Huawei Cloud OBS storage with resume support
- **WeChat Share**: Share to friends/moments with multiple templates
- **Strava Sync**: OAuth 2.0, automatic ride data sync

### 📥 Offline Maps

- Download map tiles by region
- Storage management
- Auto cleanup policy

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    RideRecord Architecture              │
├─────────────────────────────────────────────────────────┤
│                                                          │
│   ┌─────────────┐    BLE     ┌─────────────┐           │
│   │  Phone App  │◄──────────►│  Watch App  │           │
│   │ (HarmonyOS) │            │ (Watch OS)  │           │
│   │   ArkTS     │            │   ArkTS     │           │
│   └──────┬──────┘            └─────────────┘           │
│          │                                               │
│          │ HTTPS                                         │
│          ▼                                               │
│   ┌─────────────┐    ┌─────────────┐                    │
│   │   Server    │    │    Web      │                    │
│   │  Node.js    │    │  Vue 3 + TS │                    │
│   │   Express   │    │   Vite      │                    │
│   └─────────────┘    └─────────────┘                    │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Tech Stack

| Platform | Language | Framework | Storage |
|----------|----------|-----------|---------|
| Phone | ArkTS | ArkUI | SQLite |
| Watch | ArkTS | ArkUI (Watch) | Preferences |
| Server | TypeScript | Express | SQLite + OBS |
| Web | TypeScript | Vue 3 | - |

---

## Quick Start

### Requirements

- Node.js 20 LTS
- DevEco Studio 5.0+
- HarmonyOS NEXT SDK

### Clone Repository

```bash
git clone https://github.com/your-org/riderecord.git
cd riderecord
```

### Start Server

```bash
cd server
npm install
npm run dev
```

### Start Web App

```bash
cd web
npm install
npm run dev
```

### Phone Development

1. Open `phone` directory in DevEco Studio
2. Configure signing certificate
3. Connect device or emulator
4. Click Run

---

## Project Structure

```
rideRecord/
├── phone/                 # Phone app
│   └── entry/src/main/ets/
│       ├── pages/         # Pages
│       ├── components/    # Components
│       └── services/      # Services
├── watch/                 # Watch app
│   └── entry/src/main/ets/
├── server/                # Server
│   └── src/
│       ├── routes/        # Routes
│       └── services/      # Services
├── web/                   # Web app
│   └── src/
│       ├── views/         # Views
│       └── stores/        # State management
├── shared/                # Shared code
│   ├── types/             # Type definitions
│   └── utils/             # Utilities
└── docs/                  # Documentation
    └── plans/             # Design docs
```

---

## Development

### Code Standards

- Use TypeScript/ArkTS strong typing
- Follow ESLint rules
- Use declarative UI for components
- Use singleton pattern for services

### Commit Convention

```
feat: New feature
fix: Bug fix
docs: Documentation
style: Formatting
refactor: Refactoring
test: Testing
chore: Build/tools
```

### Branch Strategy

- `main` - Main branch
- `develop` - Development branch
- `feature/*` - Feature branches
- `hotfix/*` - Hotfix branches

---

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

### Steps to Contribute

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'feat: add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Create Pull Request

---

## Security

If you discover a security vulnerability, please see [SECURITY.md](SECURITY.md) for reporting instructions.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgments

Thanks to these open source projects:

- [HarmonyOS](https://www.harmonyos.com/)
- [Vue.js](https://vuejs.org/)
- [Express](https://expressjs.com/)
- [TailwindCSS](https://tailwindcss.com/)

---

<p align="center">
  Made with ❤️ by RideRecord Team
</p>
