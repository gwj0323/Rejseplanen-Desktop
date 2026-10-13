import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? lat;
  final double? lon;
  final String? errorKey;
  final bool isSuccess;

  LocationResult.success(this.lat, this.lon)
      : errorKey = null,
        isSuccess = true;

  LocationResult.failure(this.errorKey)
      : lat = null,
        lon = null,
        isSuccess = false;
}

class LocationService {
  static Future<LocationResult> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult.failure("location_services_disabled");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationResult.failure("location_permission_denied");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure("location_permission_denied_forever");
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
        return LocationResult.success(position.latitude, position.longitude);
      } catch (_) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LocationResult.success(lastKnown.latitude, lastKnown.longitude);
        }
        return LocationResult.failure("location_timeout");
      }
    } catch (e) {
      return LocationResult.failure("location_error");
    }
  }
}
