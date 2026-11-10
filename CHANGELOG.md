# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Each version is published as a GitHub release; the process is described in [docs/RELEASING.md](docs/RELEASING.md).

## [Unreleased]

### Added

- **Firebase App Distribution** for tester builds, from a manual run of the "Release" workflow or with `tools/distribute.sh`. Optional secret: `FIREBASE_APP_DISTRIBUTION_SA_BASE64`.
- **n8n admin app** example (`n8n/workflows/app-n8n.json`): panel, workflows, executions, errors, credentials and security audit of the n8n server, with confirmed operations (publish, run, retry, stop, delete), and its **error alerts** workflow (`app-n8n-alerts.json`), which sends a push to the admins for each new failed execution (or one summary when several fail at once).

### Changed

- Documentation, templates (workflow and node names, example app texts), scripts and CI translated to English.

## [1.0.0] - 2026-11-08

First public release.

> **Author's Firebase:** the published APK is built with the author's Firebase project and only connects to n8n servers configured with that same project (with another project, the app rejects the connection with `wrong_firebase_project`). For your own server, build the app with your own Firebase (see the [README](https://github.com/BiliBC034/n8n_connect#getting-started)).

> **Requirements:** Android 7.0 or later (minSdk 24).

### Added

- **Apps defined in n8n**: each app is a JSON spec that the app draws on the phone, with 24 component types (texts, forms, selectors, sliders, cards, lists, tables, grids, indicators, permissions and automations) and 28 actions (screen, device and automatic).
- **Secure session**: sign in with Firebase (email and password with verification, or Google). The app exchanges the Firebase token for a 12-hour JWT session issued by your n8n server, and renews it automatically.
- **Connection to n8n**: server URL (HTTPS only) and a check that the server is an n8n Connect server.
- **App catalog** on the home screen, with `{{key}}` templates and raw values.
- **Push with actions**: n8n notifications that ask for confirmation or, if you enable it, run without asking. Inbox with the push history and a button to run them again.
- **Live dashboards**: apps with `refreshSeconds` reload automatically while on screen.
- **Offline mode**: without network, the catalog and apps show the last saved copy.
- **Per-app automation permission**: each app can run its automatic actions without asking; the permission is revoked in Settings.
- **Dedicated n8n alarms**: they ring with the app closed, survive reboots and can be snoozed for 5 minutes.
- **Phone data for n8n**: location and time zone, only with permission.
- **Permissions from apps**: a component to view and request location or notification permissions.
- **Sharing with n8n**: send text or links from any app to n8n, with an optional note.
- **First-run tutorial**, which can be replayed from Settings.
- **Spanish or English language**, and light or dark theme.
- **Importable n8n templates**: Core, Send to phone, App access, Share and the example app Tools.
