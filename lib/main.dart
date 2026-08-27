import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
part 'src/core.dart';
part 'src/image_service.dart';
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
    ui.PlatformDispatcher.instance.onError = (error, stack) {
      debugPrintStack(label: 'Uncaught async error: $error', stackTrace: stack);
      return true;
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
    if ((defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        SupabaseConfig.stripePublishableKey.isNotEmpty) {
      Stripe.publishableKey = SupabaseConfig.stripePublishableKey;
      Stripe.urlScheme = 'trasia';
      await Stripe.instance.applySettings();
    }
    if (SupabaseConfig.isReady) {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      SupabaseConfig.supabaseInitialized = true;
      try {
        await Future.wait([TrasiaData.load(), _RewardsData.load()]);
      } catch (e, stack) {
        debugPrintStack(
          label: 'Optional Supabase data load failed: $e',
          stackTrace: stack,
        );
      }
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
  late Future<void> _initialization;
  @override
  void initState() {
    super.initState();
    _initialization = _initializeApp();
  }

  void _retryInitialization() {
    setState(() => _initialization = _initializeApp());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InitializationErrorScreen(
            error: snapshot.error!,
            onRetry: _retryInitialization,
          );
        }
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
}

class _InitializationErrorScreen extends StatelessWidget {
  const _InitializationErrorScreen({
    required this.error,
    required this.onRetry,
  });
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: Color(0xFFE04470),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to start Trasia',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supabase could not be initialized. Check your connection and try again.\n\n$error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF536477)),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
