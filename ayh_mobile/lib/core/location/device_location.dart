import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Result of a device GPS attempt (coords only — no reverse geocoding).
class DeviceCoordinates {
  final double latitude;
  final double longitude;
  final bool fromCache;

  const DeviceCoordinates({
    required this.latitude,
    required this.longitude,
    this.fromCache = false,
  });
}

enum DeviceLocationFailure {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class DeviceLocationException implements Exception {
  final DeviceLocationFailure failure;
  final String message;

  DeviceLocationException(this.failure, this.message);

  @override
  String toString() => message;
}

/// Shared GPS fetch for Create Profile / Profile / Create Request.
///
/// Reverse geocoding is intentionally NOT done here — callers save coords
/// to Django and let the backend resolve city/state (or preview separately).
class DeviceLocation {
  /// Prefer a recent last-known fix, then a low-accuracy fresh fix.
  /// Emulators often fail medium/high accuracy within a short timeLimit.
  static Future<DeviceCoordinates> getCoordinates({
    Duration freshTimeout = const Duration(seconds: 12),
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
        'Turn on Location in device settings and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw DeviceLocationException(
        DeviceLocationFailure.permissionDeniedForever,
        'Location access was permanently denied. Open app settings to allow it.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw DeviceLocationException(
        DeviceLocationFailure.permissionDenied,
        'Location permission is required. Allow it when prompted.',
      );
    }

    // Fast path: recent cached position (great for emulators / indoor).
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return DeviceCoordinates(
          latitude: last.latitude,
          longitude: last.longitude,
          fromCache: true,
        );
      }
    } catch (_) {
      // Ignore and try a fresh fix.
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // low is enough for city/radius matching and works better on emulators
          accuracy: LocationAccuracy.low,
          timeLimit: freshTimeout,
        ),
      );
      return DeviceCoordinates(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
    } on TimeoutException {
      // One more attempt without a hard timeLimit (capped by caller UI).
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.lowest,
            timeLimit: Duration(seconds: 8),
          ),
        );
        return DeviceCoordinates(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } on TimeoutException {
        throw DeviceLocationException(
          DeviceLocationFailure.timeout,
          "Couldn't get your location. Make sure Location is enabled and try again.",
        );
      }
    } on LocationServiceDisabledException {
      throw DeviceLocationException(
        DeviceLocationFailure.serviceDisabled,
        'Turn on Location in device settings and try again.',
      );
    } catch (e) {
      if (e is DeviceLocationException) rethrow;
      throw DeviceLocationException(
        DeviceLocationFailure.unavailable,
        "Couldn't get your location. Please try again.",
      );
    }
  }

  static String userMessage(Object error) {
    if (error is DeviceLocationException) return error.message;
    return "Couldn't get your location. Please try again.";
  }
}
