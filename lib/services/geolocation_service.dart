import 'package:geolocator/geolocator.dart';

enum GeolocationError {
  SERVICE_DISABLED,
  PERMISSION_DENIED,
  PERMISSION_DENIED_PERMANENTLY,
}

extension GeolocationErrorExtension on GeolocationError {

  String get message {
    switch (this) {
      case GeolocationError.SERVICE_DISABLED:
        return "Location service disabled!";
      case GeolocationError.PERMISSION_DENIED:
        return "Location permission denied!";
      case GeolocationError.PERMISSION_DENIED_PERMANENTLY:
        return "Location permission denied permanently, cannot request permission!";
    }
  }

}

class GeolocationService {
  /// Determine the current position of the device.
  ///
  /// When the location services are not enabled or permissions
  /// are denied the `Future` will return an error.
  static Future<Position> getPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error(GeolocationError.SERVICE_DISABLED);
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error(GeolocationError.PERMISSION_DENIED);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(GeolocationError.PERMISSION_DENIED_PERMANENTLY);
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }
}