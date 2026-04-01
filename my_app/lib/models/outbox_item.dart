enum OutboxAction {
  createRequest,
  updateRequest,
  updateStatus,
}

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.action,
    required this.requestId,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
    this.nextRetryAt,
  });

  final String id;
  final OutboxAction action;
  final String requestId;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;
  final DateTime? nextRetryAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'action': action.name,
      'requestId': requestId,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'lastError': lastError,
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  static OutboxItem fromJson(Map<String, Object?> json) {
    return OutboxItem(
      id: (json['id'] as String?) ?? 'unknown',
      action: _parseEnum(OutboxAction.values, json['action'], OutboxAction.updateRequest),
      requestId: (json['requestId'] as String?) ?? 'unknown',
      payload: Map<String, Object?>.from((json['payload'] as Map?) ?? const {}),
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      retryCount: (json['retryCount'] as int?) ?? 0,
      lastError: json['lastError'] as String?,
      nextRetryAt: DateTime.tryParse((json['nextRetryAt'] as String?) ?? ''),
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

