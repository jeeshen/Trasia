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
  static const _definedStripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );
  static String url = _definedUrl;
  static String anonKey = _definedAnonKey;
  static String stripePublishableKey = _definedStripePublishableKey;
  static bool supabaseInitialized = false;
  static bool get isReady => url.isNotEmpty && anonKey.isNotEmpty;
  static bool get isSupabaseReady => isReady && supabaseInitialized;
  static Future<void> load() async {
    if (isReady &&
        _GoogleMapsConfig.isReady &&
        stripePublishableKey.isNotEmpty) {
      return;
    }
    try {
      final values = _parseEnv(await rootBundle.loadString('.env'));
      url = values['SUPABASE_URL'] ?? url;
      anonKey = values['SUPABASE_ANON_KEY'] ?? anonKey;
      stripePublishableKey =
          values['STRIPE_PUBLISHABLE_KEY'] ?? stripePublishableKey;
      _GoogleMapsConfig.apiKey =
          values['GOOGLE_MAPS_API_KEY'] ?? _GoogleMapsConfig.apiKey;
    } catch (_) {}
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
    String? email,
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
      email: email ?? this.email,
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

  Future<AuthProfile?> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw const AuthException('Sign up failed.');
    }
    if (response.session == null) {
      return null;
    }
    await _ensureProfile(user);
    return _profileFor(user);
  }

  Future<AuthProfile> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );
    final user = response.user ?? _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Email confirmation failed.');
    }
    await _ensureProfile(user);
    return _profileFor(user);
  }

  Future<void> resendSignupOtp(String email) async {
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  Future<AuthProfile?> currentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final profile = await _profileFor(user);
    globalAuthProfileNotifier.value = profile;
    return profile;
  }

  Future<void> signOut() => _client.auth.signOut();
  Future<void> updateEmail(String newEmail) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final response = await _client.functions.invoke(
        'update-email',
        body: {'userId': user.id, 'newEmail': newEmail},
      );
      if (response.status == 200) {
        final updated = await currentProfile();
        if (updated != null) globalAuthProfileNotifier.value = updated;
      }
    } on FunctionException catch (e) {
      if (e.status == 409) {
        throw const AuthException('This email is already in use.');
      }
      throw const AuthException('Unable to update email. Please try again.');
    } catch (e) {
      throw const AuthException('Unable to update email. Please try again.');
    }
  }

  Future<void> verifyCurrentPassword(String password) async {
    final user = _client.auth.currentUser;
    if (user == null || user.email == null) return;
    try {
      await _client.auth.signInWithPassword(
        email: user.email,
        password: password,
      );
    } catch (e) {
      throw const AuthException('Incorrect current password.');
    }
  }

  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<bool> isUsernameAvailable(String username) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final res = await _client.rpc(
      'is_username_available',
      params: {'check_username': username},
    );
    return res == true;
  }

  Future<bool> isEmailAvailable(String email) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final res = await _client
        .from('profiles')
        .select('id')
        .ilike('email', email)
        .neq('id', user.id)
        .maybeSingle();
    return res == null;
  }

  Future<void> updateProfile(AuthProfile profile) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return;
    }
    await _client
        .from('profiles')
        .update({
          'email': profile.email,
          'username': profile.username,
          'saved_transit_routes': profile.savedTransitRoutes,
          'hub_pool_transactions': profile.hubPoolTransactions,
          'carbon_saved_kg': profile.carbonSavedKg,
          'favorite_places': profile.favoritePlaces
              .map((v) => v.toJson())
              .toList(),
          'trip_history': profile.tripHistory.map((v) => v.toJson()).toList(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id);
    globalAuthProfileNotifier.value = profile;
  }

  Future<bool> deductRideFare(double amount) async {
    final result = await _client.rpc(
      'deduct_ride_fare',
      params: {'p_amount': amount},
    );
    return result == true;
  }

  Future<bool> redeemVoucher(String voucherId) async {
    final result = await _client.rpc(
      'redeem_voucher',
      params: {'p_voucher_id': voucherId},
    );
    return result == true;
  }

  Future<bool> checkInAttraction(String placeName) async {
    final result = await _client.rpc(
      'check_in_attraction',
      params: {'p_place_name': placeName},
    );
    return result == true;
  }

  Future<bool> markVoucherUsed(String voucherId) async {
    final result = await _client.rpc(
      'mark_voucher_used',
      params: {'p_voucher_id': voucherId},
    );
    return result == true;
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
    final vouchers = rawVouchers
        .map((v) => RedeemedVoucher.fromJson(v as Map<String, dynamic>))
        .toList();
    final rawPlaces = row?['checked_in_places'];
    final checkedInPlaces = <String, CheckedInPlace>{};
    if (rawPlaces is Map<String, dynamic>) {
      for (final entry in rawPlaces.entries) {
        checkedInPlaces[entry.key] = CheckedInPlace.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }
    final rawFavorites = row?['favorite_places'] as List<dynamic>? ?? const [];
    final favorites = rawFavorites
        .map((v) => FavoritePlace.fromJson(v as Map<String, dynamic>))
        .toList();
    final rawHistory = row?['trip_history'] as List<dynamic>? ?? const [];
    final history = rawHistory
        .map((v) => TripHistoryEntry.fromJson(v as Map<String, dynamic>))
        .toList();
    return AuthProfile(
      email: (row?['email'] as String?) ?? user.email ?? '',
      role: role,
      username: row?['username'] as String?,
      credit: ((row?['credit'] as num?) ?? 0.0).toDouble(),
      savedTransitRoutes: ((row?['saved_transit_routes'] as num?) ?? 0).toInt(),
      hubPoolTransactions: ((row?['hub_pool_transactions'] as num?) ?? 0)
          .toInt(),
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
    await _client.from('profiles').insert({'id': user.id, 'email': user.email});
  }
}

class TrasiaNotification {
  const TrasiaNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.readAt,
  });
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final DateTime? readAt;
  bool get isRead => readAt != null;
  TrasiaNotification copyWith({DateTime? readAt}) {
    return TrasiaNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory TrasiaNotification.fromJson(Map<String, dynamic> json) {
    return TrasiaNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: (json['type'] as String?) ?? 'general',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(json['read_at'] as String).toLocal(),
    );
  }
}

