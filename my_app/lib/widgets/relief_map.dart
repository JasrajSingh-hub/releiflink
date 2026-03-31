import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/request.dart';

class ReliefMap extends StatefulWidget {
  const ReliefMap({
    super.key,
    required this.requests,
    this.height = 180,
    this.focusRequestId,
    this.onSelectRequest,
    this.showHint = true,
    this.userLocation,
    this.followUserLocation = false,
    this.controller,
    this.userLocationZoom,
    this.onTapLatLng,
    this.hintText,
  });

  final List<ReliefRequest> requests;
  final double? height;
  final String? focusRequestId;
  final ValueChanged<ReliefRequest>? onSelectRequest;
  final bool showHint;
  final LatLng? userLocation;
  final bool followUserLocation;
  final MapController? controller;
  final double? userLocationZoom;
  final ValueChanged<LatLng>? onTapLatLng;
  final String? hintText;

  @override
  State<ReliefMap> createState() => _ReliefMapState();
}

class _ReliefMapState extends State<ReliefMap> {
  late final MapController _controller = widget.controller ?? MapController();

  @override
  void didUpdateWidget(covariant ReliefMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final loc = widget.userLocation;
    if (loc == null) return;
    if (!widget.followUserLocation) return;
    if (oldWidget.userLocation == loc &&
        oldWidget.followUserLocation == widget.followUserLocation) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zoom = widget.userLocationZoom ?? _safeZoomFallback();
      try {
        _controller.move(loc, zoom);
      } catch (_) {}
    });
  }

  double _safeZoomFallback() {
    try {
      return _controller.camera.zoom;
    } catch (_) {
      return 15;
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

    final focusPoint = focusRequest == null
        ? null
        : tryParseLatLng(focusRequest.locationText);

    final center =
        focusPoint ??
        (points.isNotEmpty
            ? _centerOf(points)
            : (widget.userLocation ??
                  const LatLng(12.9716, 77.5946))); // default: BLR

    final markers = <Marker>[
      for (final r in widget.requests)
        if (tryParseLatLng(r.locationText) case final LatLng p)
          Marker(
            point: p,
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: widget.onSelectRequest == null
                  ? null
                  : () => widget.onSelectRequest!(r),
              child: _MarkerDot(
                color: priorityColor(r),
                isFocused: r.id == widget.focusRequestId,
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
                ? 12
                : (widget.userLocation != null ? 15 : 11),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
            onTap: widget.onTapLatLng == null
                ? null
                : (tapPosition, latLng) => widget.onTapLatLng!(latLng),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'my_app',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        if (widget.showHint)
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: _MapHint(
              hasMarkers: markers.isNotEmpty,
              overrideText: widget.hintText,
            ),
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

class _MarkerDot extends StatelessWidget {
  const _MarkerDot({required this.color, required this.isFocused});

  final Color color;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: isFocused ? 22 : 18,
        height: isFocused ? 22 : 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: isFocused ? 3 : 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _MapHint extends StatelessWidget {
  const _MapHint({required this.hasMarkers, required this.overrideText});

  final bool hasMarkers;
  final String? overrideText;

  @override
  Widget build(BuildContext context) {
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
              child: Text(
                overrideText ??
                    (hasMarkers
                        ? 'Drag/zoom the map. Pins show request locations.'
                        : 'Map needs request locations to show pins.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

LatLng? tryParseLatLng(String locationText) {
  // Expected format from the create flow:
  // "Lat: 12.97160, Lng: 77.59460"
  final re = RegExp(r'Lat:\s*([-+]?\d+(\.\d+)?),\s*Lng:\s*([-+]?\d+(\.\d+)?)');
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
