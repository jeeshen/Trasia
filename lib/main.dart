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
import 'package:image_picker/image_picker.dart';

import 'package:shared_preferences/shared_preferences.dart';
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
  if (SupabaseConfig.isReady) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  runApp(const TrasiaApp());
}
