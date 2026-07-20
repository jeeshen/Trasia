import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();

  // 1. Fix globalMapController
  content = content.replaceAll(
    'final globalMapController = ValueNotifier<GoogleMapController?>(null);',
    'final globalMapController = ValueNotifier<AppMapController?>(null);'
  );

  // 2. Fix TransitRouterScreen constructor mapController type
  content = content.replaceAll(
    'final GoogleMapController? mapController;',
    'final AppMapController? mapController;'
  );

  // 3. Fix HubPoolScreen and PelancongPlanScreen
  // (We'll just globally replace GoogleMapController with AppMapController where appropriate)
  content = content.replaceAll(
    'final GoogleMapController? mapController;',
    'final AppMapController? mapController;'
  );

  // 4. Fix animateCamera syntax errors
  content = content.replaceAll(
    '''    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: start,
          zoom: 17.5,
          tilt: 0.0,
          bearing: bearing,
        ),
      ),
    );''',
    '''    _mapController!.flyToCameraPosition(CameraPosition(target: start, zoom: 17.5, tilt: 0.0, bearing: bearing));'''
  );

  content = content.replaceAll(
    '''    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentLocation!,
            zoom: 15.0,
            tilt: 0.0,
            bearing: 0.0,
          ),
        ),
      );
    }''',
    '''    if (_currentLocation != null && _mapController != null) {
      _mapController!.flyToCameraPosition(CameraPosition(target: _currentLocation!, zoom: 15.0, tilt: 0.0, bearing: 0.0));
    }'''
  );
  
  // Fix weird syntax error at 1115
  // It's probably because of my PowerShell replace ruining a line.
  content = content.replaceAll(
    'await _mapController?.flyToLatLngZoom(location, 17);',
    'await _mapController?.flyToLatLngZoom(location, 17.0);'
  );

  // Re-fix the void Function(dynamic) error (onMapCreated)
  content = content.replaceAll(
    'final ValueChanged<AppMapController> onMapCreated;',
    'final ValueChanged<AppMapController> onMapCreated;'
  );
  
  // The error at 582: `onMapCreated: _updateMapView,` but `_updateMapView` might take a different type?
  // `void _updateMapView(SharedMapView view)` vs `ValueChanged<AppMapController>`
  // Wait! TransitRouterScreen takes `onMapCreated` ?? NO! It takes `onMapViewChanged`!
  // `onMapViewChanged` is NOT `onMapCreated`!
  // My powershell replaced `onMapCreated(GoogleMapController ...)` but left `onMapCreated` alone if it was `void Function(dynamic)`.
  // Wait, let's fix the parameter `onMapCreated` in `_LiveMapboxSurface` to `ValueChanged<AppMapController>`. It is.

  file.writeAsStringSync(content);
  print('Fixed main.dart syntax errors!');
}