class NotificationService {
  const NotificationService();
  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;
  Future<List<TrasiaNotification>> load() async {
    final userId = _userId;
    if (userId == null) return const [];
    final rows = await _client
        .from('notifications')
        .select('id,title,body,type,created_at,read_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List<dynamic>)
        .map((row) => TrasiaNotification.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String title,
    required String body,
    String type = 'general',
  }) async {
    final userId = _userId;
    if (userId == null) return;
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
    });
  }

  Future<void> markAllRead() async {
    final userId = _userId;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId)
        .isFilter('read_at', null);
  }
}

class PushNotificationService {
  const PushNotificationService();
  SupabaseClient get _client => Supabase.instance.client;
  static bool _listenersRegistered = false;
  static bool _localNotificationsInitialized = false;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      await _initializeLocalNotifications();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      final token = await messaging.getToken();
      if (token != null) await _saveToken(token);
      if (!_listenersRegistered) {
        _listenersRegistered = true;
        FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
        FirebaseMessaging.onMessage.listen((message) {
          final notification = message.notification;
          if (notification == null) return;
          unawaited(
            _showLocalNotification(
              notification.title ?? 'Trasia',
              notification.body ?? '',
            ),
          );
        });
      }
    } catch (error) {
      debugPrint('Push notifications unavailable: $error');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'car_pool',
        'Car-Pool notifications',
        description: 'Updates about Hub-Pool rides',
        importance: Importance.high,
      ),
    );
    _localNotificationsInitialized = true;
  }

  Future<void> _showLocalNotification(String title, String body) async {
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'car_pool',
          'Car-Pool notifications',
          channelDescription: 'Updates about Hub-Pool rides',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _saveToken(String token) async {
    if (_client.auth.currentUser == null) return;
    await _client.functions.invoke(
      'send-push',
      body: {
        'action': 'register',
        'token': token,
        'platform': defaultTargetPlatform.name,
      },
    );
  }

  Future<void> unregister() async {
    if (_client.auth.currentUser == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        try {
          await _client.functions.invoke(
            'send-push',
            body: {'action': 'unregister', 'token': token},
          );
        } catch (error) {
          debugPrint('Unable to unregister push token remotely: $error');
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Unable to invalidate push token: $error');
    }
  }

  Future<void> sendCarPoolNotification({
    required String title,
    required String body,
  }) async {
    if (_client.auth.currentUser == null) return;
    await _client.functions.invoke(
      'send-push',
      body: {'title': title, 'body': body, 'type': 'car_pool'},
    );
  }
}

class StripeTopUpService {
  const StripeTopUpService();
  SupabaseClient get _client => Supabase.instance.client;
  Future<void> payInApp(int amountRm) async {
    if (amountRm != 20 && amountRm != 50) {
      throw const AuthException('Invalid top-up amount.');
    }
    if (SupabaseConfig.stripePublishableKey.isEmpty) {
      throw const AuthException(
        'Add STRIPE_PUBLISHABLE_KEY (pk_test_...) to the app configuration.',
      );
    }
    final response = await _client.functions.invoke(
      'stripe-topup',
      body: {'amount_rm': amountRm, 'payment_sheet': true},
    );
    final data = response.data;
    final dataMap = data is Map ? data : null;
    final clientSecret = dataMap?['payment_intent_client_secret'] as String?;
    final paymentIntentId = dataMap?['payment_intent_id'] as String?;
    if (clientSecret == null || clientSecret.isEmpty) {
      throw const AuthException('Unable to start in-app payment.');
    }
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Trasia',
          returnURL: 'trasia://stripe-success',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      if (paymentIntentId != null && paymentIntentId.isNotEmpty) {
        try {
          await _client.functions.invoke(
            'stripe-topup',
            body: {
              'confirm_payment_intent': true,
              'payment_intent_id': paymentIntentId,
            },
          );
        } catch (error) {
          debugPrint(
            'Payment verification will rely on Stripe webhook: $error',
          );
        }
      }
    } on StripeException catch (error) {
      throw AuthException(
        error.error.localizedMessage ?? 'Payment was cancelled.',
      );
    } catch (error) {
      throw AuthException('In-app payment failed: $error');
    }
  }

  Future<void> reconcilePending() async {
    try {
      final rows = await _client
          .from('credit_topups')
          .select('stripe_payment_intent_id')
          .eq('status', 'pending')
          .limit(10);
      for (final row in rows as List<dynamic>) {
        final paymentIntentId =
            (row as Map<String, dynamic>)['stripe_payment_intent_id']
                as String?;
        if (paymentIntentId == null || paymentIntentId.isEmpty) continue;
        try {
          await _client.functions.invoke(
            'stripe-topup',
            body: {
              'confirm_payment_intent': true,
              'payment_intent_id': paymentIntentId,
            },
          );
        } catch (error) {
          debugPrint('Pending payment still awaiting confirmation: $error');
        }
      }
    } catch (error) {
      debugPrint('Unable to reconcile pending payments: $error');
    }
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
  static const developmentApiKey = '';
  static String apiKey = providedApiKey == ''
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
final globalAuthProfileNotifier = ValueNotifier<AuthProfile?>(null);
