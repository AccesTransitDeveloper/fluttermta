# Agent Instructions

## Project Snapshot

- Flutter app for the Driver experience. The app entry point is [lib/main.dart](lib/main.dart).
- Native behavior is split across Android and iOS bridges in [android/app/src/main/kotlin/com/app/driver/MainActivity.kt](android/app/src/main/kotlin/com/app/driver/MainActivity.kt) and [ios/Runner/AppDelegate.swift](ios/Runner/AppDelegate.swift).
- MTA work depends on a build-time define. See [README.md](README.md) for the required `MTA_API_BASE_URL` contract and example commands.

## Work Rules

- Keep changes focused on the requested slice; avoid broad refactors unless they are required.
- Do not edit generated or build output under `build/` unless a task explicitly requires it.
- Prefer existing patterns in `lib/core`, `lib/data`, `lib/features`, `lib/models`, and `lib/viewmodels` when adding new code.
- Treat platform-channel and Firebase changes as cross-platform work: update the matching Dart and native side together.

## Useful Commands

- Run app: `flutter run --dart-define="MTA_API_BASE_URL=..."`
- Build Android: `flutter build appbundle --dart-define="MTA_API_BASE_URL=..."`
- Analyze: `flutter analyze`
- Test: `flutter test`

## Project Pitfalls

- `MTA_API_BASE_URL` must be a valid HTTP(S) URL and should point at the deployment-specific `/api/mta/driver-app` base path.
- `lib/main.dart` initializes Firebase, notifications, Riverpod, and session handling at startup, so widget tests around app boot often need extra setup or mocking.
- The default smoke test in [test/widget_test.dart](test/widget_test.dart) is not representative of the real app flow; prefer targeted tests in `test/` for the slice you changed.

## When In Doubt

- Check [README.md](README.md) before changing configuration-sensitive behavior.
- If you touch MTA, documents, notifications, or native integrations, look for an existing nearby test or call site before adding new abstractions.