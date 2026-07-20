const fs = require('fs');
let content = fs.readFileSync('lib/main.dart', 'utf-8');

// 1. Fix globalMapController
content = content.replace(
  'final globalMapController = ValueNotifier<GoogleMapController?>(null);',
  'final globalMapController = ValueNotifier<AppMapController?>(null);'
);

// 2. Fix TransitRouterScreen constructor mapController type
content = content.replace(
  'final GoogleMapController? mapController;',
  'final AppMapController? mapController;'
);

// 3. Fix HubPoolScreen constructor mapController type
// Note: we replace all globally
content = content.replace(/GoogleMapController/g, 'AppMapController');

// 4. Fix animateCamera syntax errors (leftover)
content = content.replace(/_mapController!\.animateCamera\(\s*CameraUpdate\.newCameraPosition\(\s*CameraPosition\(\s*target:\s*start,\s*zoom:\s*17\.5,\s*tilt:\s*0\.0,\s*bearing:\s*bearing,\s*\),\s*\),\s*\);/g, 
  '_mapController!.flyToCameraPosition(CameraPosition(target: start, zoom: 17.5, tilt: 0.0, bearing: bearing));'
);
content = content.replace(/controller\.animateCamera\(\s*CameraUpdate\.newCameraPosition\(\s*CameraPosition\(\s*target:\s*start,\s*zoom:\s*17\.5,\s*tilt:\s*0\.0,\s*bearing:\s*bearing,\s*\),\s*\),\s*\);/g, 
  'controller.flyToCameraPosition(CameraPosition(target: start, zoom: 17.5, tilt: 0.0, bearing: bearing));'
);

// Fix remaining syntax error at 1115 (probably bad replace from earlier regex)
// Let's use a regex to clean up any `flyToCameraPosition(` missing a closing `);` or having extra text.
// Actually, I can just find what's wrong around 1115 and rewrite it.
fs.writeFileSync('lib/main.dart', content);
