import 'package:google_maps_flutter/google_maps_flutter.dart';

class Place {
  Place({
    required this.id,
    required this.name,
    required this.formattedAddress,
    required this.location,
    required this.directionsUri,
  });

  final String id;
  final String name;
  final String formattedAddress;
  final LatLng location;
  final String directionsUri;

  factory Place.fromJson(data) {
    final location = data["location"];
    LatLng latLng = LatLng(location["latitude"], location["longitude"]);

    final links = data["googleMapsLinks"];

    return Place(
      id: data["id"],
      name: data["displayName"]["text"],
      formattedAddress: data["formattedAddress"],
      location: latLng,
      directionsUri: links["directionsUri"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "displayName": {
        "text": name,
      },
      "formattedAddress": formattedAddress,
      "location": {
        "latitude": location.latitude,
        "longitude": location.longitude,
      },
    };
  }
}
