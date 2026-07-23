// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import 'main.dart' show DestinationCandidate, TransitOption, TrasiaColors;

const _mapboxAccessToken =
    'pk.eyJ1IjoiamVlc2hlbiIsImEiOiJjbW9uNGIzYjMwYXg1MnBwc214ZmM0dTFjIn0.VHq4AAucdQxUz865oPSwYg';
const _mapboxStyleUri = mapbox.MapboxStyles.LIGHT;

class AppMapController {
  AppMapController(this.mapboxMap);

  final mapbox.MapboxMap mapboxMap;

  Future<void> flyToCameraPosition(gmaps.CameraPosition position) {
    return mapboxMap.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
            position.target.longitude,
            position.target.latitude,
          ),
        ),
        zoom: position.zoom,
        pitch: position.tilt,
        bearing: position.bearing,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> setCameraPosition(gmaps.CameraPosition position) {
    return mapboxMap.setCamera(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(
            position.target.longitude,
            position.target.latitude,
          ),
        ),
        zoom: position.zoom,
        pitch: position.tilt,
        bearing: position.bearing,
      ),
    );
  }

  Future<void> flyToLatLngZoom(gmaps.LatLng location, double zoom) {
    return mapboxMap.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(
          coordinates: mapbox.Position(location.longitude, location.latitude),
        ),
        zoom: zoom,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> flyToBounds(gmaps.LatLngBounds bounds, double padding) async {
    final camera = await mapboxMap.cameraForCoordinateBounds(
      mapbox.CoordinateBounds(
        southwest: mapbox.Point(
          coordinates: mapbox.Position(
            bounds.southwest.longitude,
            bounds.southwest.latitude,
          ),
        ),
        northeast: mapbox.Point(
          coordinates: mapbox.Position(
            bounds.northeast.longitude,
            bounds.northeast.latitude,
          ),
        ),
        infiniteBounds: true,
      ),
      mapbox.MbxEdgeInsets(
        top: padding,
        left: padding,
        bottom: padding,
        right: padding,
      ),
      null,
      null,
      null,
      null,
    );
    await mapboxMap.flyTo(camera, mapbox.MapAnimationOptions(duration: 1000));
  }
}

class LiveMapboxSurface extends StatefulWidget {
  const LiveMapboxSurface({
    super.key,
    required this.apiKeyReady,
    required this.currentLocation,
    required this.currentAccuracyMeters,
    required this.candidate,
    required this.selectedRoute,
    required this.navigating,
    this.vehicleLocation,
    this.vehicleColor,
    this.initialTarget,
    this.initialZoom,
    this.extraMarkers = const <gmaps.Marker>{},
    this.extraPolylines = const <gmaps.Polyline>{},
    required this.onMapCreated,
    required this.onCameraMove,
  });

  final bool apiKeyReady;
  final gmaps.LatLng? currentLocation;
  final double? currentAccuracyMeters;
  final DestinationCandidate? candidate;
  final TransitOption? selectedRoute;
  final bool navigating;
  final gmaps.LatLng? vehicleLocation;
  final Color? vehicleColor;
  final gmaps.LatLng? initialTarget;
  final double? initialZoom;
  final Set<gmaps.Marker> extraMarkers;
  final Set<gmaps.Polyline> extraPolylines;
  final ValueChanged<AppMapController> onMapCreated;
  final VoidCallback onCameraMove;

  @override
  State<LiveMapboxSurface> createState() => _LiveMapboxSurfaceState();
}

