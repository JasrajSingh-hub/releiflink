import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'outbox_service.dart';
import 'remote_sync_service.dart';
import 'request_service.dart';

class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance = SyncService._();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _online = true;
  bool _syncing = false;
  String? _status;

  bool get online => _online;
  bool get syncing => _syncing;
  String? get status => _status;

  Future<void> start() async {
    final initial = await _connectivity.checkConnectivity();
    _setOnline(_isOnline(initial));

    await _sub?.cancel();
    _sub = _connectivity.onConnectivityChanged.listen((results) async {
      final nowOnline = _isOnline(results);
      final becameOnline = !_online && nowOnline;
      _setOnline(nowOnline);
      if (becameOnline) {
        await syncNow();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> syncNow({bool force = false}) async {
    if (_syncing) return;
    if (!_online) {
      _status = 'Offline (sync paused)';
      notifyListeners();
      return;
    }

    if (!RemoteSyncService.instance.enabled) {
      _status = 'Sync not configured (local only)';
      notifyListeners();
      return;
    }

    _syncing = true;
    _status = 'Syncing...';
    notifyListeners();

    try {
      final ok = await RemoteSyncService.instance.checkHealth();
      if (!ok) {
        _status = 'Backend unreachable';
        return;
      }

      final pending = OutboxService.instance.getPending();
      if (pending.isEmpty) {
        final remote = await RemoteSyncService.instance.fetchAllRequests();
        await RequestService.instance.applyRemoteRequests(remote);
        _status = 'Up to date';
        return;
      }

      var sent = 0;
      for (final item in pending) {
        final retryAt = item.nextRetryAt;
        if (!force && retryAt != null && DateTime.now().isBefore(retryAt)) {
          continue;
        }
        try {
          await RemoteSyncService.instance.send(item);
          await OutboxService.instance.remove(item.id);
          sent += 1;
        } catch (e) {
          await OutboxService.instance.markFailed(item.id, e);
          if (e is SocketException || e is TimeoutException) {
            // Fail fast: avoid waiting N * timeout when backend is unreachable.
            _status = 'Backend unreachable';
            break;
          }
        }
      }

      final remote = await RemoteSyncService.instance.fetchAllRequests();
      await RequestService.instance.applyRemoteRequests(remote);

      _status = sent == 0 ? 'Synced (0 sent)' : 'Synced ($sent sent)';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  void _setOnline(bool value) {
    if (_online == value) return;
    _online = value;
    notifyListeners();
  }
}
