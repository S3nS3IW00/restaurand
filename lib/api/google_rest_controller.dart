import 'package:dio/dio.dart';

const List<String> PLACES_FIELDS = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.location",
  "places.googleMapsLinks",
];

class GoogleRestController {
  static final BaseOptions _options = BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 10),
    followRedirects: false,
    headers: {
      "X-Goog-Api-Key": "<MAPS_API_KEY>",
    }
  );

  static final Dio _dio = Dio(_options);

  static Dio get dio => _dio;
}