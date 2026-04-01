import 'dart:math';

import '../models/outbox_item.dart';
import '../storage/local_store.dart';

class OutboxService {
  OutboxService._();

  static final OutboxService instance = OutboxService._();

  int pendingCount() => LocalStore.outboxBox().length;

  Future<OutboxItem> enqueue({
    required OutboxAction action,
    required String requestId,
    required Map<String, Object?> payload,
  }) async {
    final item = OutboxItem(
      id: _generateId(),
      action: action,
      requestId: requestId,
      payload: payload,
      createdAt: DateTime.now(),
    );
    await LocalStore.outboxBox().put(item.id, item.toJson());
    return item;
  }

  List<OutboxItem> getPending() {
    final items = <OutboxItem>[];
    for (final value in LocalStore.outboxBox().values) {
      items.add(OutboxItem.fromJson(Map<String, Object?>.from(value)));
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }

  Future<void> markFailed(String id, Object error) async {
    final box = LocalStore.outboxBox();
    final raw = box.get(id);
    if (raw == null) return;
    final existing = OutboxItem.fromJson(Map<String, Object?>.from(raw));

    final retryCount = existing.retryCount + 1;
    final backoffSeconds = min(600, pow(2, min(retryCount, 8)).toInt());
    final updated = OutboxItem(
      id: existing.id,
      action: existing.action,
      requestId: existing.requestId,
      payload: existing.payload,
      createdAt: existing.createdAt,
      retryCount: retryCount,
      lastError: error.toString(),
      nextRetryAt: DateTime.now().add(Duration(seconds: backoffSeconds)),
    );
    await box.put(id, updated.toJson());
  }

  Future<void> remove(String id) async {
    await LocalStore.outboxBox().delete(id);
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    return 'ob_${now}_$rand';
  }
}

