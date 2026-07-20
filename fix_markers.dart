import 'dart:io';

void main() {
  final file = File('lib/mapbox_surface.dart');
  var content = file.readAsStringSync();

  // Replace the extraMarkers block
  final regex = RegExp(r'for \(final marker in widget\.extraMarkers\) \{\s*await _circleManager!\.create\(\s*mapbox\.CircleAnnotationOptions\(\s*geometry: mapbox\.Point\(coordinates: mapbox\.Position\(marker\.position\.longitude, marker\.position\.latitude\)\),\s*circleRadius: 6\.0,\s*circleColor: Colors\.red\.value,\s*\)\s*\);\s*\}');
  
  final replacement = '''
    // Load custom markers from Google Maps BitmapDescriptor
    for (final marker in widget.extraMarkers) {
      String? imageId;
      try {
        final iconJson = marker.icon.toJson() as List<dynamic>;
        if (iconJson.isNotEmpty) {
          if (iconJson[0] == \\'bytes\\') {
            final map = iconJson[1] as Map<dynamic, dynamic>;
            final bytesList = map[\\'byteData\\'] as List<dynamic>;
            final bytes = Uint8List.fromList(bytesList.cast<int>());
            imageId = marker.markerId.value;
            await _mapboxMap!.style.addStyleImage(
              imageId,
              1.0,
              mapbox.MbxImage(width: 108, height: 108, data: bytes),
              false,
              [],
              [],
              null,
            );
          } else if (iconJson[0] == \\'fromBytes\\') {
            final bytes = iconJson[1] as Uint8List;
            imageId = marker.markerId.value;
            await _mapboxMap!.style.addStyleImage(
              imageId,
              1.0,
              mapbox.MbxImage(width: 108, height: 108, data: bytes),
              false,
              [],
              [],
              null,
            );
          }
        }
      } catch (e) {
        print(\\'Failed to load marker image: \\\');
      }

      if (imageId != null) {
        await _pointManager!.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(marker.position.longitude, marker.position.latitude)),
            image: imageId,
            iconSize: 1.0,
          )
        );
      } else {
        // Fallback to circle
        await _circleManager!.create(
          mapbox.CircleAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(marker.position.longitude, marker.position.latitude)),
            circleRadius: 8.0,
            circleColor: Colors.red.value,
          )
        );
      }
    }
''';

  content = content.replaceAll(regex, replacement);
  file.writeAsStringSync(content);
}
