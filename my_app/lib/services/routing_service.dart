import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result from a routing request.
class RouteResult {
  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.isFallback,
  });

  /// Decoded polyline points for the route.
  final List<LatLng> points;

  /// Total distance in meters.
  final double distanceMeters;

  /// Total duration in seconds.
  final double durationSeconds;

  /// True if this is a straight-line fallback (no internet / API failed).
  final bool isFallback;

  String get distanceLabel {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get durationLabel {
    final mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  /// Fetch a driving route from [origin] to [destination].
  /// Falls back to a straight line if the API is unreachable.
  Future<RouteResult> getRoute(LatLng origin, LatLng destination) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coords = geometry['coordinates'] as List<dynamic>;

          final points = coords.map((c) {
            final pair = c as List<dynamic>;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          }).toList();

          return RouteResult(
            points: points,
            distanceMeters: distance,
            durationSeconds: duration,
            isFallback: false,
          );
        }
      }
    } catch (_) {
      // Fall through to straight-line fallback.
    }

    return _straightLineFallback(origin, destination);
  }

  RouteResult _straightLineFallback(LatLng origin, LatLng destination) {
    final dist = _haversineMeters(origin, destination);
    // Estimate ~30 km/h average speed for fallback duration.
    final duration = (dist / 30000) * 3600;
    return RouteResult(
      points: [origin, destination],
      distanceMeters: dist,
      durationSeconds: duration,
      isFallback: true,
    );
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final h = sinDLat * sinDLat +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sinDLng * sinDLng;
    return 2 * r * asin(sqrt(h));
  }

  double _rad(double deg) => deg * pi / 180;
}
