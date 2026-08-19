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
import 'loading_compass.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
part 'src/core.dart';
part 'src/auth.dart';
part 'src/dashboard.dart';
part 'src/transit.dart';
part 'src/hub_pool.dart';
part 'src/plan.dart';
part 'src/rewards.dart';
part 'src/account.dart';
part 'src/shared_widgets.dart';
part 'src/models_data.dart';
part 'src/admin.dart';
part 'src/admin_analytics.dart';
void main() {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
      debugPrintStack(
        label: 'FlutterError: ${details.exceptionAsString()}',
        stackTrace: details.stack,
      );
    };
    runApp(const TrasiaBootstrap());
  } catch (e, stack) {
    debugPrintStack(label: 'Main Crash: $e', stackTrace: stack);
    rethrow;
  }
}
Future<void> _initializeApp() async {
  try {
    await SupabaseConfig.load();
    if (SupabaseConfig.isReady) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      await TrasiaData.load();
      await _RewardsData.load();
    }
  } catch (e, stack) {
    debugPrintStack(label: '_initializeApp Crash: $e', stackTrace: stack);
    rethrow;
  }
}
class TrasiaBootstrap extends StatefulWidget {
  const TrasiaBootstrap({super.key});
  @override
  State<TrasiaBootstrap> createState() => _TrasiaBootstrapState();
}
class _TrasiaBootstrapState extends State<TrasiaBootstrap> {
  late final Future<void> _initialization = _initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return const TrasiaApp();
        }
        return const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: Color(0xFFF1F3F4),
            body: Center(
              child: TrasiaLoadingCompass(
                key: Key('app-loading-compass'),
                size: 96,
                semanticLabel: 'Loading Trasia',
              ),
            ),
          ),
        );
      },
    );
  }
  @override
  void dispose() {
    super.dispose();
  }
}
