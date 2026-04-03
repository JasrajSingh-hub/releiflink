class AppConfig {
  AppConfig._();

  // Phase 3 note:
  // - The app is offline-first (local DB + outbox).
  // - To enable real syncing, set a backend URL and run `Sync now`.
  //
  // Example: 'https://example.com/api'
  static const String? remoteBaseUrl = 'http://10.0.2.2:8080/api'; // e.g. 'http://10.0.2.2:8080/api'

  // Auto-sync interval (tuned for low-network/battery friendliness).
  static const Duration autoSyncInterval = Duration(seconds: 30);
}
