import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:restaurand/models/place_model.dart';

import 'google_rest_controller.dart';

class NearbySearchRestController {
  static Future<List<Place>> searchNearby(
      LatLng center, double radius, Locale locale) async {
    try {
      var response = await GoogleRestController.dio.post(
        "https://places.googleapis.com/v1/places:searchNearby",
        queryParameters: {
          "languageCode": locale.languageCode,
        },
        options: Options(headers: {
          "X-Goog-FieldMask": PLACES_FIELDS.join(","),
        }),
        data: {
          "includedTypes": ["restaurant"],
          "locationRestriction": {
            "circle": {
              "center": {
                "latitude": center.latitude,
                "longitude": center.longitude,
              },
              "radius": radius.clamp(0.0, 50000.0),
            },
          },
        },
      );

      final places = response.data["places"] ?? [];

      return Future.value(
          List<Place>.from(places.map((e) => Place.fromJson(e)).toList()));
    } on DioException catch (e) {
      if (e.response == null) {
        return Future.error("Couldn't connect to Google servers!");
      }
      return Future.error(e.response!.data.toString());
    }
  }
}
