import 'outbox_item.dart';

class SyncConflict {
  SyncConflict({
    required this.id,
    required this.requestId,
    required this.action,
    required this.local,
    required this.remote,
    required this.createdAt,
    this.message,
  });

  final String id;
  final String requestId;
  final OutboxAction action;
  final Map<String, Object?>? local;
  final Map<String, Object?>? remote;
  final DateTime createdAt;
  final String? message;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'requestId': requestId,
      'action': action.name,
      'local': local,
      'remote': remote,
      'createdAt': createdAt.toIso8601String(),
      'message': message,
    };
  }

  static SyncConflict fromJson(Map<String, Object?> json) {
    return SyncConflict(
      id: (json['id'] as String?) ?? 'unknown',
      requestId: (json['requestId'] as String?) ?? 'unknown',
      action: _parseEnum(OutboxAction.values, json['action'], OutboxAction.updateRequest),
      local: (json['local'] as Map?)?.cast<String, Object?>(),
      remote: (json['remote'] as Map?)?.cast<String, Object?>(),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      message: json['message'] as String?,
    );
  }
}

T _parseEnum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is String) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
  }
  return fallback;
}

