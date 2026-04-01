class AppConfig {
  AppConfig._();

  // Phase 3 note:
  // - The app is offline-first (local DB + outbox).
  // - To enable real syncing, set a backend URL and run `Sync now`.
  //
  // Example: 'https://example.com/api'
  static const String? remoteBaseUrl = null; // e.g. 'http://10.0.2.2:8080/api'
}
