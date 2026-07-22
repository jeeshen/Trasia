import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'mapbox_surface.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'src/core.dart';
part 'src/auth.dart';
part 'src/dashboard.dart';
part 'src/transit.dart';
part 'src/hub_pool.dart';
part 'src/plan.dart';
part 'src/account.dart';
part 'src/shared_widgets.dart';
part 'src/models_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.load();
  unawaited(warmUpMapboxCache());
  if (SupabaseConfig.isReady) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await GoogleMapsFlutterAndroid().initializeWithRenderer(
        AndroidMapRenderer.latest,
      );
    } catch (_) {
      // Ignored on hot restart.
    }
  }

  _warmUpLocationEarly();

  runApp(const TrasiaApp());
}

Future<void> _warmUpLocationEarly() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 4),
        ),
      );
      final loc = LatLng(position.latitude, position.longitude);
      globalMapViewNotifier.value = SharedMapView(
        signature: 'early_warmup',
        initialTarget: loc,
        initialZoom: 16,
        currentLocation: loc,
      );
      if (globalMapController.value != null) {
        globalMapController.value!.flyToLatLngZoom(loc, 16.0);
      }
    }
  } catch (_) {}
}
