import 'dart:io';

void main() {
  final file = File('lib/mapbox_surface.dart');
  var content = file.readAsStringSync();

  final regex = RegExp(r'void _updateAnnotations\(\) async \{.*?\n\}', dotAll: true);
  
  final replacement = '''void _updateAnnotations() async {
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
        print('Failed to load marker image: \$e');
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
  }''';

  content = content.replaceFirst(regex, replacement);
  file.writeAsStringSync(content);
}
