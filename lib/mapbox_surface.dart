import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'loading_compass.dart';
import 'main.dart' show DestinationCandidate, TransitOption, TrasiaColors;
const _mapboxAccessToken =
    'pk.eyJ1IjoiamVlc2hlbiIsImEiOiJjbW9uNGIzYjMwYXg1MnBwc214ZmM0dTFjIn0.VHq4AAucdQxUz865oPSwYg';
const _mapboxStyleUri = mapbox.MapboxStyles.LIGHT;
Color routeModeColor(String mode) {
  final value = mode.toLowerCase();
  if (value.contains('walk')) {
    return const Color(0xFF168BFF);
  }
  if (value.contains('bus') || value.contains('feeder')) {
    return const Color(0xFFFF8A00);
  }
  if (value.contains('ktm') ||
      value.contains('ets') ||
      value.contains('komuter') ||
      value.contains('train')) {
    return const Color(0xFFE53935);
  }
  if (value.contains('mrt') ||
      value.contains('lrt') ||
      value.contains('subway') ||
      value.contains('metro') ||
      value.contains('monorail') ||
      value.contains('rapid rail') ||
      value.contains('rail')) {
    return const Color(0xFF7C4DFF);
  }
  if (value.contains('drive') || value.contains('car')) {
    return const Color(0xFF00A86B);
  }
  if (value.contains('ferry') || value.contains('boat')) {
    return const Color(0xFF00A6B2);
  }
  if (value.contains('cycle') || value.contains('bike')) {
    return const Color(0xFF16A085);
  }
  return const Color(0xFF5B78D6);
}
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
  Future<void> easeToCameraPosition(
    gmaps.CameraPosition position, {
    int durationMs = 240,
  }) {
    return mapboxMap.easeTo(
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
      mapbox.MapAnimationOptions(duration: durationMs),
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
    required this.mapRefreshRevision,
    required this.navigating,
    this.vehicleLocation,
    this.vehicleColor,
    this.vehicleBearing = 0,
    this.routeProgress,
    this.showCurrentLocationMarker = true,
    this.showRouteEndpoints = true,
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
  final int mapRefreshRevision;
  final bool navigating;
  final gmaps.LatLng? vehicleLocation;
  final Color? vehicleColor;
  final double vehicleBearing;
  final double? routeProgress;
  final bool showCurrentLocationMarker;
  final bool showRouteEndpoints;
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
  mapbox.PointAnnotationManager? _vehiclePointManager;
  mapbox.PolylineAnnotationManager? _polylineManager;
  mapbox.CircleAnnotationManager? _circleManager;
  mapbox.PointAnnotation? _vehicleAnnotation;
  final List<mapbox.PolylineAnnotation> _routeAnnotations = [];
  mapbox.Cancelable? _pointTapEvents;
  final Map<String, VoidCallback> _pointTapCallbacks = {};
  Future<void>? _annotationSetup;
  bool _annotationUpdateRunning = false;
  bool _annotationUpdateRequested = false;
  bool _vehicleUpdateRunning = false;
  bool _vehicleUpdateRequested = false;
  bool _routeProgressUpdateRunning = false;
  bool _routeProgressUpdateRequested = false;
  Future<Uint8List>? _selfMarkerBytes;
  Future<Uint8List>? _destinationMarkerBytes;
  final Map<int, Future<Uint8List>> _transferMarkerBytes = {};
  final Map<int, Future<Uint8List>> _vehicleMarkerBytes = {};
  bool _isMapLoaded = false;
  bool _isMapboxInitialized = false;
  @override
  void initState() {
    super.initState();
    _initMapbox();
  }
  Future<void> _initMapbox() async {
    mapbox.LogConfiguration.registerLogWriterBackend(SilentLogBackend());
    await mapbox.MapboxOptions.setAccessToken(_mapboxAccessToken);
    if (mounted) {
      setState(() => _isMapboxInitialized = true);
    }
  }
  @override
  void dispose() {
    _pointTapEvents?.cancel();
    _pointTapCallbacks.clear();
    super.dispose();
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
          child: _isMapboxInitialized
              ? mapbox.MapWidget(
                  key: const ValueKey('mapWidget'),
                  textureView: true,
                  cameraOptions: mapbox.CameraOptions(
                    center: mapbox.Point(
                      coordinates: mapbox.Position(
                        target.longitude,
                        target.latitude,
                      ),
                    ),
                    zoom: widget.initialZoom ?? 14.5,
                  ),
                  styleUri: _mapboxStyleUri,
                  onMapCreated: _onMapCreated,
                  onCameraChangeListener: (_) => widget.onCameraMove(),
                  onStyleLoadedListener: (_) => _markLoaded(),
                  onMapLoadedListener: (_) => _markLoaded(),
                )
              : const SizedBox.shrink(),
        ),
        if (!_isMapLoaded)
          Container(
            color: const Color(0xFFF1F3F4),
            child: const Center(
              child: TrasiaLoadingCompass(
                key: ValueKey('map-loading-compass'),
                size: 80,
                semanticLabel: 'Loading map',
              ),
            ),
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
    _scheduleVehicleUpdate();
  }
  @override
  void didUpdateWidget(covariant LiveMapboxSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapboxMap == null) {
      return;
    }
    if (_staticMapContentChanged(oldWidget)) {
      _scheduleAnnotationUpdate();
    }
    if (oldWidget.vehicleLocation != widget.vehicleLocation ||
        oldWidget.vehicleColor != widget.vehicleColor ||
        oldWidget.vehicleBearing != widget.vehicleBearing ||
        oldWidget.mapRefreshRevision != widget.mapRefreshRevision) {
      _scheduleVehicleUpdate();
    }
    if (oldWidget.routeProgress != widget.routeProgress) {
      _scheduleRouteProgressUpdate();
    }
  }
  bool _staticMapContentChanged(LiveMapboxSurface oldWidget) {
    return oldWidget.currentLocation != widget.currentLocation ||
        oldWidget.currentAccuracyMeters != widget.currentAccuracyMeters ||
        oldWidget.candidate != widget.candidate ||
        !identical(oldWidget.selectedRoute, widget.selectedRoute) ||
        oldWidget.mapRefreshRevision != widget.mapRefreshRevision ||
        oldWidget.navigating != widget.navigating ||
        oldWidget.showCurrentLocationMarker !=
            widget.showCurrentLocationMarker ||
        oldWidget.showRouteEndpoints != widget.showRouteEndpoints ||
        !identical(oldWidget.extraMarkers, widget.extraMarkers) ||
        !identical(oldWidget.extraPolylines, widget.extraPolylines);
  }
  void _scheduleAnnotationUpdate() {
    _annotationUpdateRequested = true;
    if (_annotationUpdateRunning) {
      return;
    }
    _annotationUpdateRunning = true;
    unawaited(_drainAnnotationUpdates());
  }
  Future<void> _drainAnnotationUpdates() async {
    while (mounted && _annotationUpdateRequested) {
      _annotationUpdateRequested = false;
      try {
        await _ensureAnnotationManagers();
        if (mounted) {
          await _updateAnnotations();
        }
      } catch (error) {
        debugPrint('Map annotation update failed: $error');
      }
    }
    _annotationUpdateRunning = false;
    if (mounted && _annotationUpdateRequested) {
      _scheduleAnnotationUpdate();
    }
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
    await _pointManager!.setIconAllowOverlap(true);
    await _pointManager!.setIconIgnorePlacement(true);
    _vehiclePointManager = await mapboxMap.annotations
        .createPointAnnotationManager();
    await _vehiclePointManager!.setIconAllowOverlap(true);
    await _vehiclePointManager!.setIconIgnorePlacement(true);
    await _vehiclePointManager!.setIconRotationAlignment(
      mapbox.IconRotationAlignment.MAP,
    );
    _pointTapEvents?.cancel();
    _pointTapEvents = _pointManager!.tapEvents(
      onTap: (annotation) {
        _pointTapCallbacks[annotation.id]?.call();
      },
    );
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
    _routeAnnotations.clear();
    _pointTapCallbacks.clear();
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
        final annotation = await _polylineManager!.create(
          mapbox.PolylineAnnotationOptions(
            geometry: mapbox.LineString(
              coordinates: leg.points
                  .map((p) => mapbox.Position(p.longitude, p.latitude))
                  .toList(),
            ),
            lineColor: routeModeColor(leg.mode).value,
            lineWidth: 5.0,
          ),
        );
        _routeAnnotations.add(annotation);
      }
      for (var index = 1; index < route.legs.length; index++) {
        final previous = route.legs[index - 1];
        final current = route.legs[index];
        final transferLocation = current.points.isNotEmpty
            ? current.points.first
            : previous.points.isNotEmpty
            ? previous.points.last
            : null;
        if (transferLocation != null) {
          await _createTransferMarker(
            transferLocation,
            routeModeColor(current.mode),
          );
        }
      }
    }
    if (widget.currentLocation != null && widget.showCurrentLocationMarker) {
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
          iconSize: 0.9,
        ),
      );
    }
    final routePoints =
        widget.selectedRoute?.legs.expand((leg) => leg.points).toList() ??
        const <gmaps.LatLng>[];
    if (widget.candidate != null) {
      await _createDestinationMarker(widget.candidate!.location);
    }
    if (routePoints.isNotEmpty && widget.showRouteEndpoints) {
      await _createCircle(
        routePoints.first,
        radius: 8,
        color: Colors.green,
        strokeColor: Colors.white,
      );
      if (widget.candidate == null) {
        await _createDestinationMarker(routePoints.last);
      }
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
      final annotation = await _pointManager!.create(
        mapbox.PointAnnotationOptions(
          geometry: _point(marker.position),
          image: imageBytes,
          iconSize: 2.5,
        ),
      );
      final onTap = marker.onTap;
      if (onTap != null) {
        _pointTapCallbacks[annotation.id] = onTap;
      }
    }
    _scheduleRouteProgressUpdate();
    _scheduleVehicleUpdate();
  }
  void _scheduleRouteProgressUpdate() {
    _routeProgressUpdateRequested = true;
    if (_routeProgressUpdateRunning) {
      return;
    }
    _routeProgressUpdateRunning = true;
    unawaited(_drainRouteProgressUpdates());
  }
  Future<void> _drainRouteProgressUpdates() async {
    while (mounted && _routeProgressUpdateRequested) {
      _routeProgressUpdateRequested = false;
      try {
        await _ensureAnnotationManagers();
        if (mounted) {
          await _updateRouteProgress();
        }
      } catch (error) {
        debugPrint('Route progress update failed: $error');
      }
    }
    _routeProgressUpdateRunning = false;
    if (mounted && _routeProgressUpdateRequested) {
      _scheduleRouteProgressUpdate();
    }
  }
  Future<void> _updateRouteProgress() async {
    final manager = _polylineManager;
    final route = widget.selectedRoute;
    final progress = widget.routeProgress;
    if (manager == null ||
        route == null ||
        progress == null ||
        _routeAnnotations.isEmpty) {
      return;
    }
    final legs = route.legs.where((leg) => leg.points.isNotEmpty).toList();
    final count = min(legs.length, _routeAnnotations.length);
    for (var i = 0; i < count; i++) {
      final remaining = _remainingRoutePoints(legs[i].points, progress);
      final annotation = _routeAnnotations[i];
      annotation.geometry = mapbox.LineString(
        coordinates: remaining
            .map((point) => mapbox.Position(point.longitude, point.latitude))
            .toList(),
      );
      await manager.update(annotation);
    }
  }
  void _scheduleVehicleUpdate() {
    _vehicleUpdateRequested = true;
    if (_vehicleUpdateRunning) {
      return;
    }
    _vehicleUpdateRunning = true;
    unawaited(_drainVehicleUpdates());
  }
  Future<void> _drainVehicleUpdates() async {
    while (mounted && _vehicleUpdateRequested) {
      _vehicleUpdateRequested = false;
      try {
        await _ensureAnnotationManagers();
        if (mounted) {
          await _updateVehicleAnnotation();
        }
      } catch (error) {
        debugPrint('Vehicle annotation update failed: $error');
      }
    }
    _vehicleUpdateRunning = false;
    if (mounted && _vehicleUpdateRequested) {
      _scheduleVehicleUpdate();
    }
  }
  Future<void> _updateVehicleAnnotation() async {
    final manager = _vehiclePointManager;
    if (manager == null) {
      return;
    }
    final location = widget.vehicleLocation;
    if (location == null) {
      final annotation = _vehicleAnnotation;
      if (annotation != null) {
        await manager.delete(annotation);
        _vehicleAnnotation = null;
      }
      return;
    }
    final image = await _vehicleMarker(widget.vehicleColor ?? Colors.black);
    final annotation = _vehicleAnnotation;
    if (annotation == null) {
      _vehicleAnnotation = await manager.create(
        mapbox.PointAnnotationOptions(
          geometry: _point(location),
          image: image,
          iconSize: .62,
          iconRotate: widget.vehicleBearing,
        ),
      );
      return;
    }
    annotation
      ..geometry = _point(location)
      ..image = image
      ..iconSize = .62
      ..iconRotate = widget.vehicleBearing;
    await manager.update(annotation);
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
  Future<void> _createDestinationMarker(gmaps.LatLng location) async {
    await _pointManager!.create(
      mapbox.PointAnnotationOptions(
        geometry: _point(location),
        image: await _destinationMarker(),
        iconAnchor: mapbox.IconAnchor.BOTTOM,
        iconSize: .78,
        symbolSortKey: 100,
      ),
    );
  }
  Future<void> _createTransferMarker(gmaps.LatLng location, Color color) async {
    await _pointManager!.create(
      mapbox.PointAnnotationOptions(
        geometry: _point(location),
        image: await _transferMarker(color),
        iconAnchor: mapbox.IconAnchor.BOTTOM,
        iconSize: .58,
        symbolSortKey: 80,
      ),
    );
  }
  mapbox.Point _point(gmaps.LatLng location) {
    return mapbox.Point(
      coordinates: mapbox.Position(location.longitude, location.latitude),
    );
  }
  List<gmaps.LatLng> _remainingRoutePoints(
    List<gmaps.LatLng> points,
    double progress,
  ) {
    if (points.length < 2) {
      return points;
    }
    final currentProgress = progress.clamp(0, 1).toDouble();
    final segmentLengths = <double>[];
    var totalMeters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = _mapDistanceMeters(points[i], points[i + 1]);
      segmentLengths.add(length);
      totalMeters += length;
    }
    if (totalMeters == 0) {
      return [points.last, points.last];
    }
    var travelledMeters = totalMeters * currentProgress;
    var segmentIndex = 0;
    while (segmentIndex < segmentLengths.length - 1 &&
        travelledMeters > segmentLengths[segmentIndex]) {
      travelledMeters -= segmentLengths[segmentIndex];
      segmentIndex++;
    }
    final from = points[segmentIndex];
    final to = points[segmentIndex + 1];
    final segmentLength = segmentLengths[segmentIndex];
    final segmentProgress = segmentLength == 0
        ? 0.0
        : (travelledMeters / segmentLength).clamp(0, 1).toDouble();
    final current = gmaps.LatLng(
      from.latitude + (to.latitude - from.latitude) * segmentProgress,
      from.longitude + (to.longitude - from.longitude) * segmentProgress,
    );
    return [current, ...points.skip(segmentIndex + 1)];
  }
  double _mapDistanceMeters(gmaps.LatLng from, gmaps.LatLng to) {
    const earthRadiusMeters = 6371000.0;
    final fromLatitude = from.latitude * pi / 180;
    final toLatitude = to.latitude * pi / 180;
    final latitudeDelta = (to.latitude - from.latitude) * pi / 180;
    final longitudeDelta = (to.longitude - from.longitude) * pi / 180;
    final a =
        sin(latitudeDelta / 2) * sin(latitudeDelta / 2) +
        cos(fromLatitude) *
            cos(toLatitude) *
            sin(longitudeDelta / 2) *
            sin(longitudeDelta / 2);
    return earthRadiusMeters * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  Future<Uint8List> _selfMarker() {
    return _selfMarkerBytes ??= _drawSelfMarker();
  }
  Future<Uint8List> _destinationMarker() {
    return _destinationMarkerBytes ??= _drawDestinationMarker();
  }
  Future<Uint8List> _transferMarker(Color color) {
    return _transferMarkerBytes.putIfAbsent(
      color.value,
      () => _drawTransferMarker(color),
    );
  }
  Future<Uint8List> _vehicleMarker(Color color) {
    return _vehicleMarkerBytes.putIfAbsent(
      color.value,
      () => _drawVehicleMarker(color),
    );
  }
  Future<Uint8List> _drawVehicleMarker(Color color) async {
    const size = 112.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final shadow = Paint()
      ..color = const Color(0x44001844)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, 16, 58, 84).shift(const Offset(0, 4)),
        const Radius.circular(24),
      ),
      shadow,
    );
    final tirePaint = Paint()..color = const Color(0xFF17202A);
    for (final rect in const [
      Rect.fromLTWH(20, 35, 10, 22),
      Rect.fromLTWH(82, 35, 10, 22),
      Rect.fromLTWH(20, 70, 10, 22),
      Rect.fromLTWH(82, 70, 10, 22),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        tirePaint,
      );
    }
    final body = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(26, 12, 60, 88),
        const Radius.circular(25),
      ),
      body,
    );
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(29, 15, 54, 82),
        const Radius.circular(22),
      ),
      highlight,
    );
    final glass = Paint()..color = const Color(0xFF1E3950);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 31, 44, 25),
        const Radius.circular(8),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(36, 65, 40, 18),
        const Radius.circular(7),
      ),
      glass,
    );
    final glassShine = Paint()..color = const Color(0xFF8ED8F8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(39, 35, 8, 17),
        const Radius.circular(4),
      ),
      glassShine,
    );
    final light = Paint()..color = const Color(0xFFFFF3A3);
    canvas.drawCircle(const Offset(39, 20), 5, light);
    canvas.drawCircle(const Offset(73, 20), 5, light);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
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
  Future<Uint8List> _drawDestinationMarker() async {
    const width = 96.0;
    const height = 120.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final markerPath = Path()
      ..moveTo(48, 109)
      ..cubicTo(43, 99, 14, 72, 14, 45)
      ..cubicTo(14, 24, 29, 9, 48, 9)
      ..cubicTo(67, 9, 82, 24, 82, 45)
      ..cubicTo(82, 72, 53, 99, 48, 109)
      ..close();
    final shadow = Paint()
      ..color = const Color(0x44001844)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(markerPath, shadow);
    canvas.restore();
    canvas.drawPath(markerPath, Paint()..color = const Color(0xFFE53935));
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(markerPath, border);
    canvas.drawCircle(const Offset(48, 44), 14, Paint()..color = Colors.white);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
  Future<Uint8List> _drawTransferMarker(Color color) async {
    const width = 64.0;
    const height = 80.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final markerPath = Path()
      ..moveTo(32, 74)
      ..cubicTo(28, 66, 9, 48, 9, 30)
      ..cubicTo(9, 15, 19, 5, 32, 5)
      ..cubicTo(45, 5, 55, 15, 55, 30)
      ..cubicTo(55, 48, 36, 66, 32, 74)
      ..close();
    final shadow = Paint()
      ..color = const Color(0x44001844)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4);
    canvas.save();
    canvas.translate(0, 3);
    canvas.drawPath(markerPath, shadow);
    canvas.restore();
    canvas.drawPath(markerPath, Paint()..color = color);
    canvas.drawPath(
      markerPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(const Offset(32, 29), 8, Paint()..color = Colors.white);
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
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
class SilentLogBackend extends mapbox.LogWriterBackend {
  @override
  void writeLog(mapbox.LoggingLevel level, String message) {
  }
}
