import 'dart:math';

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double R = 6371000; // Earth radius in meters
  double dLat = _degreesToRadians(lat2 - lat1);
  double dLon = _degreesToRadians(lon2 - lon1);
  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}

double calculateAngle(
    double centerX, double centerY, double pointX, double pointY) {
  double angleRad = atan2(pointY - centerY, pointX - centerX);

  double angleDeg = angleRad * 180 / pi;
  if (angleDeg < 0) {
    angleDeg += 360;
  }

  return angleDeg;
}
