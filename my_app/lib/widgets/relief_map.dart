import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/request.dart';
import '../services/routing_service.dart';
import '../utils/map_cluster.dart';

// Zoom threshold: below this → heatmap zones, at/above → individual pins.
const double _kPinZoom = 13.0;

class ReliefMap extends StatefulWidget {
  const ReliefMap({
    super.key,
    required this.requests,
    this.height = 180,
    this.focusRequestId,
    this.onSelectRequest,
    this.onZoneTap,
    this.showHint = true,
    this.userLocation,
    this.followUserLocation = false,
    this.controller,
    this.userLocationZoom,
    this.onTapLatLng,
    this.hintText,
    this.routeResult,
  });

  final List<ReliefRequest> requests;
  final double? height;
  final String? focusRequestId;
  final ValueChanged<ReliefRequest>? onSelectRequest;
  final ValueChanged<RequestCluster>? onZoneTap;
  final bool showHint;
  final LatLng? userLocation;
  final bool followUserLocation;
  final MapController? controller;
  final double? userLocationZoom;
  final ValueChanged<LatLng>? onTapLatLng;
  final String? hintText;
  final RouteResult? routeResult;

  @override
  State<ReliefMap> createState() => _ReliefMapState();
}

class _ReliefMapState extends State<ReliefMap> {
  late final MapController _controller = widget.controller ?? MapController();
  double _currentZoom = 11.0;

  bool get _showHeatmap => _currentZoom < _kPinZoom;

