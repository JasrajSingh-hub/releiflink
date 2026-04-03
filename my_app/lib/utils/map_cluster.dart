import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/request.dart';

/// A cluster of requests grouped by geographic proximity.
class RequestCluster {
  RequestCluster({
    required this.center,
    required this.requests,
    required this.radiusMeters,
  });

  final LatLng center;
  final List<ReliefRequest> requests;
  final double radiusMeters;

  int get count => requests.length;

  /// Open requests (no volunteer yet).
  List<ReliefRequest> get open =>
      requests.where((r) => r.status == RequestStatus.open).toList();

  /// In-progress requests (volunteer assigned).
  List<ReliefRequest> get inProgress =>
      requests
          .where((r) => r.status == RequestStatus.assigned || r.status == RequestStatus.inProgress)
          .toList();

  int get pendingCount => open.length;
  int get inProgressCount => inProgress.length;

  /// True if at least one request has a volunteer assigned.
  bool get hasAssigned => inProgressCount > 0;

  /// Highest priority among PENDING requests only.
  /// Falls back to overall dominant if all are in-progress.
  RequestPriority get dominantPriority {
    final active = open.isNotEmpty ? open : requests;
    return active.reduce(
      (a, b) => priorityRank(a.priority) <= priorityRank(b.priority) ? a : b,
    ).priority;
  }

  Color get color => _priorityZoneColor(dominantPriority);
}

/// Groups [requests] into clusters where points within [thresholdMeters] of
/// each other are merged. Uses a simple greedy approach — fast enough for
/// hundreds of requests.
List<RequestCluster> buildClusters(
  List<ReliefRequest> requests, {
  double thresholdMeters = 600,
}) {
  // Only requests that have parseable coordinates.
  final located = <_Located>[];
  for (final r in requests) {
    final ll = _parseLatLng(r.locationText);
    if (ll != null) located.add(_Located(r, ll));
  }

  final assigned = List<bool>.filled(located.length, false);
  final clusters = <RequestCluster>[];

  for (var i = 0; i < located.length; i++) {
    if (assigned[i]) continue;
    assigned[i] = true;

    final members = <_Located>[located[i]];

    for (var j = i + 1; j < located.length; j++) {
      if (assigned[j]) continue;
      if (_distanceMeters(located[i].ll, located[j].ll) <= thresholdMeters) {
        members.add(located[j]);
        assigned[j] = true;
      }
    }

    final center = _centroid(members.map((m) => m.ll).toList());
    // Radius grows with count but is capped so it doesn't cover the whole map.
    final radius = (thresholdMeters * 0.5 * log(members.length + 1)).clamp(
      200.0,
      thresholdMeters * 1.2,
    );

    clusters.add(
      RequestCluster(
        center: center,
        requests: members.map((m) => m.request).toList(),
        radiusMeters: radius,
      ),
    );
  }

  return clusters;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _Located {
  _Located(this.request, this.ll);
  final ReliefRequest request;
  final LatLng ll;
}

double _distanceMeters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final sinDLat = sin(dLat / 2);
  final sinDLng = sin(dLng / 2);
  final h =
      sinDLat * sinDLat +
      cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sinDLng * sinDLng;
  return 2 * r * asin(sqrt(h));
}

double _rad(double deg) => deg * pi / 180;

LatLng _centroid(List<LatLng> points) {
  var lat = 0.0;
  var lng = 0.0;
  for (final p in points) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / points.length, lng / points.length);
}

LatLng? _parseLatLng(String text) {
  final re = RegExp(
    r'Lat:\s*([-+]?\d+(\.\d+)?),\s*Lng:\s*([-+]?\d+(\.\d+)?)',
  );
  final m = re.firstMatch(text);
  if (m == null) return null;
  final lat = double.tryParse(m.group(1) ?? '');
  final lng = double.tryParse(m.group(3) ?? '');
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return LatLng(lat, lng);
}

/// Semi-transparent zone colors — distinct from the pin colors so the
/// heatmap feel is softer/glowing.
Color _priorityZoneColor(RequestPriority p) {
  return switch (p) {
    RequestPriority.critical => const Color(0xFFE53935), // red
    RequestPriority.high => const Color(0xFFFB8C00), // orange
    RequestPriority.medium => const Color(0xFFFDD835), // yellow
    RequestPriority.low => const Color(0xFF78909C), // blue-grey
  };
}
