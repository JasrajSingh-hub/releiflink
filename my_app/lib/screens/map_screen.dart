import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/request.dart';
import '../services/location_service.dart';
import '../services/request_service.dart';
import '../services/routing_service.dart';
import '../services/sync_service.dart';
import '../utils/map_cluster.dart';
import '../widgets/relief_map.dart';
import '../widgets/zone_summary_sheet.dart';
import 'request_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onNewReport});

  final VoidCallback onNewReport;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _service = RequestService.instance;
  ReliefRequest? _selected;
  String _filter = 'live';
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  LatLng? _userLocation;
  String? _gpsError;
  LocationErrorCode? _gpsErrorCode;
  RouteResult? _routeResult;
  bool _loadingRoute = false;

  @override
  void initState() {
    super.initState();
    _startGps();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _startGps() async {
    setState(() {
      _gpsError = null;
      _gpsErrorCode = null;
    });
    try {
      final current = await LocationService.current();
      _onPosition(current);
      await _posSub?.cancel();
      _posSub = LocationService.stream().listen(
        _onPosition,
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _gpsError = e is LocationException ? e.message : e.toString();
            _gpsErrorCode = e is LocationException
                ? e.code
                : LocationErrorCode.unknown;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsError = e is LocationException ? e.message : e.toString();
        _gpsErrorCode = e is LocationException
            ? e.code
            : LocationErrorCode.unknown;
      });
    }
  }

  void _onPosition(Position p) {
    final loc = LatLng(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      _userLocation = loc;
      _gpsError = null;
      _gpsErrorCode = null;
    });
    // Refresh route if we have an active in-progress request selected.
    _maybeRefreshRoute();
  }

  Future<void> _maybeRefreshRoute() async {
    final userLoc = _userLocation;
    final selected = _selected == null ? null : _service.getById(_selected!.id);
    if (userLoc == null ||
        selected == null ||
        selected.status != RequestStatus.inProgress) {
      if (_routeResult != null) setState(() => _routeResult = null);
      return;
    }
    final dest = tryParseLatLng(selected.locationText);
    if (dest == null) return;
    if (_loadingRoute) return;
    setState(() => _loadingRoute = true);
    try {
      final result = await RoutingService.instance.getRoute(userLoc, dest);
      if (!mounted) return;
      setState(() => _routeResult = result);
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _openRequestDetail(ReliefRequest request) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestDetailScreen(requestId: request.id),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      setState(() {});
      await _maybeRefreshRoute();
    }
  }

  void _showZoneSheet(RequestCluster cluster) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ZoneSummarySheet(
        cluster: cluster,
        isOffline: !SyncService.instance.online,
        onSelectRequest: _openRequestDetail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        final all = _service.getAll();
        final filtered = _applyFilter(all);
        final selected =
            _selected == null ? null : _service.getById(_selected!.id);

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _SearchRow(
                    onFilterTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Advanced filters are not part of this MVP',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _FilterChips(
                    value: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                  ),
                  const SizedBox(height: 12),
                  const _UrgencyLegend(),
                  const SizedBox(height: 10),
                  _GpsStatus(
                    location: _userLocation,
                    errorText: _gpsError,
                    errorCode: _gpsErrorCode,
                    onRetry: _startGps,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ReliefMap(
                      requests: filtered,
                      height: null,
                      focusRequestId: selected?.id,
                      onSelectRequest: (r) async {
                        final current = _selected;
                        if (current?.id == r.id) {
                          await _openRequestDetail(r);
                          return;
                        }
                        if (!mounted) return;
                        setState(() {
                          _selected = r;
                          _routeResult = null;
                        });
                        await _maybeRefreshRoute();
                      },
                      onZoneTap: _showZoneSheet,
                      showHint: false,
                      userLocation: _userLocation,
                      followUserLocation: selected == null,
                      controller: _mapController,
                      routeResult: _routeResult,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            if (selected != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 90,
                child: _SelectedCard(
                  request: selected,
                  onClear: () => setState(() {
                    _selected = null;
                    _routeResult = null;
                  }),
                  onView: () async {
                    final request = selected;
                    if (request == null) return;
                    await _openRequestDetail(request);
                  },
                ),
              ),
            Positioned(
              right: 20,
              bottom: 90,
              child: Column(
                children: [
                  FloatingActionButton(
                    heroTag: 'loc',
                    mini: true,
                    onPressed: () {
                      final loc = _userLocation;
                      if (loc == null) {
                        _startGps();
                        return;
                      }
                      try {
                        _mapController.move(loc, _mapController.camera.zoom);
                      } catch (_) {
                        _mapController.move(loc, 15);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'new',
                    onPressed: widget.onNewReport,
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<ReliefRequest> _applyFilter(List<ReliefRequest> all) {
    final activeOnly = all
        .where((r) => r.status != RequestStatus.completed)
        .toList();
    return switch (_filter) {
      'shelters' =>
        activeOnly.where((r) => r.type == RequestType.shelter).toList(),
      'supplies' =>
        activeOnly.where((r) => r.type == RequestType.food).toList(),
      'medical' =>
        activeOnly.where((r) => r.type == RequestType.medical).toList(),
      'rescue' =>
        activeOnly.where((r) => r.type == RequestType.rescue).toList(),
      _ => activeOnly,
    };
  }
}

class _UrgencyLegend extends StatelessWidget {
  const _UrgencyLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: const [
          _LegendItem(label: 'Critical', color: Color(0xFFC62828)),
          _LegendItem(label: 'High', color: Color(0xFFEF6C00)),
          _LegendItem(label: 'Medium', color: Color(0xFFF9A825)),
          _LegendItem(label: 'Low', color: Color(0xFF607D8B)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: const Color(0xFF52525B),
          ),
        ),
      ],
    );
  }
}

class _GpsStatus extends StatelessWidget {
  const _GpsStatus({
    required this.location,
    required this.errorText,
    required this.errorCode,
    required this.onRetry,
  });

  final LatLng? location;
  final String? errorText;
  final LocationErrorCode? errorCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = location;
    final has = loc != null;
    final actionLabel = switch (errorCode) {
      LocationErrorCode.servicesDisabled => 'ENABLE',
      LocationErrorCode.permissionDeniedForever => 'SETTINGS',
      _ => 'RETRY',
    };
    final label = errorText != null
        ? 'GPS ERROR'
        : (has ? 'GPS LIVE' : 'GPS OFF');

    final coords = has
        ? 'Lat: ${loc.latitude.toStringAsFixed(5)}, Lng: ${loc.longitude.toStringAsFixed(5)}'
        : 'Lat: —, Lng: —';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            errorText != null ? Icons.gps_off : Icons.gps_fixed,
            size: 18,
            color: errorText != null
                ? const Color(0xFFDC2626)
                : const Color(0xFF111827),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coords,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: errorText != null
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF71717A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (errorText != null || !has) ...[
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () async {
                final code = errorCode;
                if (code == LocationErrorCode.servicesDisabled ||
                    code == LocationErrorCode.permissionDeniedForever) {
                  await LocationService.openSettings(code);
                }
                onRetry();
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.onFilterTap});

  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            readOnly: true,
            decoration: const InputDecoration(
              hintText: 'Search locations...',
              prefixIcon: Icon(Icons.search),
            ),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search is not part of this MVP')),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 48,
          width: 52,
          child: OutlinedButton(
            onPressed: onFilterTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Icon(Icons.tune),
          ),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const chips = [
      (key: 'live',     label: 'LIVE SIGNALS', icon: Icons.wifi_tethering),
      (key: 'shelters', label: 'SHELTERS',      icon: Icons.home),
      (key: 'supplies', label: 'SUPPLIES',      icon: Icons.restaurant),
      (key: 'medical',  label: 'MEDICAL',       icon: Icons.medical_services),
      (key: 'rescue',   label: 'RESCUE',        icon: Icons.warning_amber),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _Chip(
              label: chips[i].label,
              icon: chips[i].icon,
              isActive: value == chips[i].key,
              onTap: () => onChanged(chips[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? const Color(0xFF111827) : Colors.white;
    final fg = isActive ? Colors.white : const Color(0xFF111827);
    final border = Theme.of(context).dividerColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.request,
    required this.onView,
    required this.onClear,
  });

  final ReliefRequest request;
  final VoidCallback onView;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final accent = priorityColor(request);
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Icon(requestTypeIcon(request.type), color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestPriorityLabel(request.priority).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    requestTypeLabel(request.type),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    request.locationText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF52525B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onView,
                      child: const Text('VIEW DETAILS'),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
          ],
        ),
      ),
    );
  }
}