  @override
  void didUpdateWidget(covariant ReliefMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final loc = widget.userLocation;
    if (loc == null) return;
    if (!widget.followUserLocation) return;
    if (oldWidget.userLocation == loc &&
        oldWidget.followUserLocation == widget.followUserLocation) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zoom = widget.userLocationZoom ?? _safeZoom();
      try {
        _controller.move(loc, zoom);
      } catch (_) {}
    });
  }

  double _safeZoom() {
    try {
      return _controller.camera.zoom;
    } catch (_) {
      return 15;
    }
  }

  void _onZoomChange(double zoom) {
    if ((zoom < _kPinZoom) != (_currentZoom < _kPinZoom)) {
      setState(() => _currentZoom = zoom);
    } else {
      _currentZoom = zoom;
    }
  }

  /// Tap on a heatmap zone → fire onZoneTap callback (only if cluster has requests).
  void _onZoneTap(RequestCluster cluster) {
    if (cluster.count > 0) {
      widget.onZoneTap?.call(cluster);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.requests
        .map((r) => tryParseLatLng(r.locationText))
        .whereType<LatLng>()
        .toList();

    final focusRequest = widget.focusRequestId == null
        ? null
        : widget.requests
              .where((r) => r.id == widget.focusRequestId)
              .firstOrNull;

    final focusPoint =
        focusRequest == null ? null : tryParseLatLng(focusRequest.locationText);

    final center =
        focusPoint ??
        (points.isNotEmpty
            ? _centerOf(points)
            : (widget.userLocation ?? const LatLng(12.9716, 77.5946)));

    // Build clusters for heatmap layer.
    final clusters = buildClusters(widget.requests);

    // Soft gradient heatmap: multiple concentric rings per cluster,
    // each ring larger and more transparent → looks like a radial gradient blob.
    final circleMarkers = <CircleMarker>[
      for (final cluster in clusters) ..._softHeatRings(cluster),
    ];

    // Tappable invisible overlay markers for each zone (for tap-to-zoom).
    final zoneMarkers = <Marker>[
      for (final cluster in clusters)
        Marker(
          point: cluster.center,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _onZoneTap(cluster),
            child: _ZoneLabel(cluster: cluster),
          ),
        ),
    ];

    // Individual pin markers (shown when zoomed in).
    final pinMarkers = <Marker>[
      for (final r in widget.requests)
        if (tryParseLatLng(r.locationText) case final LatLng p)
          Marker(
            point: p,
            width: 54,
            height: 62,
            child: GestureDetector(
              onTap: widget.onSelectRequest == null
                  ? null
                  : () => widget.onSelectRequest!(r),
              child: _UrgencyMarkerPin(
                color: priorityColor(r),
                icon: requestTypeIcon(r.type),
                isFocused: r.id == widget.focusRequestId,
                status: r.status,
              ),
            ),
          ),
      if (widget.userLocation case final LatLng u)
        Marker(point: u, width: 44, height: 44, child: const _UserMarker()),
    ];

    final mapStack = Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: points.isNotEmpty
                ? 11
                : (widget.userLocation != null ? 15 : 11),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
            onTap: widget.onTapLatLng == null
                ? null
                : (_, latLng) => widget.onTapLatLng!(latLng),
            onMapEvent: (event) {
              if (event is MapEventMove ||
                  event is MapEventScrollWheelZoom ||
                  event is MapEventDoubleTapZoom) {
                _onZoomChange(event.camera.zoom);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'my_app',
            ),
            // Heatmap layer — visible when zoomed out.
            if (_showHeatmap && circleMarkers.isNotEmpty)
              CircleLayer(circles: circleMarkers),
            // Zone tap labels — visible when zoomed out.
            if (_showHeatmap && zoneMarkers.isNotEmpty)
              MarkerLayer(markers: zoneMarkers),
            // Individual pins — visible when zoomed in.
            if (!_showHeatmap)
              MarkerLayer(markers: pinMarkers),
            // Always show user location dot.
            if (_showHeatmap && widget.userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.userLocation!,
                    width: 44,
                    height: 44,
                    child: const _UserMarker(),
                  ),
                ],
              ),
            // Route polyline overlay.
            if (widget.routeResult != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routeResult!.points,
                    strokeWidth: widget.routeResult!.isFallback ? 3.0 : 5.0,
                    color: const Color(0xFF2563EB),
                    pattern: widget.routeResult!.isFallback
                        ? StrokePattern.dashed(segments: const [12, 8])
                        : const StrokePattern.solid(),
                  ),
                ],
              ),
          ],
        ),
        if (widget.showHint)
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: _MapHint(
              hasMarkers: points.isNotEmpty,
              overrideText: widget.hintText,
              showingHeatmap: _showHeatmap && clusters.isNotEmpty,
            ),
          ),
        if (widget.routeResult != null)
          Positioned(
            left: 12,
            bottom: 12,
            child: _RouteInfoCard(result: widget.routeResult!),
          ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: widget.height,
        child: mapStack,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Zone label — shows count bubble + assigned indicator on heatmap circle.
// ---------------------------------------------------------------------------

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.cluster});

  final RequestCluster cluster;

  @override
  Widget build(BuildContext context) {
    final color = cluster.color;
    final hasAssigned = cluster.hasAssigned;

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 14,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cluster.pendingCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                if (hasAssigned) ...[
                  Container(
                    width: 1,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const Icon(
                    Icons.directions_run,
                    color: Colors.white,
                    size: 13,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${cluster.inProgressCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Green dot badge when any request is assigned
          if (hasAssigned)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pin marker (zoomed-in view)
// ---------------------------------------------------------------------------

class _UrgencyMarkerPin extends StatelessWidget {
  const _UrgencyMarkerPin({
    required this.color,
    required this.icon,
    required this.isFocused,
    required this.status,
  });

  final Color color;
  final IconData icon;
  final bool isFocused;
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final size = isFocused ? 28.0 : 24.0;
    final isAssigned = status == RequestStatus.assigned || status == RequestStatus.inProgress;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing assigned ring
              if (isAssigned)
                Container(
                  width: size + 10,
                  height: size + 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF16A34A),
                      width: 2.5,
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: isAssigned ? const Color(0xFF16A34A) : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: isFocused ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isAssigned ? const Color(0xFF16A34A) : color)
                          .withValues(alpha: isFocused ? 0.48 : 0.32),
                      blurRadius: isFocused ? 14 : 10,
                      spreadRadius: isFocused ? 5 : 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  isAssigned ? Icons.check : icon,
                  color: Colors.white,
                  size: isFocused ? 16 : 14,
                ),
              ),
            ],
          ),
          Container(
            width: 0,
            height: 0,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Colors.transparent,
                  width: size * 0.22,
                ),
                right: BorderSide(
                  color: Colors.transparent,
                  width: size * 0.22,
                ),
                top: BorderSide(
                  color: isAssigned ? const Color(0xFF16A34A) : color,
                  width: size * 0.30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User location dot
// ---------------------------------------------------------------------------

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332563EB),
              blurRadius: 14,
              spreadRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hint banner
// ---------------------------------------------------------------------------

class _MapHint extends StatelessWidget {
  const _MapHint({
    required this.hasMarkers,
    required this.overrideText,
    required this.showingHeatmap,
  });

  final bool hasMarkers;
  final String? overrideText;
  final bool showingHeatmap;

  @override
  Widget build(BuildContext context) {
    final text = overrideText ??
        (showingHeatmap
            ? 'Tap a zone to see requests in that area.'
            : (hasMarkers
                ? 'Drag/zoom the map. Pins show request locations.'
                : 'Map needs request locations to show pins.'));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.map, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route info card
// ---------------------------------------------------------------------------

class _RouteInfoCard extends StatelessWidget {
  const _RouteInfoCard({required this.result});

  final RouteResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions, size: 18, color: Color(0xFF2563EB)),
          const SizedBox(width: 8),
          Text(
            result.distanceLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 14, color: const Color(0xFFD1D5DB)),
          const SizedBox(width: 8),
          const Icon(Icons.access_time, size: 14, color: Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(
            result.durationLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
          if (result.isFallback) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'OFFLINE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF92400E),
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Utilities
// ---------------------------------------------------------------------------

LatLng? tryParseLatLng(String locationText) {
  final re = RegExp(
    r'Lat:\s*([-+]?\d+(\.\d+)?),\s*Lng:\s*([-+]?\d+(\.\d+)?)',
  );
  final match = re.firstMatch(locationText);
  if (match == null) return null;
  final lat = double.tryParse(match.group(1) ?? '');
  final lng = double.tryParse(match.group(3) ?? '');
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return LatLng(lat, lng);
}

LatLng _centerOf(List<LatLng> points) {
  if (points.isEmpty) return const LatLng(0, 0);
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  for (final p in points.skip(1)) {
    minLat = min(minLat, p.latitude);
    maxLat = max(maxLat, p.latitude);
    minLng = min(minLng, p.longitude);
    maxLng = max(maxLng, p.longitude);
  }
  return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
}

/// Produces concentric rings that fade out from center → edge,
/// simulating a smooth radial-gradient heatmap blob.
List<CircleMarker> _softHeatRings(RequestCluster cluster) {
  const rings = 7;
  final color = cluster.color;
  final maxR = cluster.radiusMeters;
  return List.generate(rings, (i) {
    // innermost ring = most opaque, outermost = nearly transparent
    final t = i / (rings - 1); // 0.0 (center) → 1.0 (edge)
    final radius = maxR * (0.18 + 0.82 * t);
    final opacity = (0.38 * (1 - t * t)).clamp(0.0, 1.0); // quadratic falloff
    return CircleMarker(
      point: cluster.center,
      radius: radius,
      useRadiusInMeter: true,
      color: color.withOpacity(opacity),
      borderStrokeWidth: 0,
    );
  }).reversed.toList(); // draw largest (most transparent) first
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
