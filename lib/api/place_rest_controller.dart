import 'dart:ui';

import 'package:dio/dio.dart';

import '../models/place_model.dart';
import 'google_rest_controller.dart';

class PlaceRestController {
  static Future<List<Place>> autocompletePlaces(
      String input, Locale locale) async {
    try {
      var response = await GoogleRestController.dio.post(
        "https://places.googleapis.com/v1/places:searchText",
        data: {
          "textQuery": input,
        },
        queryParameters: {
          "languageCode": locale.languageCode,
        },
        options: Options(
          headers: {
            "X-Goog-FieldMask": PLACES_FIELDS.join(","),
          },
        ),
      );

      final places = response.data["places"] ?? [];

      return Future.value(List<Place>.from(places.map((e) => Place.fromJson(e)).toList()));
    } on DioException catch (e) {
      if (e.response == null) {
        return Future.error("Couldn't connect to Google servers!");
      }
      return Future.error(e.response!.data.toString());
    }
  }
}
