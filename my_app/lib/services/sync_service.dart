import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/local_store.dart';
import 'conflict_service.dart';
import 'outbox_service.dart';
import 'remote_sync_service.dart';
import 'request_service.dart';
import '../models/outbox_item.dart';

class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance = SyncService._();

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  StreamSubscription? _outboxSub;
  Timer? _autoTimer;
  Timer? _outboxDebounce;

  bool _online = true;
  bool _syncing = false;
  String? _status;
  DateTime? _globalRetryAt;
  int _globalFailures = 0;

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

    _startOutboxAutoSync();
    startAutoSync(interval: AppConfig.autoSyncInterval);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _outboxSub?.cancel();
    _autoTimer?.cancel();
    _outboxDebounce?.cancel();
    super.dispose();
  }

  void startAutoSync({Duration interval = const Duration(seconds: 30)}) {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(interval, (_) async {
      if (!RemoteSyncService.instance.enabled) return;
      if (!_online) return;
      await syncNow();
    });
  }

  void _startOutboxAutoSync() {
    _outboxSub?.cancel();
    _outboxSub = LocalStore.outboxBox().watch().listen((_) {
      // When something is enqueued (create/update/status), push it quickly.
      _outboxDebounce?.cancel();
      _outboxDebounce = Timer(const Duration(milliseconds: 300), () async {
        if (!RemoteSyncService.instance.enabled) return;
        if (!_online) return;
        await syncNow();
      });
    });
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

    final retryAt = _globalRetryAt;
    if (!force && retryAt != null && DateTime.now().isBefore(retryAt)) {
      _status = 'Backing off (next retry at ${_hhmm(retryAt)})';
      notifyListeners();
      return;
    }

    _syncing = true;
    _status = 'Syncing...';
    notifyListeners();

    try {
      final ok = await RemoteSyncService.instance.checkHealth();
      if (!ok) {
        _noteGlobalFailure();
        _status = 'Backend unreachable (backing off)';
        return;
      }
      _resetGlobalFailures();

      final pending = OutboxService.instance.getPending();
      if (pending.isEmpty) {
        final remote = await RemoteSyncService.instance.fetchAllRequests();
        await RequestService.instance.applyRemoteRequests(remote);
        _status = 'Up to date';
        return;
      }

      final conflicts = <_SyncConflictDraft>[];
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
        } on SyncConflictException catch (e) {
          final local = RequestService.instance.getById(item.requestId)?.toJson() ?? item.payload;
          conflicts.add(
            _SyncConflictDraft(
              requestId: item.requestId,
              action: item.action,
              local: local,
              message: 'Server rejected this change (${e.statusCode}).',
            ),
          );
          await OutboxService.instance.remove(item.id);
        } catch (e) {
          await OutboxService.instance.markFailed(item.id, e);
          if (e is SocketException || e is TimeoutException) {
            // Fail fast: avoid waiting N * timeout when backend is unreachable.
            _noteGlobalFailure();
            _status = 'Backend unreachable';
            break;
          }
        }
      }

      final remote = await RemoteSyncService.instance.fetchAllRequests();
      await RequestService.instance.applyRemoteRequests(remote);

      if (conflicts.isNotEmpty) {
        for (final c in conflicts) {
          final remoteMatch = remote.cast<Map>().whereType<Map<String, Object?>>().firstWhere(
                (m) => (m['id'] as String?) == c.requestId,
                orElse: () => const {},
              );
          await ConflictService.instance.add(
            requestId: c.requestId,
            action: c.action,
            local: c.local,
            remote: remoteMatch.isEmpty ? null : remoteMatch,
            message: c.message,
          );
        }
      }

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

  void _noteGlobalFailure() {
    _globalFailures += 1;
    final capped = _globalFailures.clamp(1, 8);
    final seconds = (1 << capped) * 2;
    _globalRetryAt = DateTime.now().add(Duration(seconds: seconds));
  }

  void _resetGlobalFailures() {
    _globalFailures = 0;
    _globalRetryAt = null;
  }
}

class _SyncConflictDraft {
  _SyncConflictDraft({
    required this.requestId,
    required this.action,
    required this.local,
    required this.message,
  });

  final String requestId;
  final OutboxAction action;
  final Map<String, Object?> local;
  final String message;
}

String _hhmm(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
