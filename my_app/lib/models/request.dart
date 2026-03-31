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
    required this.priority,
    this.status = RequestStatus.pending,
  });

  final String id;
  final RequestType type;
  final String description;
  final int peopleCount;
  final String locationText;
  final DateTime createdAt;
  final RequestPriority priority;
  final RequestStatus status;

  ReliefRequest copyWith({
    RequestType? type,
    String? description,
    int? peopleCount,
    String? locationText,
    RequestPriority? priority,
    RequestStatus? status,
  }) {
    return ReliefRequest(
      id: id,
      type: type ?? this.type,
      description: description ?? this.description,
      peopleCount: peopleCount ?? this.peopleCount,
      locationText: locationText ?? this.locationText,
      createdAt: createdAt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
    );
  }
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

