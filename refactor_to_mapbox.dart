import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();

  // 1. Imports
  if (!content.contains("import 'mapbox_surface.dart';")) {
    content = content.replaceFirst("import 'package:google_maps_flutter/google_maps_flutter.dart';", "import 'package:google_maps_flutter/google_maps_flutter.dart';\nimport 'mapbox_surface.dart';");
  }

  // 2. ValueNotifier
  content = content.replaceAll(
    'ValueNotifier<GoogleMapController?> globalMapController',
    'ValueNotifier<AppMapController?> globalMapController',
  );

  // 3. State variables
  content = content.replaceAll('GoogleMapController? _mapController;', 'AppMapController? _mapController;');
  content = content.replaceAll('GoogleMapController? get mapController', 'AppMapController? get mapController');
  content = content.replaceAll('final GoogleMapController? mapController;', 'final AppMapController? mapController;');
  content = content.replaceAll('void _onMapCreated(GoogleMapController controller)', 'void _onMapCreated(AppMapController controller)');

  // 4. animateCamera -> newLatLngZoom
  content = content.replaceAllMapped(
    RegExp(r'await (.*?)animateCamera\(\s*CameraUpdate\.newLatLngZoom\((.*?),\s*(.*?)\),\s*\);', multiLine: true),
    (match) {
      return 'await ${match.group(1)}flyToLatLngZoom(${match.group(2)}, ${match.group(3)});';
    },
  );

  // 5. animateCamera -> newCameraPosition
  content = content.replaceAllMapped(
    RegExp(r'(.*?)animateCamera\(\s*CameraUpdate\.newCameraPosition\(\s*(CameraPosition\([^;]*?\)),\s*\),\s*\);', multiLine: true, dotAll: true),
    (match) {
      return '${match.group(1)}flyToCameraPosition(\n${match.group(2)}\n);';
    },
  );

  // 6. animateCamera -> newLatLngBounds
  content = content.replaceAllMapped(
    RegExp(r'await (.*?)animateCamera\(\s*CameraUpdate\.newLatLngBounds\(\s*(LatLngBounds\([\s\S]*?\)),\s*([0-9.]+),\s*\),\s*\);', multiLine: true),
    (match) {
      return 'await ${match.group(1)}flyToBounds(\n${match.group(2)},\n${match.group(3)}\n);';
    },
  );

  // 7. _LiveGoogleMapSurface -> LiveMapboxSurface
  content = content.replaceAll('_LiveGoogleMapSurface(', 'LiveMapboxSurface(');

  file.writeAsStringSync(content);
  print('Refactored lib/main.dart for Mapbox migration!');
}
