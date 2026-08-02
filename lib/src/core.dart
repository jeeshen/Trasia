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

SnackBarThemeData get _trasiaSnackBarTheme => SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  backgroundColor: Colors.white,
  elevation: 10,
  insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(22),
    side: const BorderSide(color: Color(0xFFE0E7F0)),
  ),
  contentTextStyle: const TextStyle(
    color: Color(0xFF172033),
    fontWeight: FontWeight.w700,
    fontSize: 13,
  ),
  actionTextColor: TrasiaColors.primary,
);

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
    this.username,
    required this.credit,
    required this.savedTransitRoutes,
    required this.hubPoolTransactions,
    required this.carbonSavedKg,
    required this.rewardPoints,
    required this.redeemedVouchers,
    required this.checkedInPlaces,
    required this.favoritePlaces,
    required this.tripHistory,
  });

  final String email;
  final UserRole role;
  final String? username;
  final double credit;
  final int savedTransitRoutes;
  final int hubPoolTransactions;
  final double carbonSavedKg;
  final int rewardPoints;
  final List<RedeemedVoucher> redeemedVouchers;
  final Map<String, CheckedInPlace> checkedInPlaces;
  final List<FavoritePlace> favoritePlaces;
  final List<TripHistoryEntry> tripHistory;

  AuthProfile copyWith({
    String? username,
    double? credit,
    int? savedTransitRoutes,
    int? hubPoolTransactions,
    double? carbonSavedKg,
    int? rewardPoints,
    List<RedeemedVoucher>? redeemedVouchers,
    Map<String, CheckedInPlace>? checkedInPlaces,
    List<FavoritePlace>? favoritePlaces,
    List<TripHistoryEntry>? tripHistory,
  }) {
    return AuthProfile(
      email: email,
      role: role,
      username: username ?? this.username,
      credit: credit ?? this.credit,
      savedTransitRoutes: savedTransitRoutes ?? this.savedTransitRoutes,
      hubPoolTransactions: hubPoolTransactions ?? this.hubPoolTransactions,
      carbonSavedKg: carbonSavedKg ?? this.carbonSavedKg,
      rewardPoints: rewardPoints ?? this.rewardPoints,
      redeemedVouchers: redeemedVouchers ?? this.redeemedVouchers,
      checkedInPlaces: checkedInPlaces ?? this.checkedInPlaces,
      favoritePlaces: favoritePlaces ?? this.favoritePlaces,
      tripHistory: tripHistory ?? this.tripHistory,
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

  Future<void> updateEmail(String newEmail) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    
    final res = await _client
        .from('profiles')
        .select('id')
        .ilike('email', newEmail)
        .neq('id', user.id)
        .maybeSingle();
        
    if (res != null) {
      throw Exception('This email address is already in use.');
    }
    
    try {
      await _client.from('profiles').update({'email': newEmail}).eq('id', user.id);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('This email address is already in use.');
      }
      rethrow;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<bool> isUsernameAvailable(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    
    final res = await _client.rpc('is_username_available', params: {
      'check_username': username,
    });
    
    return res == true;
  }

  Future<void> updateProfile(AuthProfile profile) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }
    await _client
        .from('profiles')
        .update({
          'username': profile.username,
          'credit': profile.credit,
          'saved_transit_routes': profile.savedTransitRoutes,
          'hub_pool_transactions': profile.hubPoolTransactions,
          'carbon_saved_kg': profile.carbonSavedKg,
          'reward_points': profile.rewardPoints,
          'redeemed_vouchers': profile.redeemedVouchers.map((v) => v.toJson()).toList(),
          'checked_in_places': profile.checkedInPlaces.map((k, v) => MapEntry(k, v.toJson())),
          'favorite_places': profile.favoritePlaces.map((v) => v.toJson()).toList(),
          'trip_history': profile.tripHistory.map((v) => v.toJson()).toList(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id);
  }

  Future<AuthProfile> _profileFor(User user) async {
    await _ensureProfile(user);
    final row = await _client
        .from('profiles')
        .select(
          'role,email,username,credit,saved_transit_routes,hub_pool_transactions,carbon_saved_kg,reward_points,redeemed_vouchers,checked_in_places,favorite_places,trip_history',
        )
        .eq('id', user.id)
        .maybeSingle();
    
    final role = row?['role'] == 'admin' ? UserRole.admin : UserRole.user;
    
    final rawVouchers = row?['redeemed_vouchers'] as List<dynamic>? ?? const [];
    final vouchers = rawVouchers.map((v) => RedeemedVoucher.fromJson(v as Map<String, dynamic>)).toList();
    
    final rawPlaces = row?['checked_in_places'];
    final checkedInPlaces = <String, CheckedInPlace>{};
    if (rawPlaces is Map<String, dynamic>) {
      for (final entry in rawPlaces.entries) {
        checkedInPlaces[entry.key] = CheckedInPlace.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    
    final rawFavorites = row?['favorite_places'] as List<dynamic>? ?? const [];
    final favorites = rawFavorites.map((v) => FavoritePlace.fromJson(v as Map<String, dynamic>)).toList();
    
    final rawHistory = row?['trip_history'] as List<dynamic>? ?? const [];
    final history = rawHistory.map((v) => TripHistoryEntry.fromJson(v as Map<String, dynamic>)).toList();
    
    return AuthProfile(
      email: (row?['email'] as String?) ?? user.email ?? '',
      role: role,
      username: row?['username'] as String?,
      credit: ((row?['credit'] as num?) ?? 128.40).toDouble(),
      savedTransitRoutes: ((row?['saved_transit_routes'] as num?) ?? 0).toInt(),
      hubPoolTransactions: ((row?['hub_pool_transactions'] as num?) ?? 0).toInt(),
      carbonSavedKg: ((row?['carbon_saved_kg'] as num?) ?? 0).toDouble(),
      rewardPoints: ((row?['reward_points'] as num?) ?? 600).toInt(),
      redeemedVouchers: vouchers,
      checkedInPlaces: checkedInPlaces,
      favoritePlaces: favorites,
      tripHistory: history,
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
      'reward_points': 600,
      'redeemed_vouchers': [],
      'checked_in_places': {},
      'favorite_places': [],
      'trip_history': [],
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
    this.focusDestination,
    this.selectedRoute,
    this.mapRefreshRevision = 0,
    this.navigating = false,
    this.vehicleLocation,
    this.vehicleColor,
    this.vehicleBearing = 0,
    this.routeProgress,
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
  final LatLng? focusDestination;
  final TransitOption? selectedRoute;
  final int mapRefreshRevision;
  final bool navigating;
  final LatLng? vehicleLocation;
  final Color? vehicleColor;
  final double vehicleBearing;
  final double? routeProgress;
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
