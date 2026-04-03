import 'dart:math';

import 'package:hive/hive.dart';

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
    DateTime? baseUpdatedAt,
  }) async {
    final box = LocalStore.outboxBox();

    // Coalesce writes to reduce chatter on flaky networks:
    // - If a request is newly created but updated before syncing, keep a single create item.
    // - For updates/status, keep only the latest item per request+action.
    final existing = _pendingItems(box).where((i) => i.requestId == requestId).toList();
    final pendingCreate = existing.where((i) => i.action == OutboxAction.createRequest).toList();

    if (pendingCreate.isNotEmpty && action != OutboxAction.createRequest) {
      // Merge into the existing create payload.
      final create = pendingCreate.first;
      final mergedPayload = Map<String, Object?>.from(create.payload);
      mergedPayload.addAll(payload);
      final updated = OutboxItem(
        id: create.id,
        action: create.action,
        requestId: create.requestId,
        payload: mergedPayload,
        createdAt: create.createdAt,
        baseUpdatedAt: create.baseUpdatedAt,
        retryCount: create.retryCount,
        lastError: create.lastError,
        nextRetryAt: create.nextRetryAt,
      );
      await box.put(updated.id, updated.toJson());

      // Drop other queued items for this request since create now has the latest snapshot.
      for (final other in existing) {
        if (other.id != updated.id) {
          await box.delete(other.id);
        }
      }

      return updated;
    }

    // For updates/status: keep only one latest item of that action for this request.
    if (action == OutboxAction.updateRequest || action == OutboxAction.updateStatus) {
      for (final old in existing) {
        if (old.action == action) {
          await box.delete(old.id);
        }
      }
    }

    final item = OutboxItem(
      id: _generateId(),
      action: action,
      requestId: requestId,
      payload: payload,
      createdAt: DateTime.now(),
      baseUpdatedAt: baseUpdatedAt,
    );
    await box.put(item.id, item.toJson());
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
      baseUpdatedAt: existing.baseUpdatedAt,
      retryCount: retryCount,
      lastError: error.toString(),
      nextRetryAt: DateTime.now().add(Duration(seconds: backoffSeconds)),
    );
    await box.put(id, updated.toJson());
  }

  Future<void> remove(String id) async {
    await LocalStore.outboxBox().delete(id);
  }

  Future<void> removeByRequestId(String requestId) async {
    final box = LocalStore.outboxBox();
    for (final item in _pendingItems(box)) {
      if (item.requestId == requestId) {
        await box.delete(item.id);
      }
    }
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    return 'ob_${now}_$rand';
  }

  static List<OutboxItem> _pendingItems(Box<Map> box) {
    final items = <OutboxItem>[];
    for (final value in box.values) {
      items.add(OutboxItem.fromJson(Map<String, Object?>.from(value)));
    }
    items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return items;
  }
}
