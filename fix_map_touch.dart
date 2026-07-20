import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync().replaceAll('\r\n', '\n');

  // 1. Remove map from MaterialApp builder
  final builderRegex = RegExp(r'builder:\s*\(\s*context,\s*child\s*\)\s*\{\s*return\s*Stack\(\s*children:\s*\[\s*ValueListenableBuilder<SharedMapView>\(\s*valueListenable:\s*globalMapViewNotifier,\s*builder:\s*\(\s*context,\s*view,\s*_\s*\)\s*\{\s*return\s*_LiveGoogleMapSurface\([\s\S]*?onCameraMove:\s*\(_\)\s*\{\},\s*\);\s*\},\s*\),\s*if\s*\(child\s*!=\s*null\)\s*child,\s*\],\s*\);\s*\},');
  
  if (!builderRegex.hasMatch(content)) {
    print("Could not find MaterialApp builder");
    return;
  }
  
  content = content.replaceFirst(builderRegex, '/* builder removed */');

  // 2. Put map back into _DashboardScreenState
  final dashboardStackRegex = RegExp(r'body:\s*Stack\(\s*fit:\s*StackFit.expand,\s*children:\s*\[');
  if (!dashboardStackRegex.hasMatch(content)) {
    print("Could not find DashboardScreen Stack");
    return;
  }
  
  final mapInsertion = '''body: Stack(
        fit: StackFit.expand,
        children: [
          if (_tab != 3)
            ValueListenableBuilder<SharedMapView>(
              valueListenable: globalMapViewNotifier,
              builder: (context, view, _) {
                return _LiveGoogleMapSurface(
                  apiKeyReady: _GoogleMapsConfig.isReady,
                  currentLocation: view.currentLocation,
                  currentAccuracyMeters: view.currentAccuracyMeters,
                  candidate: view.candidate,
                  selectedRoute: view.selectedRoute,
                  navigating: view.navigating,
                  vehicleLocation: view.vehicleLocation,
                  vehicleColor: view.vehicleColor,
                  initialTarget: view.initialTarget,
                  initialZoom: view.initialZoom,
                  extraMarkers: view.extraMarkers,
                  extraPolylines: view.extraPolylines,
                  onMapCreated: (controller) {
                    globalMapController.value = controller;
                  },
                  onCameraMove: (position) {
                    // Update last center if needed by active tabs
                  },
                );
              },
            ),''';
  
  content = content.replaceFirst(dashboardStackRegex, mapInsertion);
  
  file.writeAsStringSync(content);
  print('Successfully restored map position in tree to fix touch events!');
}
