import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:restaurand/api/nearby_search_rest_controller.dart';
import 'package:restaurand/api/place_rest_controller.dart';
import 'package:restaurand/services/geolocation_service.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:widget_to_marker/widget_to_marker.dart';

import '../models/place_model.dart';
import '../utils/debouncer.dart';
import '../utils/math_utils.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final Random random = Random();

  late final GoogleMapController _mapController;

  late AnimationController radarAnimationController;

  double zoom = 14.0;
  LatLng _center = const LatLng(0, 0);
  double _circleDiameter = 0.0;

  String? mapStyle;
  double _circleDiameterInMeters = 1000;

  bool filtersOpen = false;
  final FocusNode searchFieldFocus = FocusNode();
  final TextEditingController searchFieldController = TextEditingController();
  final searchFieldDebouncer = Debouncer(milliseconds: 500);

  List<Place> searchPlaces = [];
  List<Place> nearbyPlaces = [];
  Map<String, Offset> nearbyPlacesOffset = {};
  bool rolling = false;
  Place? result;
  BitmapDescriptor? markerWidget;
  Set<Marker> markers = {};

  Set<LatLng> enabledMarkerAlpha = {};

  @override
  void initState() {
    super.initState();

    rootBundle.loadString('assets/map/map_style.json').then((string) {
      setState(() {
        mapStyle = string;
      });
    });

    radarAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..repeat()
          ..addListener(() {
            setState(() {});
          });

    _loadMarkerWidget();
  }

  @override
  void dispose() {
    radarAnimationController.dispose();
    searchFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveBreakpoints.of(context).largerThan(MOBILE)) {
      _circleDiameter =
          _circleDiameter = MediaQuery.of(context).size.height / 2;
    } else {
      _circleDiameter = MediaQuery.of(context).size.width - 20.0;
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            style: mapStyle,
            mapType: MapType.normal,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            buildingsEnabled: false,
            indoorViewEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            trafficEnabled: false,
            liteModeEnabled: true,
            markers: markers,
            minMaxZoomPreference:
                MinMaxZoomPreference(getZoomLevel(50000), 50.0),
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: zoom,
            ),
            onMapCreated: (controller) async {
              _mapController = controller;

              await GeolocationService.getPosition().then((position) {
                _center = LatLng(position.latitude, position.longitude);
              }).onError((e, trace) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text((e as GeolocationError).message)));
                }
              });

              await _mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: _center, zoom: zoom),
                ),
              );

              _calculateCircleDiameter().then((distanceInMeters) {
                setState(() {
                  _circleDiameterInMeters = distanceInMeters;
                });
              });
            },
            onCameraMove: (position) {
              if (result == null) {
                setState(() {
                  zoom = position.zoom;
                  _center = position.target;
                });

                _calculateCircleDiameter().then((distanceInMeters) {
                  setState(() {
                    _circleDiameterInMeters = distanceInMeters;
                  });
                });
              }
            },
            rotateGesturesEnabled: result == null && !rolling,
            scrollGesturesEnabled:
                result == null && !rolling && !searchFieldFocus.hasFocus,
            tiltGesturesEnabled: result == null && !rolling,
            zoomGesturesEnabled: result == null && !rolling,
            gestureRecognizers: {
              Factory<PanGestureRecognizer>(() => PanGestureRecognizer())
            },
          ),
          if (result == null && rolling)
            ...nearbyPlaces.map((nearbyPlace) {
              final offset = nearbyPlacesOffset[nearbyPlace.id]!;
              return Positioned(
                left: offset.dx,
                top: offset.dy,
                child: Opacity(
                  opacity: _getAlphaForPoint(nearbyPlace.location),
                  child: Container(
                    width: 20.0,
                    height: 20.0,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blueAccent,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blueAccent,
                          Colors.transparent,
                        ],
                        center: Alignment.center,
                        radius: 1.0,
                      ),
                    ),
                  ),
                ),
              );
            }),
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: result == null ? _circleDiameter : 0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withValues(alpha: 0.2),
                border: Border.all(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
              child: AnimatedCrossFade(
                firstChild: RotationTransition(
                  turns: Tween(begin: 0.5, end: 1.5)
                      .animate(radarAnimationController),
                  child: Container(
                    width: _circleDiameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        center: FractionalOffset.center,
                        colors: <Color>[
                          Colors.blueAccent.withValues(alpha: 0.2),
                          Colors.blueAccent,
                          Colors.blueAccent.withValues(alpha: 0.2),
                        ],
                        stops: const [0.20, 0.25, 0.20],
                      ),
                    ),
                  ),
                ),
                secondChild: Container(),
                crossFadeState: rolling
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 500),
              ),
            ),
          ),
          Visibility(
            visible: result == null && !rolling,
            child: Positioned(
              bottom: MediaQuery.of(context).size.height / 2 -
                  _circleDiameter / 2 -
                  50.0,
              child: Chip(
                color: WidgetStateProperty.all(Colors.blueAccent),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(
                    color: Colors.blueAccent,
                  ),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                avatar: const Icon(
                  Symbols.distance,
                  color: Colors.white,
                ),
                label: Text(
                  "Radius: ${(_circleDiameterInMeters / 2 / 1000).toStringAsFixed(2)}km",
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: result == null,
            child: AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              top: filtersOpen || rolling
                  ? 0 - MediaQuery.of(context).size.height
                  : MediaQuery.of(context).padding.top + 10.0,
              left: 20,
              right: 20,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width /
                      ResponsiveValue(context,
                          defaultValue: 1,
                          conditionalValues: [
                            const Condition.largerThan(name: MOBILE, value: 3),
                          ]).value,
                  child: TapRegion(
                    onTapOutside: (callback) {
                      setState(() {
                        searchFieldFocus.unfocus();
                      });
                    },
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOutCubic,
                          height: searchFieldFocus.hasFocus &&
                                  searchPlaces.isNotEmpty
                              ? 500.0
                              : 45.0,
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.only(top: 40.0),
                            itemCount: searchPlaces.length,
                            separatorBuilder: (context, index) {
                              return const Divider(
                                height: 1,
                              );
                            },
                            itemBuilder: (context, index) {
                              final item = searchPlaces[index];

                              return ListTile(
                                leading: const Icon(Symbols.location_on),
                                title: Text(item.name),
                                subtitle: Text(item.formattedAddress),
                                onTap: () => _onSearchTileTap(item),
                              );
                            },
                          ),
                        ),
                        TextFormField(
                          focusNode: searchFieldFocus,
                          controller: searchFieldController,
                          onChanged: _searchOnChanged,
                          decoration: InputDecoration(
                              prefixIcon: const Icon(Symbols.search),
                              suffixIcon: IconButton(
                                icon: Icon(searchFieldController.text.isNotEmpty
                                    ? Symbols.clear
                                    : Symbols.my_location),
                                onPressed: _searchSuffixAction,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              hintText: "Location",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Visibility(
            visible: result == null,
            child: AnimatedPositioned(
              left: 20,
              right: 20,
              bottom: rolling
                  ? 0 - MediaQuery.of(context).size.height
                  : MediaQuery.of(context).padding.bottom + 10.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(builder: (context) {
                    final button = SizedBox(
                      height: 60.0,
                      width: 200.0,
                      child: ElevatedButton(
                        onPressed: _roll,
                        child: const Text("Roll"),
                      ),
                    );

                    if (ResponsiveBreakpoints.of(context).largerThan(MOBILE)) {
                      return button;
                    }

                    return Expanded(
                      child: button,
                    );
                  }),
                ],
              ),
            ),
          ),
          /*AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            top: filtersOpen
                ? MediaQuery.of(context).padding.top + 10.0
                : MediaQuery.of(context).size.height - 100.0,
            left: 20,
            right: 20,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      filtersOpen = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(filtersOpen
                              ? Symbols.keyboard_arrow_down
                              : Symbols.tune),
                          onPressed: () {
                            setState(() {
                              filtersOpen = !filtersOpen;
                            });
                          },
                        ),
                        const SizedBox(width: 10.0),
                        Text("Filters"),
                        const Spacer(),
                        IconButton(
                          icon: Icon(Symbols.shuffle),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOutCubic,
                  child: SizedBox(
                      height: filtersOpen
                          ? 10.0
                          : MediaQuery.of(context).size.height),
                ),
                Container(
                  height: MediaQuery.of(context).size.height - 200.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [

                    ],
                  ),
                ),
              ],
            ),
          ),*/
          AnimatedPositioned(
            left: 20.0,
            right: 20.0,
            bottom: result == null
                ? 0 - MediaQuery.of(context).size.height
                : MediaQuery.of(context).padding.bottom + 10.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: Align(
              child: Container(
                height: MediaQuery.of(context).size.height / 4,
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width /
                        ResponsiveValue(context,
                            defaultValue: 1,
                            conditionalValues: [
                              const Condition.largerThan(
                                  name: MOBILE, value: 3),
                            ]).value),
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.0),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result?.name ?? "-",
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                result?.formattedAddress ?? "-",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5.0),
                        IconButton(
                          icon: const Icon(Symbols.close),
                          onPressed: _close,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _reRoll,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Symbols.refresh),
                                SizedBox(width: 5.0),
                                Text("Re-roll"),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 5.0),
                        Expanded(
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                  Theme.of(context).colorScheme.primary),
                              foregroundColor: WidgetStatePropertyAll(
                                  Theme.of(context).colorScheme.surface),
                            ),
                            onPressed: _directions,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Symbols.directions,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 5.0),
                                Text("Directions"),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _reset() {
    _mapController.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _center, zoom: zoom),
      ),
    );

    setState(() {
      result = null;
      markers.clear();
      enabledMarkerAlpha.clear();
    });
  }

  _search() {
    setState(() {
      rolling = true;
    });

    Future.delayed(const Duration(seconds: 10), () async {
      setState(() {
        rolling = false;
        result = nearbyPlaces.elementAt(random.nextInt(nearbyPlaces.length));
        markers.add(Marker(
          markerId: MarkerId(result!.id),
          position: result!.location,
          icon: markerWidget!,
        ));
      });

      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
              target:
                  LatLng(result!.location.latitude, result!.location.longitude),
              zoom: 16.0),
        ),
      );
    });
  }

  _roll() async {
    nearbyPlaces = await NearbySearchRestController.searchNearby(
        _center, _circleDiameterInMeters / 2, Localizations.localeOf(context));

    if (nearbyPlaces.isNotEmpty) {
      await _updateNearbyPlacesOffset();
      _search();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No place found in the area!")));
      }
    }
  }

  _reRoll() {
    _reset();
    _search();
  }

  _directions() {
    if (result != null) {
      launchUrlString(result!.directionsUri);
    }
  }

  _close() {
    _reset();

    setState(() {
      nearbyPlaces.clear();
      nearbyPlacesOffset.clear();
    });
  }

  _searchSuffixAction() {
    if (searchFieldController.text.isNotEmpty) {
      setState(() {
        searchFieldController.clear();
        searchPlaces.clear();
      });
    } else {
      GeolocationService.getPosition().then((position) {
        _center = LatLng(position.latitude, position.longitude);
        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _center, zoom: zoom),
          ),
        );
      }).onError((e, trace) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text((e as GeolocationError).message)));
        }
      });
    }
  }

  _searchOnChanged(String value) {
    if (searchFieldFocus.hasFocus) {
      if (value.trim().isNotEmpty) {
        searchFieldDebouncer.run(() async {
          searchPlaces = await PlaceRestController.autocompletePlaces(
              value, Localizations.localeOf(context));
          setState(() {});
        });
      } else {
        searchPlaces.clear();
      }

      setState(() {});
    }
  }

  _onSearchTileTap(Place item) async {
    searchFieldFocus.unfocus();
    searchFieldController.clear();
    searchPlaces.clear();

    setState(() {
      _center = item.location;
      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
              target: LatLng(item.location.latitude, item.location.longitude),
              zoom: zoom),
        ),
      );
    });
  }

  Future<void> _loadMarkerWidget() async {
    markerWidget ??= await Container(
      width: 50.0,
      height: 50.0,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blueAccent,
        gradient: RadialGradient(
          colors: [
            Colors.blueAccent,
            Colors.transparent,
          ],
          center: Alignment.center,
          radius: 1.0,
        ),
      ),
    ).toBitmapDescriptor(
      logicalSize: const Size(50.0, 50.0),
      imageSize: const Size(50.0, 50.0),
    );
  }

  Future<double> _calculateCircleDiameter() async {
    LatLng topPoint = await _getLatLngFromScreenOffset(
      Offset(MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2 - _circleDiameter),
    );

    double distanceInMeters = calculateDistance(
      _center.latitude,
      _center.longitude,
      topPoint.latitude,
      topPoint.longitude,
    );

    return distanceInMeters;
  }

  Future<LatLng> _getLatLngFromScreenOffset(Offset offset) async {
    return _mapController.getLatLng(ScreenCoordinate(
      x: offset.dx.toInt(),
      y: offset.dy.toInt(),
    ));
  }

  Future<Offset?> _getScreenOffsetFromLatLng(LatLng latLng) async {
    final screenCoordinate = await _mapController.getScreenCoordinate(latLng);
    return Offset(screenCoordinate.x.toDouble(), screenCoordinate.y.toDouble());
  }

  Future<void> _updateNearbyPlacesOffset() async {
    for (final nearbyPlace in nearbyPlaces) {
      nearbyPlacesOffset[nearbyPlace.id] =
          (await _getScreenOffsetFromLatLng(nearbyPlace.location))!;
    }
  }

  double getZoomLevel(double radius) {
    double zoomLevel = 11;
    if (radius > 0) {
      double radiusElevated = radius + radius / 2;
      double scale = radiusElevated / 500;
      zoomLevel = 16 - log(scale) / log(2);
    }
    zoomLevel = double.parse(zoomLevel.toStringAsFixed(2));
    return zoomLevel;
  }

  double _getAlphaForPoint(LatLng point) {
    final angle = calculateAngle(
        _center.latitude, _center.longitude, point.latitude, point.longitude);

    final correctMainAngle =
        (radarAnimationController.value + (1 - angle / 360.0)) % 1;
    final baseAngle = correctMainAngle * 360.0;

    double alpha = 0.0;
    if (baseAngle > 0.0 && baseAngle < 200.0) {
      if (baseAngle < 20.0) {
        if (!enabledMarkerAlpha.contains(point)) {
          enabledMarkerAlpha.add(point);
        }
        alpha = baseAngle / 20.0;
      } else if (baseAngle < 200.0) {
        alpha = 1.0 - (baseAngle - 20.0) / 180.0;
      }
    }

    return enabledMarkerAlpha.contains(point) ? alpha : 0.0;
  }
}
