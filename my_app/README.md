# my_app

A disaster-response coordination Flutter app (work-in-progress).

## Product Scope

- Feature breakdown: `docs/feature-breakdown.md`

## Offline-First (Phase 3)

- Requests are persisted locally (Hive) so they survive app restarts.
- Changes are also written to a local outbox (sync queue).
- Remote sync is optional and disabled by default; configure it in `lib/config/app_config.dart`.

## Local Backend (Node.js) for Sync

If you have Node.js, you can run a tiny local backend included in this repo.

1) Start the backend:

- In `releiflink/backend` run: `node server.js`

2) Point the app to the backend:

- Edit `releiflink/my_app/lib/config/app_config.dart` and set `remoteBaseUrl`.
  - Android emulator: `http://10.0.2.2:8080/api`
  - iOS simulator: `http://localhost:8080/api`
  - Real phone (same Wi-Fi): `http://<YOUR_LAPTOP_LAN_IP>:8080/api`

3) In the app, tap the `Sync` icon in the top bar.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
