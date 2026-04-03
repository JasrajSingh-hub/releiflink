import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/request.dart';
import '../services/location_service.dart';
import '../services/request_service.dart';
import '../widgets/relief_map.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({
    super.key,
    this.embedded = false,
    this.onSubmitted,
  });

  static const routeName = '/create';

  final bool embedded;
  final VoidCallback? onSubmitted;

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = RequestService.instance;

  RequestType _type = RequestType.medical;
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _manualLocationController =
      TextEditingController();
  final TextEditingController _peopleController = TextEditingController();

  bool _submitting = false;
  int _peopleCount = 1;
  StreamSubscription<Position>? _posSub;
  bool _locating = false;
  bool _tracking = false;
  String? _gpsError;
  LocationErrorCode? _gpsErrorCode;
  bool _manualLocation = false;

  @override
  void initState() {
    super.initState();
    _peopleController.text = '$_peopleCount';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _descriptionController.dispose();
    _locationController.dispose();
    _manualLocationController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'IMMEDIATE ACTION REQUIRED',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Signal for Help',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Provide essential details. Coordination will prioritize based on severity and resources.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF52525B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'TYPE OF EMERGENCY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            _TypeGrid(
              value: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 18),
            Text(
              'SITUATION DETAILS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Briefly describe the situation (e.g., rising water, injuries, trapped people)...',
              ),
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Please describe the situation';
                if (value.length < 10) return 'Add a bit more detail';
                return null;
              },
            ),
            const SizedBox(height: 18),
            Text(
              'NUMBER OF PEOPLE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            _PeopleStepper(
              value: _peopleCount,
              controller: _peopleController,
              disabled: _submitting,
              onChanged: (v) {
                final next = v.clamp(1, 999);
                setState(() => _peopleCount = next);
                if (_peopleController.text != '$next') {
                  _peopleController.text = '$next';
                  _peopleController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _peopleController.text.length),
                  );
                }
              },
            ),
            const SizedBox(height: 18),
            Text(
              'CURRENT LOCATION',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            _LocationRow(
              locationText: _locationController.text.trim(),
              disabled: _submitting,
              locating: _locating,
              tracking: _tracking,
              manual: _manualLocation,
              errorText: _gpsError,
              errorCode: _gpsErrorCode,
              onDetect: _startLiveLocation,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _manualLocationController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                hintText: 'Type area / landmark (manual location)',
                prefixIcon: Icon(Icons.edit_location_alt),
              ),
            ),
            const SizedBox(height: 12),
            ReliefMap(
              requests: _previewRequest() == null
                  ? const []
                  : [_previewRequest()!],
              height: 170,
              focusRequestId: _previewRequest()?.id,
              userLocation: tryParseLatLng(_locationController.text.trim()),
              followUserLocation: _tracking,
              onTapLatLng: (LatLng p) => _setManualLocation(p),
              hintText:
                  'If internet/GPS fails, tap the map to drop a pin (tiles may be blank offline).',
            ),
            const SizedBox(height: 16),
            Text(
              'Encrypted data shared with verified disaster response teams only.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF71717A),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.send),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _submitting ? 'SUBMITTING...' : 'SUBMIT REQUEST',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const Text('New Request')),
      body: content,
    );
  }

  void _startLiveLocation() {
    if (_locating) return;
    final existingErrorCode = _gpsErrorCode;
    if (existingErrorCode == LocationErrorCode.servicesDisabled ||
        existingErrorCode == LocationErrorCode.permissionDeniedForever) {
      unawaited(LocationService.openSettings(existingErrorCode));
      return;
    }
    setState(() {
      _locating = true;
      _gpsError = null;
      _gpsErrorCode = null;
    });

    unawaited(() async {
      try {
        final current = await LocationService.current();
        _onPosition(current);

        await _posSub?.cancel();
        _posSub = LocationService.stream().listen(
          _onPosition,
          onError: (e) {
            if (!mounted) return;
            setState(() {
              _gpsError = e.toString();
              _gpsErrorCode = e is LocationException
                  ? e.code
                  : LocationErrorCode.unknown;
              _tracking = false;
            });
          },
        );
        if (!mounted) return;
        setState(() => _tracking = true);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _gpsError = e is LocationException ? e.message : e.toString();
          _gpsErrorCode = e is LocationException
              ? e.code
              : LocationErrorCode.unknown;
          _tracking = false;
        });
      } finally {
        if (mounted) setState(() => _locating = false);
      }
    }());
  }

  void _onPosition(Position p) {
    final lat = p.latitude;
    final lng = p.longitude;
    if (!mounted) return;
    setState(() {
      _locationController.text =
          'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
      _gpsError = null;
      _gpsErrorCode = null;
      _tracking = true;
      _manualLocation = false;
    });
  }

  void _setManualLocation(LatLng p) {
    _posSub?.cancel();
    if (!mounted) return;
    setState(() {
      _locationController.text =
          'Lat: ${p.latitude.toStringAsFixed(5)}, Lng: ${p.longitude.toStringAsFixed(5)}';
      _gpsError = null;
      _gpsErrorCode = null;
      _tracking = false;
      _locating = false;
      _manualLocation = true;
    });
  }

  String _effectiveLocationText() {
    final manual = _manualLocationController.text.trim();
    if (manual.isNotEmpty) return manual;
    return _locationController.text.trim();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final locationText = _effectiveLocationText();
    if (locationText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use AUTO GPS, tap the map, or type manual location'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.createRequest(
        type: _type,
        description: _descriptionController.text,
        peopleCount: _peopleCount,
        locationText: locationText,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request submitted')));
      if (widget.embedded) {
        setState(() {
          _descriptionController.clear();
          _locationController.clear();
          _manualLocationController.clear();
          _peopleCount = 1;
          _peopleController.text = '1';
          _type = RequestType.medical;
          _gpsError = null;
          _gpsErrorCode = null;
          _tracking = false;
          _locating = false;
          _manualLocation = false;
        });
      }
      widget.onSubmitted?.call();
      if (!widget.embedded) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  ReliefRequest? _previewRequest() {
    final locationText = _effectiveLocationText();
    if (locationText.isEmpty) return null;
    final now = DateTime.now();
    return ReliefRequest(
      id: 'preview',
      type: _type,
      description: _descriptionController.text.trim().isEmpty
          ? 'Preview'
          : _descriptionController.text.trim(),
      peopleCount: _peopleCount,
      locationText: locationText,
      createdAt: now,
      updatedAt: now,
      priority: computePriority(type: _type, peopleCount: _peopleCount),
    );
  }
}

class _TypeGrid extends StatelessWidget {
  const _TypeGrid({required this.value, required this.onChanged});

  final RequestType value;
  final ValueChanged<RequestType> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: [
        _TypeTile(
          label: 'MEDICAL',
          icon: Icons.medical_services,
          isSelected: value == RequestType.medical,
          onTap: () => onChanged(RequestType.medical),
        ),
        _TypeTile(
          label: 'FOOD',
          icon: Icons.restaurant,
          isSelected: value == RequestType.food,
          onTap: () => onChanged(RequestType.food),
        ),
        _TypeTile(
          label: 'SHELTER',
          icon: Icons.home,
          isSelected: value == RequestType.shelter,
          onTap: () => onChanged(RequestType.shelter),
        ),
        _TypeTile(
          label: 'RESCUE',
          icon: Icons.warning_amber,
          isSelected: value == RequestType.rescue,
          onTap: () => onChanged(RequestType.rescue),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? const Color(0xFF111827) : Colors.white;
    final fg = isSelected ? Colors.white : const Color(0xFF111827);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleStepper extends StatelessWidget {
  const _PeopleStepper({
    required this.value,
    required this.controller,
    required this.onChanged,
    required this.disabled,
  });

  final int value;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed:
                disabled || value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: TextField(
                  controller: controller,
                  enabled: !disabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '1',
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111827),
                      ),
                  onChanged: (raw) {
                    if (raw.trim().isEmpty) return;
                    final parsed = int.tryParse(raw);
                    if (parsed == null) return;
                    final next = parsed.clamp(1, 999);
                    if ('$next' != raw) {
                      controller.text = '$next';
                      controller.selection = TextSelection.fromPosition(
                        TextPosition(offset: controller.text.length),
                      );
                    }
                    if (next != value) onChanged(next);
                  },
                  onEditingComplete: () {
                    if (controller.text.trim().isNotEmpty) return;
                    controller.text = '1';
                    controller.selection = const TextSelection.collapsed(
                      offset: 1,
                    );
                    if (value != 1) onChanged(1);
                  },
                ),
              ),
            ),
          ),
          IconButton(
            onPressed:
                disabled || value >= 999 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.locationText,
    required this.onDetect,
    required this.disabled,
    required this.locating,
    required this.tracking,
    required this.manual,
    required this.errorText,
    required this.errorCode,
  });

  final String locationText;
  final VoidCallback onDetect;
  final bool disabled;
  final bool locating;
  final bool tracking;
  final bool manual;
  final String? errorText;
  final LocationErrorCode? errorCode;

  @override
  Widget build(BuildContext context) {
    final has = locationText.isNotEmpty;
    final error = errorText;
    final title = error != null
        ? error
        : (has
              ? locationText
              : (locating
                    ? 'Detecting location...'
                    : 'Tap AUTO to detect location'));
    final titleColor = error != null
        ? const Color(0xFFDC2626)
        : (has ? const Color(0xFF111827) : const Color(0xFF71717A));

    final status = error != null
        ? 'GPS: ERROR'
        : (tracking
              ? 'GPS: LIVE'
              : (manual
                    ? 'GPS: MANUAL (TAP MAP)'
                    : (locating ? 'GPS: STARTING' : 'GPS: OFF')));

    final buttonLabel = switch (errorCode) {
      LocationErrorCode.servicesDisabled => 'ENABLE',
      LocationErrorCode.permissionDeniedForever => 'SETTINGS',
      _ => 'AUTO',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, size: 20, color: Color(0xFF52525B)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: error != null
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF71717A),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: disabled ? null : onDetect,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
