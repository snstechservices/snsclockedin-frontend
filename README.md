# SNS Clocked In v2 - Frontend

Employee time tracking and management system built with Flutter.

## Project Structure

This project follows a feature-first architecture with clean separation of concerns:

```
lib/
├── app/                        # Application-level configuration
│   ├── app.dart               # Main app widget with routing & theming
│   ├── router/                # Navigation configuration
│   │   └── app_router.dart    # GoRouter setup
│   └── theme/                 # App theming
│       └── theme_config.dart  # Theme definitions
├── core/                       # Core utilities & shared code
│   ├── config/                # Configuration
│   │   └── env.dart           # Environment variables wrapper
│   └── network/               # Network layer
│       └── api_client.dart    # Dio HTTP client
├── features/                   # Feature modules (feature-first)
│   ├── auth/                  # Authentication feature
│   │   └── presentation/
│   │       └── login_screen.dart
│   ├── home/                  # Home feature
│   │   └── presentation/
│   │       └── home_screen.dart
│   └── splash/                # Splash screen
│       └── presentation/
│           └── splash_screen.dart
└── main.dart                   # App entry point
```

### Folder Organization

- **app/**: App-wide configuration (routing, theming)
- **core/**: Shared utilities, constants, network clients, etc.
- **features/**: Feature modules organized by domain
  - Each feature can have: `data/`, `domain/`, `presentation/` layers
  - Keep features isolated and reusable

## Getting Started

### Prerequisites

- Flutter SDK (stable channel)
- Dart SDK 3.0.0 or higher
- Android Studio / Xcode / VS Code

### Setup

1. Clone the repository
2. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```
3. Update `.env` with your configuration
4. Install dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

```bash
# Run on connected device/emulator
flutter run

# Run on specific device
flutter run -d <device_id>

# Run on Chrome (web)
flutter run -d chrome

# Run on Android emulator
flutter run -d android

# Run on iOS simulator
flutter run -d ios
```

### Build

```bash
# Build APK (Android)
flutter build apk --release

# Build App Bundle (Android)
flutter build appbundle --release

# Build iOS
flutter build ios --release

# Build Web
flutter build web --release
```

## Tech Stack

- **Framework**: Flutter (stable)
- **State Management**: Provider
- **Routing**: go_router
- **HTTP Client**: Dio
- **Environment Config**: flutter_dotenv
- **Linting**: very_good_analysis

## Development Guidelines

### Code Style

- Follow the lint rules defined in `analysis_options.yaml`
- Run `flutter analyze` before committing
- Format code with `dart format .`

### Environment Variables

Environment-specific configuration is managed via `.env` files:

- `APP_ENV`: development | staging | production
- `API_BASE_URL`: Backend API base URL

**Important**: Never commit `.env` files. Only `.env.example` should be in version control.

## Current Status

**Step 1 Complete**: Foundation setup with:
- Clean feature-first folder structure
- Router setup with splash, login, and home screens
- Theme configuration scaffolding
- API client scaffolding with Dio
- Environment configuration

**Step 2 Complete**: Provider-based session/app state and router guards:
- AppState with bootstrap and authentication management
- Router guards for automatic navigation
- API client token provider integration
- Correlation ID generation per request
- Mock authentication flow

## Migration Documentation

See [MIGRATION_STEPS.md](./MIGRATION_STEPS.md) for detailed documentation of all migration steps, including:
- Files created/modified
- Implementation details
- Linting issues and fixes
- Architecture decisions
- Verification steps

## Next Steps (Step 3+)

- [ ] Real authentication API integration
- [ ] Add time tracking features
- [ ] Integrate with backend API
- [ ] Add offline sync capability
- [ ] Migrate features from old codebase
- [ ] Add Firebase integration (if needed)
- [ ] Implement local database (Hive/Drift) (if needed)

## License

Proprietary - SNS Clocked In
