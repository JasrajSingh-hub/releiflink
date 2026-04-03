import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/request.dart';
import '../storage/local_store.dart';
import 'conflict_service.dart';
import 'outbox_service.dart';
import '../models/outbox_item.dart';

class RequestService extends ChangeNotifier {
  RequestService._();

  static final RequestService instance = RequestService._();

  late final Box<Map> _requestsBox;
  List<ReliefRequest> _cache = const [];
  bool _ready = false;

  bool get ready => _ready;

  Future<void> init() async {
    _requestsBox = LocalStore.requestsBox();
    _rebuildCache();
    _requestsBox.watch().listen((_) {
      _rebuildCache();
      notifyListeners();
    });
    _ready = true;
    notifyListeners();
  }

  List<ReliefRequest> getAll() => List.unmodifiable(_cache);

  ReliefRequest? getById(String id) {
    for (final r in _cache) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<ReliefRequest> createRequest({
    required RequestType type,
    required String description,
    required int peopleCount,
    required String locationText,
  }) async {
    final priority = computePriority(type: type, peopleCount: peopleCount);
    final now = DateTime.now();
    final request = ReliefRequest(
      id: _generateId(),
      type: type,
      description: description.trim(),
      peopleCount: peopleCount,
      locationText: locationText.trim(),
      createdAt: now,
      updatedAt: now,
      priority: priority,
    );
    await _requestsBox.put(request.id, request.toJson());
    await OutboxService.instance.enqueue(
      action: OutboxAction.createRequest,
      requestId: request.id,
      payload: request.toJson(),
      baseUpdatedAt: null,
    );
    _rebuildCache();
    notifyListeners();
    return request;
  }

  Future<ReliefRequest> updateRequest({
    required String id,
    RequestType? type,
    String? description,
    int? peopleCount,
    String? locationText,
  }) async {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Request not found');
    }
    final baseUpdatedAt = existing.updatedAt;

    final nextType = type ?? existing.type;
    final nextPeopleCount = peopleCount ?? existing.peopleCount;
    final nextPriority =
        computePriority(type: nextType, peopleCount: nextPeopleCount);

    final updated = existing.copyWith(
      type: type,
      description: description?.trim(),
      peopleCount: peopleCount,
      locationText: locationText?.trim(),
      priority: nextPriority,
    );

    await _requestsBox.put(updated.id, updated.toJson());
    await OutboxService.instance.enqueue(
      action: OutboxAction.updateRequest,
      requestId: updated.id,
      payload: updated.toJson(),
      baseUpdatedAt: baseUpdatedAt,
    );

    _rebuildCache();
    notifyListeners();
    return updated;
  }

  Future<void> applyRemoteRequests(List<Map<String, Object?>> remote) async {
    var changed = false;
    for (final json in remote) {
      final incoming = ReliefRequest.fromJson(json);
      final existing = getById(incoming.id);
      if (existing == null) {
        await _requestsBox.put(incoming.id, incoming.toJson());
        changed = true;
        continue;
      }

      if (!incoming.updatedAt.isAfter(existing.updatedAt)) {
        continue;
      }

      final pendingLocal = OutboxService.instance
          .getPending()
          .where((i) => i.requestId == incoming.id)
          .toList();

      if (pendingLocal.isNotEmpty) {
        // Minimal conflict handling: server wins; preserve local snapshot for review.
        await ConflictService.instance.add(
          requestId: incoming.id,
          action: pendingLocal.first.action,
          local: existing.toJson(),
          remote: incoming.toJson(),
          message: 'Server changed this request while you had unsynced edits.',
        );
        await OutboxService.instance.removeByRequestId(incoming.id);
      }

      await _requestsBox.put(incoming.id, incoming.toJson());
      changed = true;
    }
    if (changed) {
      _rebuildCache();
      notifyListeners();
    }
  }

  Future<ReliefRequest> acceptRequest(String id) async {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Request not found');
    }
    if (existing.status != RequestStatus.open) {
      return existing;
    }
    final updated = existing.copyWith(status: RequestStatus.inProgress);
    await _requestsBox.put(updated.id, updated.toJson());
    await OutboxService.instance.enqueue(
      action: OutboxAction.updateStatus,
      requestId: updated.id,
      payload: {'status': requestStatusToWire(updated.status)},
      baseUpdatedAt: existing.updatedAt,
    );
    _rebuildCache();
    notifyListeners();
    return updated;
  }

  Future<ReliefRequest> markCompleted(String id) async {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Request not found');
    }
    if (existing.status == RequestStatus.completed) {
      return existing;
    }
    final updated = existing.copyWith(status: RequestStatus.completed);
    await _requestsBox.put(updated.id, updated.toJson());
    await OutboxService.instance.enqueue(
      action: OutboxAction.updateStatus,
      requestId: updated.id,
      payload: {'status': requestStatusToWire(updated.status)},
      baseUpdatedAt: existing.updatedAt,
    );
    _rebuildCache();
    notifyListeners();
    return updated;
  }

  void _rebuildCache() {
    final list = <ReliefRequest>[];
    for (final value in _requestsBox.values) {
      list.add(ReliefRequest.fromJson(Map<String, Object?>.from(value)));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = list;
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    return 'req_${now}_$rand';
  }
}
