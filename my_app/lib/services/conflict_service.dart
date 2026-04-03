import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/outbox_item.dart';
import '../models/sync_conflict.dart';
import '../storage/local_store.dart';

class ConflictService extends ChangeNotifier {
  ConflictService._();

  static final ConflictService instance = ConflictService._();

  late final Box<Map> _box;
  bool _ready = false;

  bool get ready => _ready;

  Future<void> init() async {
    _box = LocalStore.conflictsBox();
    _box.watch().listen((_) => notifyListeners());
    _ready = true;
    notifyListeners();
  }

  int unresolvedCount() => _box.length;

  List<SyncConflict> listAll() {
    final list = <SyncConflict>[];
    for (final v in _box.values) {
      list.add(SyncConflict.fromJson(Map<String, Object?>.from(v)));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> add({
    required String requestId,
    required OutboxAction action,
    required Map<String, Object?>? local,
    required Map<String, Object?>? remote,
    String? message,
  }) async {
    final conflict = SyncConflict(
      id: _generateId(),
      requestId: requestId,
      action: action,
      local: local,
      remote: remote,
      createdAt: DateTime.now(),
      message: message,
    );
    await _box.put(conflict.id, conflict.toJson());
  }

  Future<void> dismiss(String id) async {
    await _box.delete(id);
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    return 'cx_${now}_$rand';
  }
}

