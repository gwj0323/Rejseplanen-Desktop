import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? lat;
  final double? lon;
  final String? errorKey;
  final bool isSuccess;
  final bool isPermissionDeniedForever;
  final bool isServiceDisabled;

  LocationResult.success(this.lat, this.lon)
      : errorKey = null,
        isSuccess = true,
        isPermissionDeniedForever = false,
        isServiceDisabled = false;

  LocationResult.failure(
    this.errorKey, {
    this.isPermissionDeniedForever = false,
    this.isServiceDisabled = false,
  })  : lat = null,
        lon = null,
        isSuccess = false;
}

class LocationService {
  /// Request permission and acquire current device GPS position
  static Future<LocationResult> getCurrentPosition({bool requestIfNotGranted = true}) async {
    try {
      // 1. Check & Request Runtime Permission FIRST!
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('[LocationService] Current permission status: $permission');

      if (permission == LocationPermission.denied) {
        if (requestIfNotGranted) {
          permission = await Geolocator.requestPermission();
          debugPrint('[LocationService] Requested permission result: $permission');
        }
        if (permission == LocationPermission.denied) {
          return LocationResult.failure("location_permission_denied");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          "location_permission_denied_forever",
          isPermissionDeniedForever: true,
        );
      }

      // 2. Check if Location Services (GPS Toggle) is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[LocationService] Location service enabled: $serviceEnabled');
      if (!serviceEnabled) {
        return LocationResult.failure(
          "location_services_disabled",
          isServiceDisabled: true,
        );
      }

      // 3. Acquire position (Fast medium accuracy first, with fallback to last known)
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
        debugPrint('[LocationService] Acquired GPS: ${position.latitude}, ${position.longitude}');
        return LocationResult.success(position.latitude, position.longitude);
      } catch (e) {
        debugPrint('[LocationService] getCurrentPosition timed out or failed: $e, trying lastKnown...');
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          debugPrint('[LocationService] Using lastKnown: ${lastKnown.latitude}, ${lastKnown.longitude}');
          return LocationResult.success(lastKnown.latitude, lastKnown.longitude);
        }
        return LocationResult.failure("location_timeout");
      }
    } catch (e) {
      debugPrint('[LocationService] Unexpected location error: $e');
      return LocationResult.failure("location_error");
    }
  }

  /// Format distance between two coordinates into human-readable string (e.g. 150 m, 2.4 km)
  static String formatDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    final meters = 12742000 * asin(sqrt(max(0.0, a)));

    if (meters < 1000) {
      return "${meters.round()} m";
    } else if (meters < 100000) {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    } else {
      return "${(meters / 1000).round()} km";
    }
  }

  /// Whether coordinates are within Denmark bounding box (lat [54.3, 58.0], lon [7.5, 15.5])
  static bool isInDenmark(double lat, double lon) {
    return lat >= 54.3 && lat <= 58.0 && lon >= 7.5 && lon <= 15.5;
  }

  /// Approximate distance in km from coordinates to Copenhagen center (55.6761, 12.5683)
  static double distanceToDenmarkKm(double lat, double lon) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((55.6761 - lat) * p) / 2 +
        cos(lat * p) * cos(55.6761 * p) * (1 - cos((12.5683 - lon) * p)) / 2;
    final meters = 12742000 * asin(sqrt(max(0.0, a)));
    return meters / 1000.0;
  }

  static Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  static Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
