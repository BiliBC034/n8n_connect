# How to contribute to n8n Connect

Thanks for your interest! This guide explains how to set up the environment, which commands to use and what we expect from changes.

## Requirements

- **Flutter 3.35** (stable channel) with **Dart 3.9**.
- **Android SDK** (the app is Android-only for now).

## Setup

1. Clone the repository and enter the folder.
2. Configure Firebase with one of these options:
   - **Quick option (without a real Firebase project)**: copy the example files:
     - `lib/firebase_options.example.dart` → `lib/firebase_options.dart`
     - `lib/firebase_web_client.example.dart` → `lib/firebase_web_client.dart`
     - `android/app/google-services.example.json` → `android/app/google-services.json`: this is **required** to build, because the `com.google.gms.google-services` plugin needs it. With example values the app builds, but sign-in does not work.
   - **Full option**: run `flutterfire configure` with your own Firebase project. This generates `lib/firebase_options.dart`. Also copy `lib/firebase_web_client.example.dart` to `lib/firebase_web_client.dart` and fill it in for Google Sign-In.
3. For real sign-in, place your project's `google-services.json` in `android/app/`. Before downloading it, register the SHA-1 fingerprint of your signing key in the Firebase Android app (for debug: `cd android && ./gradlew signingReport`). This is required for Google Sign-In.
4. Install the dependencies: `flutter pub get`.

The real Firebase files are listed in `.gitignore`: never commit them to the repository.

## Common commands

```bash
flutter pub get        # Install dependencies
flutter analyze        # Static analysis (there must be no warnings)
flutter test           # Tests
flutter build apk      # Build the Android APK
```

## Code style

- Format with `dart format` before submitting changes.
- `flutter analyze` must not show any warnings.
- Code comments are written in **English**.
- Documentation and commit messages are written in **English**. App UI strings are kept in both `lib/l10n/intl_en.arb` and `lib/l10n/intl_es.arb`.

## Commits

Use the format `<type>: <description>`, with a short description in English:

| Type | Use |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `perf` | Performance improvement |
| `refactor` | Internal change without changing behavior |
| `docs` | Documentation |
| `test` | Tests |
| `chore` | Maintenance (dependencies, configuration, etc.) |

Example: `fix: alarm is not scheduled if the time has already passed`.

## Protocol changes

If you change the protocol between the app and n8n:

- Update [`docs/PROTOCOL.md`](docs/PROTOCOL.md) in the same change.
- If the change breaks compatibility, increase `AppConfig.protocolVersion` and/or `AppConfig.specSchemaVersion` (in `lib/core/app_config.dart`) and explain it in the pull request description.

## Secrets and personal data

**Never commit secrets or personal data**: API keys, tokens, `google-services.json`, signing keys (`*.jks`, `*.keystore`, `android/key.properties`), email addresses, IP addresses, or real n8n workflow or credential IDs. Always use example data in code, tests and documentation.

## Publishing a release

Versions are published as GitHub releases with the signed APK. Follow [docs/RELEASING.md](docs/RELEASING.md) and update `CHANGELOG.md` and the version in `pubspec.yaml` in the same change. The guide covers:

- Automatic releases: [section f](docs/RELEASING.md#f-publishing-a-release-automatic).
- Manual releases: [section g](docs/RELEASING.md#g-publishing-manually).
- Tester builds with Firebase App Distribution: [section h](docs/RELEASING.md#h-distributing-to-testers-firebase-app-distribution).

## Pull requests

Fill in the pull request template and make sure `flutter analyze` and `flutter test` pass before requesting a review.
