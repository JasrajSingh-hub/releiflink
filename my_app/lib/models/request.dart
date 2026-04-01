import 'package:flutter/material.dart';

enum RequestType { medical, food, rescue, shelter }

enum RequestStatus { pending, inProgress, completed }

enum RequestPriority { critical, high, medium, low }

class ReliefRequest {
  ReliefRequest({
    required this.id,
    required this.type,
    required this.description,
    required this.peopleCount,
    required this.locationText,
    required this.createdAt,
    required this.updatedAt,
    required this.priority,
    this.status = RequestStatus.pending,
  });

  final String id;
  final RequestType type;
  final String description;
  final int peopleCount;
  final String locationText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RequestPriority priority;
  final RequestStatus status;

  ReliefRequest copyWith({
    RequestType? type,
    String? description,
    int? peopleCount,
    String? locationText,
    RequestPriority? priority,
    RequestStatus? status,
    DateTime? updatedAt,
  }) {
    return ReliefRequest(
      id: id,
      type: type ?? this.type,
      description: description ?? this.description,
      peopleCount: peopleCount ?? this.peopleCount,
      locationText: locationText ?? this.locationText,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      priority: priority ?? this.priority,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      'description': description,
      'peopleCount': peopleCount,
      'locationText': locationText,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
    };
  }

  static ReliefRequest fromJson(Map<String, Object?> json) {
    return ReliefRequest(
      id: (json['id'] as String?) ?? 'unknown',
      type: _parseEnum(RequestType.values, json['type'], RequestType.medical),
      description: (json['description'] as String?) ?? '',
      peopleCount: (json['peopleCount'] as int?) ?? 1,
      locationText: (json['locationText'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      priority:
          _parseEnum(RequestPriority.values, json['priority'], RequestPriority.low),
      status: _parseEnum(RequestStatus.values, json['status'], RequestStatus.pending),
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

RequestPriority computePriority({
  required RequestType type,
  required int peopleCount,
}) {
  // Simple, transparent, rule-based logic (no AI).
  if (type == RequestType.medical) return RequestPriority.critical;
  if (type == RequestType.rescue) return RequestPriority.high;
  if (peopleCount >= 10) return RequestPriority.high;
  if (type == RequestType.shelter) return RequestPriority.medium;
  if (type == RequestType.food) return RequestPriority.medium;
  return RequestPriority.low;
}

int priorityRank(RequestPriority p) {
  return switch (p) {
    RequestPriority.critical => 0,
    RequestPriority.high => 1,
    RequestPriority.medium => 2,
    RequestPriority.low => 3,
  };
}

String requestTypeLabel(RequestType t) {
  return switch (t) {
    RequestType.medical => 'Medical',
    RequestType.food => 'Food',
    RequestType.rescue => 'Rescue',
    RequestType.shelter => 'Shelter',
  };
}

String requestStatusLabel(RequestStatus s) {
  return switch (s) {
    RequestStatus.pending => 'Pending',
    RequestStatus.inProgress => 'In Progress',
    RequestStatus.completed => 'Completed',
  };
}

String requestPriorityLabel(RequestPriority p) {
  return switch (p) {
    RequestPriority.critical => 'Critical',
    RequestPriority.high => 'High',
    RequestPriority.medium => 'Medium',
    RequestPriority.low => 'Low',
  };
}

IconData requestTypeIcon(RequestType t) {
  return switch (t) {
    RequestType.medical => Icons.medical_services,
    RequestType.food => Icons.restaurant,
    RequestType.rescue => Icons.warning_amber,
    RequestType.shelter => Icons.home,
  };
}

Color statusColor(RequestStatus s) {
  return switch (s) {
    RequestStatus.pending => const Color(0xFF455A64),
    RequestStatus.inProgress => const Color(0xFF1565C0),
    RequestStatus.completed => const Color(0xFF2E7D32),
  };
}

Color priorityColor(ReliefRequest r) {
  if (r.status == RequestStatus.completed) return const Color(0xFF2E7D32);
  return switch (r.priority) {
    RequestPriority.critical => const Color(0xFFC62828), // red
    RequestPriority.high => const Color(0xFFEF6C00), // orange
    RequestPriority.medium => const Color(0xFFF9A825), // yellow
    RequestPriority.low => const Color(0xFF607D8B), // blue grey
  };
}
