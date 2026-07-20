import 'dart:io';

void main() {
  final file = File('lib/main.dart');
  var content = file.readAsStringSync();

  // Fix 1: flyToLatLngZoom inside DashboardScreenState
  content = content.replaceAll(
    'globalMapController.value!.moveCamera(CameraUpdate.newLatLngZoom(loc, 16));',
    'globalMapController.value!.flyToLatLngZoom(loc, 16.0);'
  );

  content = content.replaceAll(
    'globalMapController.value!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom)),',
    'globalMapController.value!.flyToLatLngZoom(target, zoom),'
  );

  content = content.replaceAll(
    'await controller.animateCamera(CameraUpdate.newLatLngZoom(location, 17));',
    'await controller.flyToLatLngZoom(location, 17.0);'
  );
  
  content = content.replaceAll(
    '_mapController?.animateCamera(',
    '_mapController?.flyToCameraPosition('
  );
  
  content = content.replaceAll(
    'await controller.animateCamera(',
    'await controller.flyToCameraPosition('
  );
  
  // Fix weird extra syntax around 1115
  // Original broken code:
  //         padding,
  //       ),
  //     );
  //   }
  //
  //   void _resetNavigation() {
  
  content = content.replaceAll(
'''    await _mapController!.flyToBounds(
LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        padding,
      ),
    );''',
'''    await _mapController!.flyToBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      padding,
    );'''
  );

  // For HubPoolScreen missing methods
  content = content.replaceAll(
    'CameraUpdate.newCameraPosition(',
    ''
  );
  
  // Actually, wait, animateCamera -> flyToCameraPosition might have left `CameraUpdate.newCameraPosition(` in the args?
  // Yes! The regex replacement missed some.
  // I will just do a fallback replace:
  content = content.replaceAll(
    'flyToCameraPosition(CameraUpdate.newCameraPosition(',
    'flyToCameraPosition('
  );

  content = content.replaceAll(
    'flyToCameraPosition(\nCameraUpdate.newCameraPosition(',
    'flyToCameraPosition('
  );
  
  // And fix the trailing `),` which was part of `CameraUpdate.newCameraPosition`
  content = content.replaceAll(
'''            bearing: bearing,
          ),
        ),
      );''',
'''            bearing: bearing,
          ),
      );'''
  );
  
  content = content.replaceAll(
'''            bearing: bearing,
          ),
        ),
      )''',
'''            bearing: bearing,
          )
      )'''
  );

  file.writeAsStringSync(content);
  print('Final fix complete!');
}
