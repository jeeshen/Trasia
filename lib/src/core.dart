part of '../main.dart';

enum UserRole { user, admin }

enum RideStage { idle, matching, tracking, onboard, completed, cancelled }

enum PriceTier { budget, midRange, luxury }

enum BlindBoxTravelMode { drive, transit }

enum FeatureCTripStatus { notStarted, traveling, arrived, completed }

class TrasiaColors {
  static const background = Color(0xFF07131F);
  static const primary = Color(0xFF0B7CFF);
  static const primaryPressed = Color(0xFF006CFF);
  static const darkIcon = Color(0xFF1F2937);
}

class SupabaseConfig {
  static const _definedUrl = String.fromEnvironment('SUPABASE_URL');
  static const _definedAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String url = _definedUrl;
  static String anonKey = _definedAnonKey;

  static bool get isReady => url.isNotEmpty && anonKey.isNotEmpty;

  static Future<void> load() async {
    if (isReady) {
      return;
    }
    try {
      final values = _parseEnv(await rootBundle.loadString('.env.local'));
      url = values['SUPABASE_URL'] ?? url;
      anonKey = values['SUPABASE_ANON_KEY'] ?? anonKey;
    } catch (_) {
      // Keep dart-define values, or remain unconfigured for preview mode.
    }
  }

  static Map<String, String> _parseEnv(String source) {
    final values = <String, String>{};
    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      values[key] = value;
    }
    return values;
  }
}

class AuthProfile {
  const AuthProfile({
    required this.email,
    required this.role,
    required this.credit,
    required this.savedTransitRoutes,
    required this.hubPoolTransactions,
    required this.carbonSavedKg,
  });

  final String email;
  final UserRole role;
  final double credit;
  final int savedTransitRoutes;
  final int hubPoolTransactions;
  final double carbonSavedKg;

  AuthProfile copyWith({
    double? credit,
    int? savedTransitRoutes,
    int? hubPoolTransactions,
    double? carbonSavedKg,
  }) {
    return AuthProfile(
      email: email,
      role: role,
      credit: credit ?? this.credit,
      savedTransitRoutes: savedTransitRoutes ?? this.savedTransitRoutes,
      hubPoolTransactions: hubPoolTransactions ?? this.hubPoolTransactions,
      carbonSavedKg: carbonSavedKg ?? this.carbonSavedKg,
    );
  }
}

class AuthService {
  const AuthService();

  SupabaseClient get _client => Supabase.instance.client;

  Future<AuthProfile> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Login failed.');
    }
    return _profileFor(user);
  }

  Future<AuthProfile> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null || response.session == null) {
      throw const AuthException(
        'Check your email to finish sign up, then log in.',
      );
    }
    await _ensureProfile(user);
    return _profileFor(user);
  }

  Future<AuthProfile?> currentProfile() async {
    final user = _client.auth.currentUser;
    return user == null ? null : _profileFor(user);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> updateStats({
    required double credit,
    required int savedTransitRoutes,
    required int hubPoolTransactions,
    required double carbonSavedKg,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }
    await _client
        .from('profiles')
        .update({
          'credit': credit,
          'saved_transit_routes': savedTransitRoutes,
          'hub_pool_transactions': hubPoolTransactions,
          'carbon_saved_kg': carbonSavedKg,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id);
  }

  Future<AuthProfile> _profileFor(User user) async {
    await _ensureProfile(user);
    final row = await _client
        .from('profiles')
        .select(
          'role,email,credit,saved_transit_routes,hub_pool_transactions,carbon_saved_kg',
        )
        .eq('id', user.id)
        .maybeSingle();
    final role = row?['role'] == 'admin' ? UserRole.admin : UserRole.user;
    return AuthProfile(
      email: (row?['email'] as String?) ?? user.email ?? '',
      role: role,
      credit: ((row?['credit'] as num?) ?? 128.40).toDouble(),
      savedTransitRoutes: ((row?['saved_transit_routes'] as num?) ?? 0).toInt(),
      hubPoolTransactions: ((row?['hub_pool_transactions'] as num?) ?? 0)
          .toInt(),
      carbonSavedKg: ((row?['carbon_saved_kg'] as num?) ?? 0).toDouble(),
    );
  }

  Future<void> _ensureProfile(User user) async {
    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) {
      return;
    }
    await _client.from('profiles').insert({
      'id': user.id,
      'email': user.email,
      'role': 'user',
      'credit': 128.40,
      'saved_transit_routes': 0,
      'hub_pool_transactions': 0,
      'carbon_saved_kg': 0,
    });
  }
}

extension BlindBoxTravelModeDetails on BlindBoxTravelMode {
  String get label {
    return switch (this) {
      BlindBoxTravelMode.drive => 'Drive',
      BlindBoxTravelMode.transit => 'Transit',
    };
  }

  IconData get icon {
    return switch (this) {
      BlindBoxTravelMode.drive => Icons.directions_car_rounded,
      BlindBoxTravelMode.transit => Icons.directions_transit_rounded,
    };
  }

  int travelMinutesFor(double km) {
    return switch (this) {
      BlindBoxTravelMode.drive => max(8, (km * 4.2).round()),
      BlindBoxTravelMode.transit => max(20, (km * 4.8 + 18).round()),
    };
  }
}

class _GoogleMapsConfig {
  static const providedApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const developmentApiKey = 'AIzaSyDEDpjqw4CrmsiJSOGWtjeH4LnJSl715jw';
  static const apiKey = providedApiKey == ''
      ? developmentApiKey
      : providedApiKey;

  static bool get isReady => apiKey.isNotEmpty;
}

class SharedMapView {
  const SharedMapView({
    required this.signature,
    this.currentLocation,
    this.currentAccuracyMeters,
    this.candidate,
    this.selectedRoute,
    this.navigating = false,
    this.vehicleLocation,
    this.vehicleColor,
    this.vehicleBearing = 0,
    this.showCurrentLocationMarker = true,
    this.showRouteEndpoints = true,
    this.initialTarget,
    this.initialZoom,
    this.extraMarkers = const <Marker>{},
    this.extraPolylines = const <Polyline>{},
  });

  final String signature;
  final LatLng? currentLocation;
  final double? currentAccuracyMeters;
  final DestinationCandidate? candidate;
  final TransitOption? selectedRoute;
  final bool navigating;
  final LatLng? vehicleLocation;
  final Color? vehicleColor;
  final double vehicleBearing;
  final bool showCurrentLocationMarker;
  final bool showRouteEndpoints;
  final LatLng? initialTarget;
  final double? initialZoom;
  final Set<Marker> extraMarkers;
  final Set<Polyline> extraPolylines;

  static const initial = SharedMapView(
    signature: 'initial',
    initialTarget: LatLng(3.1478, 101.6953),
    initialZoom: 12,
  );
}

final globalMapViewNotifier = ValueNotifier<SharedMapView>(
  SharedMapView.initial,
);
final globalMapController = ValueNotifier<AppMapController?>(null);
