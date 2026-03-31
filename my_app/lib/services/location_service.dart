import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationErrorCode {
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  unknown,
}

class LocationException implements Exception {
  LocationException(this.code, this.message);
  final LocationErrorCode code;
  final String message;

  @override
  String toString() => 'LocationException: $message';
}

class LocationService {
  LocationService._();

  static Future<void> openSettings(LocationErrorCode? code) async {
    if (code == null) return;
    switch (code) {
      case LocationErrorCode.servicesDisabled:
        await Geolocator.openLocationSettings();
        return;
      case LocationErrorCode.permissionDeniedForever:
        await Geolocator.openAppSettings();
        return;
      case LocationErrorCode.permissionDenied:
      case LocationErrorCode.unknown:
        return;
    }
  }

  static Future<void> ensureReady() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw LocationException(
          LocationErrorCode.servicesDisabled,
          'Location services are disabled',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw LocationException(
          LocationErrorCode.permissionDenied,
          'Location permission denied',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        throw LocationException(
          LocationErrorCode.permissionDeniedForever,
          'Location permission permanently denied. Enable it in app settings.',
        );
      }
    } on LocationException {
      rethrow;
    } catch (e) {
      throw LocationException(LocationErrorCode.unknown, e.toString());
    }
  }

  static Future<Position> current({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    await ensureReady();
    return Geolocator.getCurrentPosition(desiredAccuracy: accuracy);
  }

  static Stream<Position> stream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 5,
  }) async* {
    await ensureReady();
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilterMeters,
    );
    yield* Geolocator.getPositionStream(locationSettings: settings);
  }
}