class _LiveMapboxSurfaceState extends State<LiveMapboxSurface> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointManager;
  mapbox.PolylineAnnotationManager? _polylineManager;
  mapbox.CircleAnnotationManager? _circleManager;
  Future<void>? _annotationSetup;
  Future<void> _annotationUpdates = Future<void>.value();
  Future<Uint8List>? _selfMarkerBytes;
  bool _isMapLoaded = false;

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);
  }

  @override
  Widget build(BuildContext context) {
    final target =
        widget.initialTarget ??
        widget.currentLocation ??
        const gmaps.LatLng(3.1478, 101.6953);

    return Stack(
      children: [
        Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              _mapboxMap?.getCameraState().then((cameraState) {
                final zoomDelta = pointerSignal.scrollDelta.dy > 0 ? -0.5 : 0.5;
                _mapboxMap?.setCamera(
                  mapbox.CameraOptions(zoom: cameraState.zoom + zoomDelta),
                );
              });
            }
          },
          child: mapbox.MapWidget(
            key: const ValueKey('mapWidget'),
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(
                coordinates: mapbox.Position(target.longitude, target.latitude),
              ),
              zoom: widget.initialZoom ?? 14.5,
            ),
            styleUri: _mapboxStyleUri,
            onMapCreated: _onMapCreated,
            onCameraChangeListener: (_) => widget.onCameraMove(),
            onStyleLoadedListener: (_) => _markLoaded(),
            onMapLoadedListener: (_) => _markLoaded(),
          ),
        ),
        if (!_isMapLoaded)
          Container(
            color: const Color(0xFFF1F3F4),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await _hideMapOrnaments(mapboxMap);
    widget.onMapCreated(AppMapController(mapboxMap));
  }

  Future<void> _hideMapOrnaments(mapbox.MapboxMap mapboxMap) async {
    await mapboxMap.compass.updateSettings(
      mapbox.CompassSettings(enabled: false, visibility: false),
    );
    await mapboxMap.scaleBar.updateSettings(
      mapbox.ScaleBarSettings(enabled: false),
    );
    await mapboxMap.logo.updateSettings(mapbox.LogoSettings(enabled: false));
    await mapboxMap.attribution.updateSettings(
      mapbox.AttributionSettings(enabled: false, clickable: false),
    );
  }

  void _markLoaded() {
    if (!_isMapLoaded && mounted) {
      setState(() => _isMapLoaded = true);
    }
    _scheduleAnnotationUpdate();
  }

  @override
  void didUpdateWidget(covariant LiveMapboxSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapboxMap != null) {
      _scheduleAnnotationUpdate();
    }
  }

  void _scheduleAnnotationUpdate() {
    _annotationUpdates = _annotationUpdates
        .then((_) async {
          await _ensureAnnotationManagers();
          if (mounted) {
            await _updateAnnotations();
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Map annotation update failed: $error');
        });
  }

  Future<void> _ensureAnnotationManagers() {
    return _annotationSetup ??= _createAnnotationManagers();
  }

  Future<void> _createAnnotationManagers() async {
    final mapboxMap = _mapboxMap;
    if (mapboxMap == null) {
      return;
    }
    _polylineManager = await mapboxMap.annotations
        .createPolylineAnnotationManager();
    _circleManager = await mapboxMap.annotations
        .createCircleAnnotationManager();
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();
  }

  Future<void> _updateAnnotations() async {
    if (_pointManager == null ||
        _polylineManager == null ||
        _circleManager == null) {
      return;
    }

    await _pointManager!.deleteAll();
    await _polylineManager!.deleteAll();
    await _circleManager!.deleteAll();

    for (final polyline in widget.extraPolylines) {
      await _polylineManager!.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(
            coordinates: polyline.points
                .map((p) => mapbox.Position(p.longitude, p.latitude))
                .toList(),
          ),
          lineColor: polyline.color.value,
          lineWidth: polyline.width.toDouble(),
        ),
      );
    }

    final route = widget.selectedRoute;
    if (route != null) {
      for (final leg in route.legs) {
        if (leg.points.isEmpty) {
          continue;
        }
        await _polylineManager!.create(
          mapbox.PolylineAnnotationOptions(
            geometry: mapbox.LineString(
              coordinates: leg.points
                  .map((p) => mapbox.Position(p.longitude, p.latitude))
                  .toList(),
            ),
            lineColor: route.color.value,
            lineWidth: 5.0,
          ),
        );
      }
    }

    if (widget.currentLocation != null) {
      if (widget.currentAccuracyMeters != null &&
          widget.currentAccuracyMeters! > 0) {
        await _createCircle(
          widget.currentLocation!,
          radius: max(16.0, widget.currentAccuracyMeters! * 0.5),
          color: Colors.blue.withValues(alpha: 0.15),
          strokeWidth: 0,
        );
      }
      await _pointManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: _point(widget.currentLocation!),
          image: await _selfMarker(),
          iconSize: 1.0,
        ),
      );
    }

    if (widget.candidate != null) {
      await _createCircle(
        widget.candidate!.location,
        radius: 8,
        color: Colors.red,
        strokeColor: Colors.white,
      );
    }

    if (widget.vehicleLocation != null) {
      await _createCircle(
        widget.vehicleLocation!,
        radius: 8,
        color: widget.vehicleColor ?? Colors.black,
        strokeColor: Colors.white,
      );
    }

    final routePoints =
        widget.selectedRoute?.legs.expand((leg) => leg.points).toList() ??
        const <gmaps.LatLng>[];
    if (routePoints.isNotEmpty) {
      await _createCircle(
        routePoints.first,
        radius: 8,
        color: Colors.green,
        strokeColor: Colors.white,
      );
      await _createCircle(
        routePoints.last,
        radius: 8,
        color: Colors.red,
        strokeColor: Colors.white,
      );
    }

    for (final marker in widget.extraMarkers) {
      final imageBytes = _markerBytes(marker);
      if (imageBytes == null) {
        await _createCircle(
          marker.position,
          radius: 8,
          color: Colors.red,
          strokeColor: Colors.white,
        );
        continue;
      }
      await _pointManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: _point(marker.position),
          image: imageBytes,
          iconSize: 2.5,
        ),
      );
    }
  }

  Future<void> _createCircle(
    gmaps.LatLng location, {
    required double radius,
    required Color color,
    Color? strokeColor,
    double strokeWidth = 2,
  }) {
    return _circleManager!.create(
      mapbox.CircleAnnotationOptions(
        geometry: _point(location),
        circleRadius: radius,
        circleColor: color.value,
        circleStrokeWidth: strokeWidth,
        circleStrokeColor: (strokeColor ?? Colors.transparent).value,
      ),
    );
  }

  mapbox.Point _point(gmaps.LatLng location) {
    return mapbox.Point(
      coordinates: mapbox.Position(location.longitude, location.latitude),
    );
  }

  Future<Uint8List> _selfMarker() {
    return _selfMarkerBytes ??= _drawSelfMarker();
  }

  Future<Uint8List> _drawSelfMarker() async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final shadow = Paint()
      ..color = const Color(0x33001844)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(0, 5), 31, shadow);

    final hood = Paint()..color = TrasiaColors.primary;
    canvas.drawCircle(center, 32, hood);
    canvas.drawCircle(const Offset(27, 25), 12, hood);
    canvas.drawCircle(const Offset(69, 25), 12, hood);

    final face = Paint()..color = const Color(0xFFFFE4C7);
    canvas.drawCircle(center.translate(0, 1), 23, face);

    final eye = Paint()..color = const Color(0xFF102033);
    canvas.drawCircle(const Offset(40, 47), 3.2, eye);
    canvas.drawCircle(const Offset(56, 47), 3.2, eye);

    final smile = Paint()
      ..color = const Color(0xFF102033)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      const Rect.fromLTRB(39, 48, 57, 64),
      .25,
      pi - .5,
      false,
      smile,
    );

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, 34, border);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Uint8List? _markerBytes(gmaps.Marker marker) {
    try {
      final iconJson = marker.icon.toJson() as List<dynamic>;
      if (iconJson.isEmpty) {
        return null;
      }
      if (iconJson[0] == 'bytes') {
        final map = iconJson[1] as Map<dynamic, dynamic>;
        final bytesList = map['byteData'] as List<dynamic>;
        return Uint8List.fromList(bytesList.cast<int>());
      }
      if (iconJson[0] == 'fromBytes') {
        return iconJson[1] as Uint8List;
      }
    } catch (e) {
      debugPrint('Failed to load marker image: $e');
    }
    return null;
  }
}
