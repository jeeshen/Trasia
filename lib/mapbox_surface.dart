import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:flutter/gestures.dart';
import 'main.dart' show DestinationCandidate, TransitOption, RouteLeg;

class AppMapController {
  final mapbox.MapboxMap mapboxMap;
  AppMapController(this.mapboxMap);

  Future<void> flyToCameraPosition(gmaps.CameraPosition position) async {
    await mapboxMap.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(position.target.longitude, position.target.latitude)),
        zoom: position.zoom,
        pitch: position.tilt,
        bearing: position.bearing,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> setCameraPosition(gmaps.CameraPosition position) async {
    await mapboxMap.setCamera(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(position.target.longitude, position.target.latitude)),
        zoom: position.zoom,
        pitch: position.tilt,
        bearing: position.bearing,
      ),
    );
  }

  Future<void> flyToLatLngZoom(gmaps.LatLng location, double zoom) async {
    await mapboxMap.flyTo(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(location.longitude, location.latitude)),
        zoom: zoom,
      ),
      mapbox.MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> flyToBounds(gmaps.LatLngBounds bounds, double padding) async {
    final camera = await mapboxMap.cameraForCoordinateBounds(
      mapbox.CoordinateBounds(
        southwest: mapbox.Point(coordinates: mapbox.Position(bounds.southwest.longitude, bounds.southwest.latitude)),
        northeast: mapbox.Point(coordinates: mapbox.Position(bounds.northeast.longitude, bounds.northeast.latitude)),
        infiniteBounds: true,
      ),
      mapbox.MbxEdgeInsets(top: padding, left: padding, bottom: padding, right: padding),
      null, null, null, null);
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
  bool _isMapLoaded = false;

  @override
  void initState() {
    super.initState();
    mapbox.MapboxOptions.setAccessToken('pk.eyJ1IjoiamVlc2hlbiIsImEiOiJjbW9uNGIzYjMwYXg1MnBwc214ZmM0dTFjIn0.VHq4AAucdQxUz865oPSwYg');
  }

  @override
  Widget build(BuildContext context) {
    // Removed apiKeyReady wait as Mapbox uses its own token and can initialize immediately.

    final target = widget.initialTarget ?? widget.currentLocation ?? const gmaps.LatLng(3.1478, 101.6953);

    return Stack(
      children: [
        Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              if (_mapboxMap != null) {
                _mapboxMap!.getCameraState().then((cameraState) {
                  final zoomDelta = pointerSignal.scrollDelta.dy > 0 ? -0.5 : 0.5;
                  _mapboxMap!.setCamera(
                    mapbox.CameraOptions(
                      zoom: cameraState.zoom + zoomDelta,
                    ),
                  );
                });
              }
            }
          },
          child: mapbox.MapWidget(
            key: const ValueKey('mapWidget'),
            
            cameraOptions: mapbox.CameraOptions(
              center: mapbox.Point(coordinates: mapbox.Position(target.longitude, target.latitude)),
              zoom: widget.initialZoom ?? 14.5,
            ),
            styleUri: mapbox.MapboxStyles.LIGHT,
            onMapCreated: _onMapCreated,
            onCameraChangeListener: (cameraChangedEventData) {
              widget.onCameraMove();
            },
            onStyleLoadedListener: (styleLoadedEventData) {
              if (!_isMapLoaded && mounted) {
                setState(() {
                  _isMapLoaded = true;
                });
              }
            },
            onMapLoadedListener: (mapLoadedEventData) {
              if (!_isMapLoaded && mounted) {
                setState(() {
                  _isMapLoaded = true;
                });
              }
            },
          ),
        ),
        if (!_isMapLoaded)
          Container(
            color: const Color(0xFFF1F3F4), // Light map background color
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    
    // Create annotation managers in order of z-index (bottom to top)
    _polylineManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    _circleManager = await mapboxMap.annotations.createCircleAnnotationManager();
    _pointManager = await mapboxMap.annotations.createPointAnnotationManager();

    widget.onMapCreated(AppMapController(mapboxMap));
    
    _updateAnnotations();
  }

  @override
  void didUpdateWidget(covariant LiveMapboxSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_mapboxMap != null) {
      _updateAnnotations();
    }
  }

  void _updateAnnotations() async {
    if (_pointManager == null || _polylineManager == null || _circleManager == null) return;

    // Clear existing
    await _pointManager!.deleteAll();
    await _polylineManager!.deleteAll();
    await _circleManager!.deleteAll();

    // 1. Polylines (Rendered first, so they are at the bottom)
    for (final polyline in widget.extraPolylines) {
      await _polylineManager!.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: polyline.points.map((p) => mapbox.Position(p.longitude, p.latitude)).toList()),
          lineColor: polyline.color.value,
          lineWidth: polyline.width.toDouble(),
        )
      );
    }
    
    if (widget.selectedRoute != null) {
      for (final leg in widget.selectedRoute!.legs) {
        if (leg.points.isNotEmpty) {
          await _polylineManager!.create(
            mapbox.PolylineAnnotationOptions(
              geometry: mapbox.LineString(coordinates: leg.points.map((p) => mapbox.Position(p.longitude, p.latitude)).toList()),
              lineColor: widget.selectedRoute!.color.value,
              lineWidth: 5.0,
            )
          );
        }
      }
    }

    // 2. Circles (Rendered in the middle)
    if (widget.currentLocation != null) {
      await _circleManager!.create(
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(widget.currentLocation!.longitude, widget.currentLocation!.latitude)),
          circleRadius: 8.0,
          circleColor: Colors.blue.value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        )
      );
      if (widget.currentAccuracyMeters != null && widget.currentAccuracyMeters! > 0) {
        await _circleManager!.create(
          mapbox.CircleAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(widget.currentLocation!.longitude, widget.currentLocation!.latitude)),
            circleRadius: max(16.0, widget.currentAccuracyMeters! * 0.5), // Approximate radius
            circleColor: Colors.blue.withOpacity(0.15).value,
            circleStrokeWidth: 0.0,
          )
        );
      }
    }

    if (widget.candidate != null) {
      await _circleManager!.create(
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(widget.candidate!.location.longitude, widget.candidate!.location.latitude)),
          circleRadius: 8.0,
          circleColor: Colors.red.value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        )
      );
    }

    if (widget.vehicleLocation != null) {
      await _circleManager!.create(
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(widget.vehicleLocation!.longitude, widget.vehicleLocation!.latitude)),
          circleRadius: 8.0,
          circleColor: (widget.vehicleColor ?? Colors.black).value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        )
      );
    }
    
    if (widget.selectedRoute != null && widget.selectedRoute!.legs.isNotEmpty) {
      final firstPoint = widget.selectedRoute!.legs.first.points.first;
      final lastPoint = widget.selectedRoute!.legs.last.points.last;
      
      // Start point (Green)
      await _circleManager!.create(
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(firstPoint.longitude, firstPoint.latitude)),
          circleRadius: 8.0,
          circleColor: Colors.green.value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        )
      );
      
      // End point (Red)
      await _circleManager!.create(
        mapbox.CircleAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(lastPoint.longitude, lastPoint.latitude)),
          circleRadius: 8.0,
          circleColor: Colors.red.value,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.value,
        )
      );
    }

    // 3. Points (Markers, Rendered last so they are on top)
    for (final marker in widget.extraMarkers) {
      Uint8List? imageBytes;
      try {
        final iconJson = marker.icon.toJson() as List<dynamic>;
        if (iconJson.isNotEmpty) {
          if (iconJson[0] == 'bytes') {
            final map = iconJson[1] as Map<dynamic, dynamic>;
            final bytesList = map['byteData'] as List<dynamic>;
            imageBytes = Uint8List.fromList(bytesList.cast<int>());
          } else if (iconJson[0] == 'fromBytes') {
            imageBytes = iconJson[1] as Uint8List;
          }
        }
      } catch (e) {
        print('Failed to load marker image: $e');
      }

      if (imageBytes != null) {
        await _pointManager!.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(marker.position.longitude, marker.position.latitude)),
            image: imageBytes,
            iconSize: 2.5, // Increased size for visibility
          )
        );
      } else {
        // Fallback to circle
        await _circleManager!.create(
          mapbox.CircleAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(marker.position.longitude, marker.position.latitude)),
            circleRadius: 8.0,
            circleColor: Colors.red.value,
            circleStrokeWidth: 2.0,
            circleStrokeColor: Colors.white.value,
          )
        );
      }
    }
  }
}
