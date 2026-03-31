import 'dart:math';

import '../models/request.dart';

class RequestService {
  RequestService._();

  static final RequestService instance = RequestService._();

  final List<ReliefRequest> _requests = [];

  List<ReliefRequest> getAll() => List.unmodifiable(_requests);

  ReliefRequest? getById(String id) {
    for (final r in _requests) {
      if (r.id == id) return r;
    }
    return null;
  }

  ReliefRequest createRequest({
    required RequestType type,
    required String description,
    required int peopleCount,
    required String locationText,
  }) {
    final priority = computePriority(type: type, peopleCount: peopleCount);
    final request = ReliefRequest(
      id: _generateId(),
      type: type,
      description: description.trim(),
      peopleCount: peopleCount,
      locationText: locationText.trim(),
      createdAt: DateTime.now(),
      priority: priority,
    );
    _requests.insert(0, request);
    return request;
  }

  ReliefRequest acceptRequest(String id) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Request not found');
    }
    if (existing.status != RequestStatus.pending) {
      return existing;
    }
    final updated = existing.copyWith(status: RequestStatus.inProgress);
    _replace(updated);
    return updated;
  }

  ReliefRequest markCompleted(String id) {
    final existing = getById(id);
    if (existing == null) {
      throw StateError('Request not found');
    }
    if (existing.status == RequestStatus.completed) {
      return existing;
    }
    final updated = existing.copyWith(status: RequestStatus.completed);
    _replace(updated);
    return updated;
  }

  void _replace(ReliefRequest updated) {
    final index = _requests.indexWhere((r) => r.id == updated.id);
    if (index == -1) return;
    _requests[index] = updated;
  }

  static String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(1 << 20);
    return 'req_${now}_$rand';
  }
}

