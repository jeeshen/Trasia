import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TrasiaApp());
}

enum UserRole { user, admin }

enum RideStage { idle, matching, tracking, onboard, completed, cancelled }

class TrasiaApp extends StatelessWidget {
  const TrasiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trasia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B7CFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07131F),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2688FF), Color(0xFF005DD9)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              width: min(MediaQuery.sizeOf(context).width - 44, 390),
              height: MediaQuery.sizeOf(context).height * .86,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66001943),
                    blurRadius: 28,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _SkylineBackdrop(),
                  Container(color: const Color(0xAA064B9E)),
                  const Positioned(
                    top: 74,
                    left: 0,
                    right: 0,
                    child: Text(
                      'TRASIA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 116,
                    child: Column(
                      children: [
                        _PageDots(),
                        SizedBox(height: 18),
                        Text(
                          'Public transit, shared mobility,\nand Malaysian travel discovery',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 34,
                    child: Column(
                      children: [
                        FilledButton(
                          key: const Key('start-now'),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF006CFF),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 14,
                            ),
                          ),
                          child: const Text('Start Now'),
                        ),
                        const SizedBox(height: 12),
                        const Icon(Icons.keyboard_arrow_up_rounded, size: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  void _enter(BuildContext context, UserRole role) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardScreen(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _BlueShell(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(Icons.route_rounded, size: 70),
                    const SizedBox(height: 18),
                    const Text(
                      'Choose Trasia Mode',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A presentation-ready simulator for SDG 9 transit planning, hub pooling, and tourist routes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                    const SizedBox(height: 34),
                    _LoginRoleButton(
                      key: const Key('login-user'),
                      icon: Icons.person_rounded,
                      title: 'Login as User',
                      subtitle: 'Wallet, transit, rides, and PelancongPlan',
                      onTap: () => _enter(context, UserRole.user),
                    ),
                    const SizedBox(height: 14),
                    _LoginRoleButton(
                      key: const Key('login-admin'),
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Login as Admin',
                      subtitle: 'Registry, credits, controls, and diagnostics',
                      onTap: () => _enter(context, UserRole.admin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.role, super.key});

  final UserRole role;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  double _wallet = 128.40;
  String _transitDestination = 'KLCC';

  void _openTransitFor(String destination) {
    setState(() {
      _transitDestination = destination;
      _tab = 0;
    });
  }

  void _deductFare(double fare) {
    setState(() => _wallet = max(0, _wallet - fare));
  }

  void _topUp(double amount) {
    setState(() => _wallet += amount);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TransitRouterScreen(destination: _transitDestination),
      HubPoolScreen(wallet: _wallet, onFareDeducted: _deductFare),
      PelancongPlanScreen(onGoViaTransit: _openTransitFor),
      AccountConsoleScreen(role: widget.role, wallet: _wallet, onTopUp: _topUp),
    ];

    return Scaffold(
      body: _BlueShell(
        child: _tab == 0 || _tab == 1
            ? pages[_tab]
            : SafeArea(
                child: Column(
                  children: [
                    _DashboardHeader(role: widget.role, wallet: _wallet),
                    Expanded(
                      child: IndexedStack(index: _tab, children: pages),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: const Color(0xF2091828),
        indicatorColor: const Color(0xFF0B7CFF),
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.train_rounded),
            label: 'Transit',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_rounded),
            label: 'Hub-Pool',
          ),
          NavigationDestination(
            icon: Icon(Icons.travel_explore_rounded),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_rounded),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class TransitRouterScreen extends StatefulWidget {
  const TransitRouterScreen({required this.destination, super.key});

  final String destination;

  @override
  State<TransitRouterScreen> createState() => _TransitRouterScreenState();
}

class _TransitRouterScreenState extends State<TransitRouterScreen> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  double? _currentAccuracyMeters;
  LatLng? _departureLocation;
  String? _departureName;
  LatLng _lastMapCenter = const LatLng(3.1478, 101.6953);
  DestinationCandidate? _candidate;
  List<DestinationCandidate> _candidates = const [];
  List<TransitOption> _routes = const [];
  TransitOption? _selectedRoute;
  String? _statusMessage;
  bool _loading = false;
  bool _navigating = false;
  static const _providedGoogleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const _developmentGoogleMapsApiKey =
      'AIzaSyDEDpjqw4CrmsiJSOGWtjeH4LnJSl715jw';
  static const _googleMapsApiKey = _providedGoogleMapsApiKey == ''
      ? _developmentGoogleMapsApiKey
      : _providedGoogleMapsApiKey;

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController(text: 'Current location');
    _toController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_warmCurrentLocation());
    });
  }

  @override
  void didUpdateWidget(covariant TransitRouterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _toController.text = widget.destination;
      unawaited(_searchDestination());
      _candidate = null;
      _candidates = const [];
      _routes = const [];
      _selectedRoute = null;
      _navigating = false;
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(
          child: _LiveGoogleMapSurface(
            apiKeyReady: _hasGoogleMapsKey,
            currentLocation: _currentLocation,
            currentAccuracyMeters: _currentAccuracyMeters,
            candidate: _candidate,
            selectedRoute: _selectedRoute,
            navigating: _navigating,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (position) {
              _lastMapCenter = position.target;
            },
          ),
        ),
        if (!_navigating)
          Positioned(
            left: 14,
            right: 14,
            top: topInset + 8,
            child: _MapSearchWindow(
              fromController: _fromController,
              toController: _toController,
              statusMessage: _statusMessage,
              candidate: _candidate,
              candidates: _candidates,
              routes: _routes,
              selectedRoute: _selectedRoute,
              navigating: _navigating,
              onSearch: _searchDestination,
              onConfirmDestination: _calculateDirections,
              onSelectRoute: _startPlannedRoute,
            ),
          ),
        Positioned(
          right: 14,
          bottom: 18,
          child: Column(
            children: [
              _RoundMapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Current location',
                onPressed: () => unawaited(_centerOnCurrentLocation()),
              ),
              const SizedBox(height: 10),
              _RoundMapButton(
                icon: Icons.layers_rounded,
                tooltip: 'Map layers',
                onPressed: () {},
              ),
            ],
          ),
        ),
        if (_loading)
          const Positioned(
            left: 22,
            bottom: 24,
            child: _MapLoadingPill(),
          ),
        if (_navigating && _selectedRoute != null)
          Positioned(
            left: 16,
            right: 16,
            top: topInset + 8,
            child: _TripDetailsDropdown(
              destination: _candidate,
              route: _selectedRoute!,
              onStop: _resetNavigation,
            ),
          ),
      ],
    );
  }

  bool get _hasGoogleMapsKey => _googleMapsApiKey.isNotEmpty;

  Future<void> _warmCurrentLocation() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_hasGoogleMapsKey || _currentLocation != null) {
      return;
    }
    await _loadCurrentLocation(silent: true);
  }

  Future<void> _centerOnCurrentLocation() async {
    if (_navigating && _departureLocation != null && _mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_departureLocation!, 17),
      );
      return;
    }
    await _loadCurrentLocation();
    if (_mapController == null) {
      return;
    }
    final location = _currentLocation;
    if (location == null) {
      return;
    }
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(location, 17),
    );
  }

  Future<void> _loadCurrentLocation({bool silent = false}) async {
    if (!_hasGoogleMapsKey) {
      if (!silent) {
        setState(() {
          _statusMessage = null;
        });
      }
      return;
    }
    if (!silent) {
      setState(() => _loading = true);
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
          setState(() {
            _statusMessage =
                'Turn on location services to show your position.';
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) {
          return;
        }
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
          setState(() {
            _statusMessage =
                'Location permission is needed to start from your current position.';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final location = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      if (!_isGreaterKlLocation(location)) {
        if (!silent) {
          setState(() {
            _statusMessage =
                'Device GPS is reporting a location outside Greater KL. Check emulator/mock location or precise location settings.';
          });
        }
        return;
      }
      if (position.accuracy > 120 ||
          (_currentLocation != null && position.accuracy > 80)) {
        if (!silent) {
          setState(() {
            _statusMessage =
                'Location accuracy is still low. Turn on precise location, then try again.';
          });
        }
        return;
      }
      setState(() {
        _currentLocation = location;
        _currentAccuracyMeters = position.accuracy;
        _lastMapCenter = location;
        if (!silent) {
          _statusMessage = null;
        }
      });
      if (!silent) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(location, 17),
        );
      }
    } catch (error) {
      if (!silent && mounted) {
        setState(
          () => _statusMessage = 'Unable to read current location: $error',
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _searchDestination() async {
    final query = _toController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _candidate = null;
        _candidates = const [];
        _routes = const [];
        _selectedRoute = null;
        _statusMessage = null;
      });
      return;
    }
    if (!_hasGoogleMapsKey) {
      final candidates = _previewCandidates(query);
      setState(() {
        _candidate = candidates.first;
        _candidates = candidates;
        _routes = const [];
        _selectedRoute = null;
        _statusMessage =
            'Preview mode. Add a Google Maps API key for live place results and directions.';
        _navigating = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
      _candidate = null;
      _candidates = const [];
      _routes = const [];
      _selectedRoute = null;
      _navigating = false;
    });

    try {
      if (_currentLocation == null) {
        await _loadCurrentLocation(silent: true);
      }
      final candidates = await _GoogleMapsApi.findPlaces(
        query: query,
        apiKey: _googleMapsApiKey,
      );
      setState(() {
        _candidate = candidates.isEmpty ? null : candidates.first;
        _candidates = candidates;
        _statusMessage = candidates.isEmpty
            ? 'No places found. Try a more specific address or landmark.'
            : null;
      });
      if (candidates.isNotEmpty) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(candidates.first.location, 14.5),
        );
      }
    } catch (error) {
      setState(() => _statusMessage = 'Place search failed: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _calculateDirections(DestinationCandidate destination) async {
    await _loadCurrentLocation(silent: true);
    setState(() {
      _candidate = destination;
      _routes = const [];
      _selectedRoute = null;
      _navigating = false;
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_routingOrigin, 15),
    );

    final origin = _routingOrigin;
    if (!_hasGoogleMapsKey) {
      final routes = _previewRoutes(destination);
      setState(() {
        _routes = routes;
        _selectedRoute = null;
        _statusMessage = _usingFallbackDeparture
            ? 'Device GPS looks unreliable, so planning starts from the Kuala Lumpur map area until a precise current location is available.'
            : 'Preview routes shown. Connect Google Maps API for real travel time and path interpolation.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    try {
      final routes = await _GoogleMapsApi.fetchTransitDirections(
        origin: origin,
        destination: destination,
        apiKey: _googleMapsApiKey,
      );
      setState(() {
        _routes = routes;
        _selectedRoute = null;
      });
      if (routes.isNotEmpty) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_routingOrigin, 15),
        );
      } else {
        setState(() => _statusMessage = 'No Google transit route found.');
      }
    } catch (error) {
      if (_isGoogleRoutesUnavailable(error)) {
        final routes = _previewRoutes(destination);
        setState(() {
          _routes = routes;
          _selectedRoute = null;
          _statusMessage = _usingFallbackDeparture
              ? 'Device GPS looks unreliable, so planning starts from the Kuala Lumpur map area until a precise current location is available.'
              : null;
        });
      } else {
        setState(() => _statusMessage = 'Directions failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startPlannedRoute(TransitOption route) {
    final departure = route.legs.isNotEmpty && route.legs.first.points.isNotEmpty
        ? route.legs.first.points.first
        : route.points.isNotEmpty
            ? route.points.first
            : _routingOrigin;
    final departureName = route.legs.isNotEmpty
        ? route.legs.first.fromName
        : _routingOriginName;
    setState(() {
      _departureLocation = departure;
      _departureName = departureName;
      _lastMapCenter = departure;
      _selectedRoute = route;
      _navigating = true;
      _statusMessage = null;
    });
    unawaited(_focusStartLeg(route));
  }

  Future<void> _focusStartLeg(TransitOption route) async {
    final firstLeg = route.legs.isEmpty ? route.points : route.legs.first.points;
    if (firstLeg.isEmpty) {
      return;
    }
    await _fitRoute(firstLeg, padding: 110);
  }

  Future<void> _fitRoute(List<LatLng> points, {double padding = 72}) async {
    if (points.isEmpty || _mapController == null) {
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        padding,
      ),
    );
  }

  void _resetNavigation() {
    setState(() {
      _candidate = null;
      _candidates = const [];
      _routes = const [];
      _selectedRoute = null;
      _statusMessage = null;
      _navigating = false;
      _departureLocation = null;
      _departureName = null;
      _toController.clear();
    });
  }

  List<DestinationCandidate> _previewCandidates(String query) {
    return [
      DestinationCandidate(
        name: query,
        address: 'Kuala Lumpur City Centre, Kuala Lumpur, Malaysia',
        location: const LatLng(3.1579, 101.7123),
        placeId: 'preview-primary',
      ),
      DestinationCandidate(
        name: '$query Sentral',
        address: 'KL Sentral, Brickfields, Kuala Lumpur, Malaysia',
        location: const LatLng(3.1340, 101.6869),
        placeId: 'preview-sentral',
      ),
      DestinationCandidate(
        name: '$query Bukit Bintang',
        address: 'Bukit Bintang, Kuala Lumpur, Malaysia',
        location: const LatLng(3.1468, 101.7113),
        placeId: 'preview-bukit-bintang',
      ),
    ];
  }

  bool _isGoogleRoutesUnavailable(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('routes api has not been used') ||
        message.contains('routes.googleapis.com') ||
        message.contains('api has not been enabled') ||
        message.contains('has not been used in project') ||
        message.contains('disabled') ||
        message.contains('enable it by visiting') ||
        message.contains('api') ||
        message.contains('google') ||
        message.contains('permission denied');
  }

  List<TransitOption> _previewRoutes([DestinationCandidate? destination]) {
    final destinationLocation = destination?.location;
    final target = destinationLocation != null &&
            _isGreaterKlLocation(destinationLocation)
        ? destinationLocation
        : const LatLng(3.1579, 101.7123);
    final origin = _routingOrigin;
    final originName = _routingOriginName;
    return [
      TransitOption(
        label: 'Best Transit',
        chain: 'Walk -> Nearest rail -> Connector',
        time: '34 min',
        distance: '8.4 km',
        fare: 'RM 4.80',
        transfers: '3 steps',
        crowd: .52,
        color: const Color(0xFF22B8F2),
        legs: _previewRouteLegs(origin, originName, target, 0),
        firstStopLabel: 'Nearest rail station',
        nextInstruction: 'Head to the nearest rail station',
      ),
      TransitOption(
        label: 'Minimum Transfer',
        chain: 'Walk -> Nearest rail -> Walk',
        time: '42 min',
        distance: '9.1 km',
        fare: 'RM 5.20',
        transfers: '2 steps',
        crowd: .44,
        color: const Color(0xFF00C48C),
        legs: _previewRouteLegs(origin, originName, target, 1),
        firstStopLabel: 'Nearest rail station',
        nextInstruction: 'Walk toward the nearest rail platform',
      ),
      TransitOption(
        label: 'Cheapest',
        chain: 'Walk -> Nearest rail -> Rapid KL Bus -> Walk',
        time: '58 min',
        distance: '7.8 km',
        fare: 'RM 2.60',
        transfers: '3 steps',
        crowd: .36,
        color: const Color(0xFFFFB000),
        legs: _previewRouteLegs(origin, originName, target, 2),
        firstStopLabel: 'Nearest rail station',
        nextInstruction: 'Walk to the nearest rail station',
      ),
    ];
  }

  LatLng get _routingOrigin {
    final location = _currentLocation;
    if (location != null && _isGreaterKlLocation(location)) {
      return location;
    }
    final departure = _departureLocation;
    if (departure != null && _isGreaterKlLocation(departure)) {
      return departure;
    }
    if (_candidate == null && _isGreaterKlLocation(_lastMapCenter)) {
      return _lastMapCenter;
    }
    return const LatLng(3.1478, 101.6953);
  }

  String get _routingOriginName {
    final location = _currentLocation;
    if (location != null && _isGreaterKlLocation(location)) {
      return 'Current location';
    }
    final departure = _departureLocation;
    if (departure != null && _isGreaterKlLocation(departure)) {
      return _departureName ?? 'Selected departure point';
    }
    if (_candidate == null && _isGreaterKlLocation(_lastMapCenter)) {
      return 'Selected map area';
    }
    return 'Kuala Lumpur map area';
  }

  bool get _usingFallbackDeparture {
    final location = _currentLocation;
    return location == null || !_isGreaterKlLocation(location);
  }

  bool _isGreaterKlLocation(LatLng location) {
    return location.latitude >= 2.85 &&
        location.latitude <= 3.35 &&
        location.longitude >= 101.45 &&
        location.longitude <= 102.05;
  }

  static const _lrtStops = [
    _TransitStop('Masjid Jamek LRT Station', LatLng(3.1494, 101.6961)),
    _TransitStop('Dang Wangi LRT Station', LatLng(3.1567, 101.7018)),
    _TransitStop('Kampung Baru LRT Station', LatLng(3.1612, 101.7069)),
    _TransitStop('KLCC LRT Station', LatLng(3.1590, 101.7132)),
    _TransitStop('Ampang Park LRT Station', LatLng(3.1605, 101.7197)),
    _TransitStop('Damai LRT Station', LatLng(3.1643, 101.7240)),
    _TransitStop('Dato Keramat LRT Station', LatLng(3.1653, 101.7306)),
    _TransitStop('Jelatek LRT Station', LatLng(3.1672, 101.7357)),
    _TransitStop('Setiawangsa LRT Station', LatLng(3.1758, 101.7357)),
    _TransitStop('Sri Rampai LRT Station', LatLng(3.1995, 101.7375)),
    _TransitStop('Wangsa Maju LRT Station', LatLng(3.2056, 101.7317)),
    _TransitStop('Taman Melati LRT Station', LatLng(3.2194, 101.7227)),
  ];

  static const _mrtStops = [
    _TransitStop('Batu 11 Cheras MRT Station', LatLng(3.0613, 101.7738)),
    _TransitStop('Bandar Tun Hussein Onn MRT Station', LatLng(3.0487, 101.7758)),
    _TransitStop('Bukit Dukung MRT Station', LatLng(3.0338, 101.7712)),
    _TransitStop('Sri Raya MRT Station', LatLng(3.0640, 101.7542)),
    _TransitStop('Kajang MRT Station', LatLng(2.9837, 101.7906)),
    _TransitStop('Bukit Bintang MRT Entrance A', LatLng(3.1469, 101.7114)),
    _TransitStop('Tun Razak Exchange MRT Station', LatLng(3.1422, 101.7206)),
    _TransitStop('Pasar Seni MRT Platform', LatLng(3.1420, 101.6950)),
    _TransitStop('Merdeka MRT Station', LatLng(3.1413, 101.7022)),
  ];

  static const _railStops = [
    ..._lrtStops,
    ..._mrtStops,
    _TransitStop('Hang Tuah Monorail Station', LatLng(3.1408, 101.7060)),
    _TransitStop('Maharajalela Monorail Station', LatLng(3.1381, 101.6993)),
    _TransitStop('Imbi Monorail Station', LatLng(3.1423, 101.7098)),
    _TransitStop('Raja Chulan Monorail Station', LatLng(3.1500, 101.7108)),
    _TransitStop('Medan Tuanku Monorail Station', LatLng(3.1593, 101.6996)),
    _TransitStop('Kuala Lumpur KTM Station', LatLng(3.1394, 101.6936)),
    _TransitStop('Bank Negara KTM Station', LatLng(3.1584, 101.6936)),
  ];

  _TransitStop _nearestStop(LatLng origin, List<_TransitStop> stops) {
    var nearest = stops.first;
    var bestMeters = double.infinity;
    for (final stop in stops) {
      final meters = _metersBetween(origin, stop.location);
      if (meters < bestMeters) {
        bestMeters = meters;
        nearest = stop;
      }
    }
    return nearest;
  }

  String _railMode(_TransitStop stop) {
    final name = stop.name.toLowerCase();
    if (name.contains('mrt')) {
      return 'MRT';
    }
    if (name.contains('monorail')) {
      return 'KL Monorail';
    }
    if (name.contains('ktm')) {
      return 'KTM Komuter';
    }
    return 'LRT';
  }

  List<RouteLeg> _previewRouteLegs(
    LatLng origin,
    String originName,
    LatLng target,
    int variant,
  ) {
    final destinationName = _candidate?.name ?? 'Destination';
    final nearestRail = _nearestStop(origin, _railStops);
    final railWalkDistance = _formatLegDistance(
      _walkingMeters(origin, nearestRail.location),
    );
    final railWalkTime = _formatLegMinutes(
      _walkingMinutes(origin, nearestRail.location),
    );
    final railTransitMeters = _metersBetween(
      nearestRail.location,
      const LatLng(3.1590, 101.7132),
    );
    final railTransitDistance = _formatLegDistance(railTransitMeters * 1.12);
    final railTransitTime = _formatLegMinutes(
      max(6, (railTransitMeters / 520).round()),
    );
    final railMode = _railMode(nearestRail);
    final routes = [
      [
        _leg(
          originName,
          nearestRail.name,
          'Walk',
          railWalkTime,
          railWalkDistance,
          Icons.directions_walk_rounded,
          _roadLikePath(origin, nearestRail.location, bend: .0008),
        ),
        _leg(
          nearestRail.name,
          'Pasar Seni MRT Platform',
          railMode,
          '9 min',
          '3.2 km',
          Icons.train_rounded,
          _roadLikePath(
            nearestRail.location,
            const LatLng(3.1420, 101.6950),
            bend: -.0011,
          ),
        ),
        _leg(
          'Pasar Seni MRT Platform',
          'KLCC LRT Station',
          'LRT Kelana Jaya Line',
          '13 min',
          '4.1 km',
          Icons.directions_transit_rounded,
          _roadLikePath(const LatLng(3.1420, 101.6950), target, bend: .0012),
        ),
      ],
      [
        _leg(
          originName,
          nearestRail.name,
          'Walk',
          railWalkTime,
          railWalkDistance,
          Icons.directions_walk_rounded,
          _roadLikePath(origin, nearestRail.location, bend: -.0008),
        ),
        _leg(
          nearestRail.name,
          'KLCC LRT Station',
          railMode,
          railTransitTime,
          railTransitDistance,
          Icons.train_rounded,
          _roadLikePath(nearestRail.location, target, bend: .0009),
        ),
      ],
      [
        _leg(
          originName,
          nearestRail.name,
          'Walk',
          railWalkTime,
          railWalkDistance,
          Icons.directions_walk_rounded,
          _roadLikePath(origin, nearestRail.location, bend: .0006),
        ),
        _leg(
          nearestRail.name,
          'Pasar Seni LRT Platform',
          railMode,
          railTransitTime,
          railTransitDistance,
          Icons.train_rounded,
          _roadLikePath(
            nearestRail.location,
            const LatLng(3.1420, 101.6950),
            bend: -.0007,
          ),
        ),
        _leg(
          'Pasar Seni Bus Hub',
          'KLCC North Bus Stop',
          'Rapid KL Bus 300',
          '18 min',
          '3.4 km',
          Icons.directions_bus_rounded,
          _roadLikePath(
            const LatLng(3.1420, 101.6950),
            const LatLng(3.1584, 101.7120),
            bend: .0011,
          ),
        ),
        _leg(
          'KLCC North Bus Stop',
          destinationName,
          'Walk',
          '5 min',
          '350 m',
          Icons.directions_walk_rounded,
          _roadLikePath(const LatLng(3.1584, 101.7120), target, bend: .0004),
        ),
      ],
    ];
    return routes[variant % routes.length];
  }

  RouteLeg _leg(
    String fromName,
    String toName,
    String mode,
    String time,
    String distance,
    IconData icon,
    List<LatLng> points,
  ) {
    return RouteLeg(
      fromName: fromName,
      toName: toName,
      mode: mode,
      time: time,
      distance: distance,
      icon: icon,
      points: points,
    );
  }

  List<LatLng> _roadLikePath(LatLng from, LatLng to, {required double bend}) {
    final firstTurn = LatLng(
      from.latitude,
      (from.longitude + to.longitude) / 2 + bend,
    );
    final secondTurn = LatLng(
      (from.latitude + to.latitude) / 2 - bend,
      firstTurn.longitude,
    );
    final thirdTurn = LatLng(secondTurn.latitude, to.longitude);
    return [from, firstTurn, secondTurn, thirdTurn, to];
  }

  double _metersBetween(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  double _walkingMeters(LatLng from, LatLng to) {
    return _metersBetween(from, to) * 1.25;
  }

  int _walkingMinutes(LatLng from, LatLng to) {
    return max(2, (_walkingMeters(from, to) / 78).round());
  }

  String _formatLegMinutes(num minutes) {
    return '${minutes.round()} min';
  }

  String _formatLegDistance(num meters) {
    if (meters < 950) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class HubPoolScreen extends StatefulWidget {
  const HubPoolScreen({
    required this.wallet,
    required this.onFareDeducted,
    super.key,
  });

  final double wallet;
  final ValueChanged<double> onFareDeducted;

  @override
  State<HubPoolScreen> createState() => _HubPoolScreenState();
}

class _HubPoolScreenState extends State<HubPoolScreen>
    with SingleTickerProviderStateMixin {
  final _destinationController = TextEditingController();
  GoogleMapController? _mapController;
  final _drivers = const [
    Driver(
      'Ali',
      'EV Proton e.MAS 7',
      '4.9',
      Color(0xFF00E2A7),
      LatLng(3.1529, 101.7049),
    ),
    Driver(
      'Candy',
      'Hyundai Ioniq 5',
      '4.8',
      Color(0xFF40A9FF),
      LatLng(3.1421, 101.6953),
    ),
    Driver(
      'Jenny',
      'BYD Dolphin',
      '4.7',
      Color(0xFFFFCE3D),
      LatLng(3.1623, 101.7118),
    ),
  ];
  late final AnimationController _carController;
  Timer? _timer;
  RideStage _stage = RideStage.idle;
  Driver? _driver;
  DestinationCandidate? _destination;
  TransitOption? _route;
  int _seconds = 0;
  bool _fareDeducted = false;
  static const _origin = LatLng(3.1478, 101.6953);
  static const _originName = 'Current pickup point';

  @override
  void initState() {
    super.initState();
    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..addListener(() {
        if (mounted && _stage == RideStage.tracking) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _carController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _bookRide() {
    final destination = _selectedDestination;
    final rideDistanceKm = _rideDistanceKm(destination.location);
    final fare = _fareForDistance(rideDistanceKm);
    if (widget.wallet < fare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top up credit before booking.')),
      );
      return;
    }
    _timer?.cancel();
    _carController.reset();
    setState(() {
      _stage = RideStage.matching;
      _seconds = 10;
      _driver = null;
      _destination = destination;
      _route = null;
      _fareDeducted = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        final index = DateTime.now().millisecond % _drivers.length;
        final driver = _drivers[index];
        setState(() {
          _stage = RideStage.tracking;
          _driver = driver;
          _route = _approachRoute(driver);
          _seconds = 60;
        });
        _carController.forward(from: 0);
        unawaited(_fitRoute(_route?.points ?? const []));
        _startTrackingTimer();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _startTrackingTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        final destination = _destination ?? _selectedDestination;
        final fare = _fareForDistance(_rideDistanceKm(destination.location));
        if (!_fareDeducted) {
          widget.onFareDeducted(fare);
        }
        setState(() {
          _seconds = 0;
          _stage = RideStage.onboard;
          _route = _destinationRoute(destination);
          _fareDeducted = true;
        });
        unawaited(_fitRoute(_route?.points ?? const []));
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _cancelRide() {
    _timer?.cancel();
    _carController.stop();
    setState(() {
      _stage = RideStage.cancelled;
      _seconds = 0;
      _route = null;
    });
  }

  void _resetRide() {
    _timer?.cancel();
    _carController.reset();
    setState(() {
      _stage = RideStage.idle;
      _seconds = 0;
      _driver = null;
      _destination = null;
      _route = null;
      _fareDeducted = false;
    });
  }

  DestinationCandidate get _selectedDestination {
    final query = _destinationController.text.trim().toLowerCase();
    final fallback = _hubDestinations.first;
    return _hubDestinations.firstWhere(
      (destination) =>
          query.isNotEmpty &&
          (destination.name.toLowerCase().contains(query) ||
              destination.address.toLowerCase().contains(query)),
      orElse: () => fallback,
    );
  }

  List<DestinationCandidate> get _visibleDestinations {
    final query = _destinationController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _hubDestinations;
    }
    final matches = _hubDestinations
        .where(
          (destination) =>
              destination.name.toLowerCase().contains(query) ||
              destination.address.toLowerCase().contains(query),
        )
        .toList();
    return matches.isEmpty ? _hubDestinations : matches;
  }

  LatLng? get _vehicleLocation {
    final driver = _driver;
    if (driver == null) {
      return null;
    }
    if (_stage == RideStage.tracking) {
      return _pointAlongPath(_route?.points ?? const [], _carController.value);
    }
    if (_stage == RideStage.onboard) {
      return _origin;
    }
    return driver.startLocation;
  }

  double get _selectedDistanceKm =>
      _rideDistanceKm((_destination ?? _selectedDestination).location);

  double get _selectedFare => _fareForDistance(_selectedDistanceKm);

  TransitOption _approachRoute(Driver driver) {
    final distanceKm = _rideDistanceKm(driver.startLocation, to: _origin);
    final minutes = max(1, (distanceKm * 3).round());
    return TransitOption(
      label: 'Driver approach',
      chain: '${driver.vehicle} -> Pickup',
      time: '1 min demo',
      distance: '${distanceKm.toStringAsFixed(1)} km',
      fare: 'No charge yet',
      transfers: 'Pickup',
      crowd: .2,
      color: driver.color,
      legs: [
        RouteLeg(
          fromName: '${driver.name} nearby',
          toName: _originName,
          mode: driver.vehicle,
          time: '$minutes min',
          distance: '${distanceKm.toStringAsFixed(1)} km',
          icon: Icons.local_taxi_rounded,
          points: _roadPath(driver.startLocation, _origin, bend: .0012),
        ),
      ],
      firstStopLabel: _originName,
      nextInstruction: '${driver.name} is driving to your pickup point',
    );
  }

  TransitOption _destinationRoute(DestinationCandidate destination) {
    final distanceKm = _rideDistanceKm(destination.location);
    return TransitOption(
      label: 'Hub-Pool ride',
      chain: 'Pickup -> ${destination.name}',
      time: '${max(4, (distanceKm * 4).round())} min',
      distance: '${distanceKm.toStringAsFixed(1)} km',
      fare: '${_fareForDistance(distanceKm).toStringAsFixed(2)} credit',
      transfers: 'Direct',
      crowd: .2,
      color: const Color(0xFF0B7CFF),
      legs: [
        RouteLeg(
          fromName: _originName,
          toName: destination.name,
          mode: _driver?.vehicle ?? 'Hub-Pool',
          time: '${max(4, (distanceKm * 4).round())} min',
          distance: '${distanceKm.toStringAsFixed(1)} km',
          icon: Icons.directions_car_rounded,
          points: _roadPath(_origin, destination.location, bend: -.0014),
        ),
      ],
      firstStopLabel: destination.name,
      nextInstruction: 'Ride to ${destination.name}',
    );
  }

  List<LatLng> _roadPath(LatLng from, LatLng to, {required double bend}) {
    final firstTurn = LatLng(
      from.latitude,
      (from.longitude + to.longitude) / 2 + bend,
    );
    final secondTurn = LatLng(
      (from.latitude + to.latitude) / 2 - bend,
      firstTurn.longitude,
    );
    final thirdTurn = LatLng(secondTurn.latitude, to.longitude);
    return [from, firstTurn, secondTurn, thirdTurn, to];
  }

  LatLng? _pointAlongPath(List<LatLng> points, double progress) {
    if (points.isEmpty) {
      return null;
    }
    if (points.length == 1) {
      return points.first;
    }
    final clamped = progress.clamp(0, 1).toDouble();
    final position = clamped * (points.length - 1);
    final index = min(points.length - 2, position.floor());
    final segmentProgress = position - index;
    final from = points[index];
    final to = points[index + 1];
    return LatLng(
      from.latitude + (to.latitude - from.latitude) * segmentProgress,
      from.longitude + (to.longitude - from.longitude) * segmentProgress,
    );
  }

  double _rideDistanceKm(LatLng location, {LatLng to = _origin}) {
    final meters = Geolocator.distanceBetween(
      to.latitude,
      to.longitude,
      location.latitude,
      location.longitude,
    );
    return max(.2, meters / 1000);
  }

  double _fareForDistance(double km) {
    return max(.01, double.parse((km * .01).toStringAsFixed(2)));
  }

  Future<void> _fitRoute(List<LatLng> points) async {
    if (points.isEmpty || _mapController == null) {
      return;
    }
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        110,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final destination = _destination ?? _selectedDestination;
    return Stack(
      children: [
        Positioned.fill(
          child: _LiveGoogleMapSurface(
            apiKeyReady: true,
            currentLocation: _origin,
            currentAccuracyMeters: null,
            candidate: destination,
            selectedRoute: _route,
            navigating: _stage == RideStage.tracking ||
                _stage == RideStage.onboard,
            vehicleLocation: _vehicleLocation,
            vehicleColor: _driver?.color,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onCameraMove: (_) {},
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: topInset + 8,
          child: _HubPoolOverlay(
            controller: _destinationController,
            stage: _stage,
            seconds: _seconds,
            wallet: widget.wallet,
            fare: _selectedFare,
            distanceKm: _selectedDistanceKm,
            driver: _driver,
            destinations: _visibleDestinations,
            selectedDestination: destination,
            onTextChanged: () => setState(() {}),
            onSelectDestination: (candidate) {
              setState(() {
                _destinationController.text = candidate.name;
                _destination = candidate;
              });
              unawaited(
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(candidate.location, 14.5),
                ),
              );
            },
            onBook: _bookRide,
            onCancel: _stage == RideStage.matching ||
                    _stage == RideStage.tracking
                ? _cancelRide
                : null,
            onReset: _stage == RideStage.cancelled ? _resetRide : null,
          ),
        ),
      ],
    );
  }

  static const _hubDestinations = [
    DestinationCandidate(
      name: 'TRX Exchange',
      address: 'Tun Razak Exchange, Kuala Lumpur',
      location: LatLng(3.1421, 101.7184),
      placeId: 'hub-trx',
    ),
    DestinationCandidate(
      name: 'Suria KLCC',
      address: 'Kuala Lumpur City Centre',
      location: LatLng(3.1579, 101.7123),
      placeId: 'hub-klcc',
    ),
    DestinationCandidate(
      name: 'KL Sentral',
      address: 'Brickfields, Kuala Lumpur',
      location: LatLng(3.1340, 101.6869),
      placeId: 'hub-sentral',
    ),
    DestinationCandidate(
      name: 'Bukit Bintang',
      address: 'Bukit Bintang, Kuala Lumpur',
      location: LatLng(3.1468, 101.7113),
      placeId: 'hub-bukit-bintang',
    ),
  ];
}

class _HubPoolOverlay extends StatelessWidget {
  const _HubPoolOverlay({
    required this.controller,
    required this.stage,
    required this.seconds,
    required this.wallet,
    required this.fare,
    required this.distanceKm,
    required this.driver,
    required this.destinations,
    required this.selectedDestination,
    required this.onTextChanged,
    required this.onSelectDestination,
    required this.onBook,
    required this.onCancel,
    required this.onReset,
  });

  final TextEditingController controller;
  final RideStage stage;
  final int seconds;
  final double wallet;
  final double fare;
  final double distanceKm;
  final Driver? driver;
  final List<DestinationCandidate> destinations;
  final DestinationCandidate selectedDestination;
  final VoidCallback onTextChanged;
  final ValueChanged<DestinationCandidate> onSelectDestination;
  final VoidCallback onBook;
  final VoidCallback? onCancel;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final title = switch (stage) {
      RideStage.idle => 'Book Hub-Pool',
      RideStage.matching => 'Finding a driver',
      RideStage.tracking => '${driver?.name ?? 'Driver'} is arriving',
      RideStage.onboard => 'Ride started',
      RideStage.completed => 'Ride completed',
      RideStage.cancelled => 'Ride cancelled',
    };
    final subtitle = switch (stage) {
      RideStage.idle => '${distanceKm.toStringAsFixed(1)} km / ${fare.toStringAsFixed(2)} credit',
      RideStage.matching => 'Confirmed. Matching in $seconds sec',
      RideStage.tracking => 'Arrives in $seconds sec',
      RideStage.onboard => '${driver?.vehicle ?? 'Vehicle'} to ${selectedDestination.name}',
      RideStage.completed => 'Fare deducted',
      RideStage.cancelled => 'You can book again',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22001844),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0B7CFF),
                child: const Icon(
                  Icons.local_taxi_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                wallet.toStringAsFixed(2),
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stage == RideStage.idle || stage == RideStage.cancelled) ...[
            TextField(
              controller: controller,
              onChanged: (_) => onTextChanged(),
              style: const TextStyle(color: Color(0xFF172033)),
              decoration: InputDecoration(
                hintText: 'Search destination',
                hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF0F4FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final destination in destinations.take(3)) ...[
              _HubDestinationTile(
                destination: destination,
                selected: destination.placeId == selectedDestination.placeId,
                onTap: () => onSelectDestination(destination),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('book-ride'),
                onPressed: onBook,
                icon: const Icon(Icons.local_taxi_rounded),
                label: const Text('Book Ride'),
              ),
            ),
            if (onReset != null)
              TextButton(
                onPressed: onReset,
                child: const Text('Reset'),
              ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: stage == RideStage.matching
                    ? (10 - seconds).clamp(0, 10) / 10
                    : stage == RideStage.tracking
                        ? (60 - seconds).clamp(0, 60) / 60
                        : 1,
                backgroundColor: const Color(0xFFE7EEF8),
                color: const Color(0xFF0B7CFF),
              ),
            ),
            if (driver != null) ...[
              const SizedBox(height: 12),
              _DriverCard(driver: driver!),
            ],
            if (onCancel != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Cancel Ride'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _HubDestinationTile extends StatelessWidget {
  const _HubDestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final DestinationCandidate destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F2FF) : const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF0B7CFF) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_rounded, color: Color(0xFF0B7CFF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    destination.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PelancongPlanScreen extends StatefulWidget {
  const PelancongPlanScreen({required this.onGoViaTransit, super.key});

  final ValueChanged<String> onGoViaTransit;

  @override
  State<PelancongPlanScreen> createState() => _PelancongPlanScreenState();
}

class _PelancongPlanScreenState extends State<PelancongPlanScreen> {
  double _radius = 10;
  List<Attraction> _spots = [];
  bool _accepted = false;

  final List<Attraction> _database = const [
    Attraction('KLCC Park', '10:00 - 22:00', 4.7, 0, Color(0xFF40A9FF)),
    Attraction('Central Market', '10:00 - 20:00', 4.5, 25, Color(0xFF00E2A7)),
    Attraction('Batu Caves', '07:00 - 21:00', 4.8, 15, Color(0xFFFFCE3D)),
    Attraction('Merdeka 118 View', '09:00 - 18:00', 4.6, 60, Color(0xFF7C5CFF)),
    Attraction('River of Life', '11:00 - 23:00', 4.4, 10, Color(0xFFFF7A59)),
    Attraction('National Mosque', '09:00 - 17:30', 4.6, 0, Color(0xFF38D9FF)),
  ];

  void _generate() {
    final shuffled = List<Attraction>.of(_database)..shuffle(Random());
    setState(() {
      _spots = shuffled.take(3 + Random().nextInt(3)).toList();
      _accepted = false;
    });
  }

  void _removeSpot(Attraction spot) {
    setState(() => _spots = _spots.where((item) => item != spot).toList());
  }

  void _clearAll() {
    setState(() {
      _spots = [];
      _accepted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      children: [
        const _SectionTitle(
          icon: Icons.explore_rounded,
          title: 'PelancongPlan Engine',
          trailing: '3-5 stops',
        ),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Radius: ${_radius.toStringAsFixed(0)} km',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Slider(
                value: _radius,
                min: 5,
                max: 20,
                divisions: 3,
                label: '${_radius.toStringAsFixed(0)} km',
                onChanged: (value) => setState(() => _radius = value),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('generate-route'),
                  onPressed: _generate,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Generate Route'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_spots.isEmpty)
          const _MapPreview(
            title: 'Nearby Malaysian gems',
            subtitle: 'Generate a smart 3-5 stop discovery route',
          )
        else ...[
          _ItineraryMap(spots: _spots, accepted: _accepted),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => setState(() => _accepted = true),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Accept Plan'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'All Cancel',
                onPressed: _clearAll,
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final spot in _spots) ...[
            _AttractionCard(
              spot: spot,
              active: _accepted,
              onTransit: () => widget.onGoViaTransit(spot.name),
              onRemove: () => _removeSpot(spot),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class AccountConsoleScreen extends StatelessWidget {
  const AccountConsoleScreen({
    required this.role,
    required this.wallet,
    required this.onTopUp,
    super.key,
  });

  final UserRole role;
  final double wallet;
  final ValueChanged<double> onTopUp;

  @override
  Widget build(BuildContext context) {
    if (role == UserRole.admin) {
      return const _AdminConsole();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      children: [
        const _SectionTitle(
          icon: Icons.account_balance_wallet_rounded,
          title: 'User Wallet',
          trailing: 'SDG 9 log',
        ),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RM ${wallet.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Available app credit for Hub-Pool rides',
                style: TextStyle(color: Colors.white.withValues(alpha: .72)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: () => onTopUp(20),
                    child: const Text('Top Up RM20'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => onTopUp(50),
                    child: const Text('Top Up RM50'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassPanel(
          child: Column(
            children: const [
              _LedgerRow('Saved transit routes', '14'),
              _LedgerRow('Hub-Pool transactions', '6'),
              _LedgerRow('Carbon saved', '28.4 kg CO2e'),
              _LedgerRow('Green travel score', '91 / 100'),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminConsole extends StatelessWidget {
  const _AdminConsole();

  @override
  Widget build(BuildContext context) {
    final users = [
      ('Aina Rahman', 'RM 128.40', 'Active'),
      ('Ben Tan', 'RM 42.00', 'Frozen'),
      ('Chong Wei', 'RM 305.20', 'Active'),
      ('Deepa Kumar', 'RM 76.80', 'Active'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      children: [
        const _SectionTitle(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Admin Console',
          trailing: 'CRUD demo',
        ),
        _GlassPanel(
          child: Column(
            children: [
              for (final user in users)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF0B7CFF),
                        child: Text(user.$1.substring(0, 1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('${user.$2} / ${user.$3}'),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Adjust credit',
                        onPressed: () {},
                        icon: const Icon(Icons.tune_rounded),
                      ),
                      IconButton(
                        tooltip: 'Freeze profile',
                        onPressed: () {},
                        icon: const Icon(Icons.lock_rounded),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassPanel(
          child: Column(
            children: const [
              _LedgerRow('GTFS cache status', 'Loaded'),
              _LedgerRow('Mock ride dispatcher', 'Online'),
              _LedgerRow('Supabase demo tables', 'Healthy'),
              _LedgerRow('Audit events today', '37'),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.role, required this.wallet});

  final UserRole role;
  final double wallet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role == UserRole.admin ? 'Admin Dashboard' : 'Discover KL',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  role == UserRole.admin
                      ? 'Registry and system controls'
                      : 'Wallet RM ${wallet.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: .7)),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFF0B7CFF),
            child: Icon(Icons.person_rounded),
          ),
        ],
      ),
    );
  }
}

class _LoginRoleButton extends StatelessWidget {
  const _LoginRoleButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0B7CFF),
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .68),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlueShell extends StatelessWidget {
  const _BlueShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061827), Color(0xFF083F7C), Color(0xFF06111D)],
        ),
      ),
      child: child,
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF40A9FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(color: Colors.white.withValues(alpha: .62)),
          ),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.icon,
    required this.label,
    required this.controller,
  });

  final IconData icon;
  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        filled: true,
        fillColor: Colors.white.withValues(alpha: .10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MapSearchWindow extends StatelessWidget {
  const _MapSearchWindow({
    required this.fromController,
    required this.toController,
    required this.statusMessage,
    required this.candidate,
    required this.candidates,
    required this.routes,
    required this.selectedRoute,
    required this.navigating,
    required this.onSearch,
    required this.onConfirmDestination,
    required this.onSelectRoute,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final String? statusMessage;
  final DestinationCandidate? candidate;
  final List<DestinationCandidate> candidates;
  final List<TransitOption> routes;
  final TransitOption? selectedRoute;
  final bool navigating;
  final VoidCallback onSearch;
  final ValueChanged<DestinationCandidate> onConfirmDestination;
  final ValueChanged<TransitOption> onSelectRoute;

  @override
  Widget build(BuildContext context) {
    final hasResults =
        statusMessage != null || candidates.isNotEmpty || routes.isNotEmpty;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .62,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2D001844),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F6FB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: Color(0xFF0B7CFF),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fromController.text,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('feature-a-destination'),
                  controller: toController,
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(color: Color(0xFF172033)),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Color(0xFFF2F6FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Search and Navigate',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Search route options',
                onPressed: onSearch,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0B7CFF),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.near_me_rounded),
              ),
            ],
          ),
          if (hasResults) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 12),
                children: [
                  if (statusMessage != null)
                    _SheetNotice(message: statusMessage!),
                  if (candidates.isNotEmpty && routes.isEmpty) ...[
                    const Text(
                      'Choose a destination',
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final option in candidates.take(6)) ...[
                      _DestinationConfirmCard(
                        candidate: option,
                        selected: option == candidate,
                        actionLabel: 'Calculate Distance',
                        onConfirm: () => onConfirmDestination(option),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (candidate != null && routes.isNotEmpty) ...[
                    _DestinationConfirmCard(
                      candidate: candidate!,
                      selected: true,
                      actionLabel: 'Destination Selected',
                      onConfirm: null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (routes.isNotEmpty) ...[
                    Text(
                      navigating
                          ? 'Navigation in progress'
                          : 'Choose a travel option',
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final route in routes) ...[
                      _RouteChoiceCard(
                        route: route,
                        selected: route == selectedRoute,
                        onTap: () => onSelectRoute(route),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveGoogleMapSurface extends StatefulWidget {
  const _LiveGoogleMapSurface({
    required this.apiKeyReady,
    required this.currentLocation,
    required this.currentAccuracyMeters,
    required this.candidate,
    required this.selectedRoute,
    required this.navigating,
    this.vehicleLocation,
    this.vehicleColor,
    required this.onMapCreated,
    required this.onCameraMove,
  });

  final bool apiKeyReady;
  final LatLng? currentLocation;
  final double? currentAccuracyMeters;
  final DestinationCandidate? candidate;
  final TransitOption? selectedRoute;
  final bool navigating;
  final LatLng? vehicleLocation;
  final Color? vehicleColor;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<CameraPosition> onCameraMove;

  static const _defaultKualaLumpur = LatLng(3.1478, 101.6953);

  @override
  State<_LiveGoogleMapSurface> createState() => _LiveGoogleMapSurfaceState();
}

class _LiveGoogleMapSurfaceState extends State<_LiveGoogleMapSurface> {
  bool _mapReady = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.apiKeyReady) {
      return _MapUnavailableSurface(currentLocation: widget.currentLocation);
    }

    final route = widget.selectedRoute;
    final currentLeg = route == null ? const <LatLng>[] : _currentLeg(route);
    final remainingLegs = route == null
        ? const <LatLng>[]
        : _remainingLegs(route);
    final firstStop = currentLeg.length > 1 ? currentLeg.last : null;
    final polylines = <Polyline>{
      if (route != null && currentLeg.length > 1)
        Polyline(
          polylineId: const PolylineId('current_leg'),
          points: currentLeg,
          width: widget.navigating ? 8 : 6,
          color: const Color(0xFF22C7F4),
          zIndex: 2,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      if (route != null && remainingLegs.length > 1)
        Polyline(
          polylineId: const PolylineId('remaining_legs'),
          points: remainingLegs,
          width: widget.navigating ? 7 : 5,
          color: const Color(0xFFE64040),
          zIndex: 1,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };
    final markers = <Marker>{
      if (widget.currentLocation != null)
        Marker(
          markerId: const MarkerId('current_location'),
          position: widget.currentLocation!,
          infoWindow: const InfoWindow(title: 'Current location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      if (widget.candidate != null)
        Marker(
          markerId: const MarkerId('destination'),
          position: widget.candidate!.location,
          infoWindow: InfoWindow(
            title: widget.candidate!.name,
            snippet: widget.candidate!.address,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      if (firstStop != null && widget.navigating)
        Marker(
          markerId: const MarkerId('first_stop'),
          position: firstStop,
          infoWindow: InfoWindow(title: route?.firstStopLabel ?? 'First stop'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      if (widget.vehicleLocation != null)
        Marker(
          markerId: const MarkerId('vehicle'),
          position: widget.vehicleLocation!,
          infoWindow: const InfoWindow(title: 'Driver vehicle'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _markerHueForColor(widget.vehicleColor ?? const Color(0xFF0B7CFF)),
          ),
        ),
    };
    final circles = <Circle>{
      if (widget.currentLocation != null && widget.currentAccuracyMeters != null)
        Circle(
          circleId: const CircleId('current_accuracy'),
          center: widget.currentLocation!,
          radius: widget.currentAccuracyMeters!.clamp(12, 250).toDouble(),
          fillColor: const Color(0x3322C7F4),
          strokeColor: const Color(0xFF22C7F4),
          strokeWidth: 1,
        ),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        _MapUnavailableSurface(currentLocation: widget.currentLocation),
        AnimatedOpacity(
          opacity: _mapReady ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target:
                  widget.currentLocation ??
                  _LiveGoogleMapSurface._defaultKualaLumpur,
              zoom: widget.currentLocation == null ? 12 : 15,
            ),
            onMapCreated: (controller) {
              if (mounted) {
                setState(() => _mapReady = true);
              }
              widget.onMapCreated(controller);
            },
            onCameraMove: widget.onCameraMove,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
            trafficEnabled: widget.navigating,
            markers: markers,
            circles: circles,
            polylines: polylines,
          ),
        ),
      ],
    );
  }

  List<LatLng> _currentLeg(TransitOption route) {
    if (route.legs.isNotEmpty) {
      return route.legs.first.points;
    }
    final points = route.points;
    if (points.length <= 2) {
      return points;
    }
    final endIndex = route.firstLegPointCount.clamp(2, points.length).toInt();
    return points.take(endIndex).toList();
  }

  List<LatLng> _remainingLegs(TransitOption route) {
    if (route.legs.length > 1) {
      final all = <LatLng>[];
      for (final leg in route.legs.skip(1)) {
        if (all.isNotEmpty &&
            leg.points.isNotEmpty &&
            all.last == leg.points.first) {
          all.addAll(leg.points.skip(1));
        } else {
          all.addAll(leg.points);
        }
      }
      return all;
    }
    final points = route.points;
    if (points.length <= 2) {
      return const [];
    }
    final startIndex = (route.firstLegPointCount - 1)
        .clamp(1, points.length - 1)
        .toInt();
    return points.skip(startIndex).toList();
  }

  double _markerHueForColor(Color color) {
    if (color == const Color(0xFFFFCE3D)) {
      return BitmapDescriptor.hueYellow;
    }
    if (color == const Color(0xFF00E2A7)) {
      return BitmapDescriptor.hueGreen;
    }
    if (color == const Color(0xFF40A9FF)) {
      return BitmapDescriptor.hueAzure;
    }
    return BitmapDescriptor.hueBlue;
  }
}

class _MapUnavailableSurface extends StatelessWidget {
  const _MapUnavailableSurface({required this.currentLocation});

  final LatLng? currentLocation;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF1F4),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _NavigationMapPainter(
                routeColor: const Color(0xFF0B7CFF),
                navigating: false,
              ),
            ),
          ),
          if (currentLocation == null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(28),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .84),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x16001844),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Text(
                  'Kuala Lumpur',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetNotice extends StatelessWidget {
  const _SheetNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6DF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFFFA800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              softWrap: true,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationConfirmCard extends StatelessWidget {
  const _DestinationConfirmCard({
    required this.candidate,
    required this.selected,
    required this.actionLabel,
    required this.onConfirm,
  });

  final DestinationCandidate candidate;
  final bool selected;
  final String actionLabel;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFEAF3FF)
            : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFF0B7CFF) : const Color(0xFFE0E7F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFF4B43),
                foregroundColor: Colors.white,
                child: Icon(Icons.place_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      candidate.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF687386)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onConfirm,
              icon: const Icon(Icons.alt_route_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteChoiceCard extends StatelessWidget {
  const _RouteChoiceCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final TransitOption route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? route.color.withValues(alpha: .14)
              : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? route.color : const Color(0xFFE0E7F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: route.color,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.alt_route_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    route.label,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              route.chain,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF687386)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _DarkMiniMetric(Icons.schedule_rounded, route.time),
                const SizedBox(width: 8),
                _DarkMiniMetric(Icons.straighten_rounded, route.distance),
                const SizedBox(width: 8),
                _DarkMiniMetric(Icons.payments_rounded, route.fare),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkMiniMetric extends StatelessWidget {
  const _DarkMiniMetric(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0B7CFF)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripDetailsDropdown extends StatefulWidget {
  const _TripDetailsDropdown({
    required this.destination,
    required this.route,
    required this.onStop,
  });

  final DestinationCandidate? destination;
  final TransitOption route;
  final VoidCallback onStop;

  @override
  State<_TripDetailsDropdown> createState() => _TripDetailsDropdownState();
}

class _TripDetailsDropdownState extends State<_TripDetailsDropdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final destination = widget.destination?.name ?? 'Destination';
    final nextLeg = route.legs.isEmpty ? null : route.legs.first;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .58,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2D001844),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: route.color,
                foregroundColor: Colors.white,
                child: const Icon(Icons.alt_route_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${route.label} / ${route.time} / ${route.distance}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF687386)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _expanded ? 'Hide details' : 'Show details',
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF172033),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Stop navigation',
                onPressed: widget.onStop,
                icon: const Icon(Icons.stop_rounded),
              ),
            ],
          ),
          if (_expanded && nextLeg != null) ...[
            const SizedBox(height: 10),
            _NextLegCard(leg: nextLeg),
          ],
          if (_expanded && route.legs.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < route.legs.length; i++)
              _TripLegRow(
                leg: route.legs[i],
                active: i == 0,
                isLast: i == route.legs.length - 1,
              ),
          ],
          ],
        ),
      ),
    );
  }
}

class _NextLegCard extends StatelessWidget {
  const _NextLegCard({required this.leg});

  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C7F4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me_rounded, color: Color(0xFF0B7CFF)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next: ${leg.toName}',
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${leg.mode} / ${leg.time} / ${leg.distance}',
                  style: const TextStyle(color: Color(0xFF687386)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripLegRow extends StatelessWidget {
  const _TripLegRow({
    required this.leg,
    required this.active,
    required this.isLast,
  });

  final RouteLeg leg;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF22C7F4) : const Color(0xFFE64040);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: Icon(leg.icon, size: 17),
              ),
              if (!isLast)
                Container(
                  width: 3,
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: const Color(0xFFE0E7F0),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFEAF8FF)
                    : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${leg.fromName} to ${leg.toName}',
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${leg.mode} / ${leg.time} / ${leg.distance}',
                    style: const TextStyle(color: Color(0xFF687386)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  const _RoundMapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B7CFF),
        elevation: 6,
      ),
      icon: Icon(icon),
    );
  }
}

class _MapLoadingPill extends StatelessWidget {
  const _MapLoadingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22001844),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFF0B7CFF),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Loading',
            style: TextStyle(
              color: Color(0xFF172033),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF8DD9FF), Color(0xFFB9F0D4)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: _GlassPanel(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFF0B7CFF),
                    child: Icon(Icons.search_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(subtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RideStatusPanel extends StatelessWidget {
  const _RideStatusPanel({
    required this.stage,
    required this.seconds,
    required this.driver,
    required this.carAnimation,
    required this.onCancel,
  });

  final RideStage stage;
  final int seconds;
  final Driver? driver;
  final Animation<double> carAnimation;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final title = switch (stage) {
      RideStage.idle => 'Ready for deterministic match',
      RideStage.matching => 'Searching drivers... $seconds',
      RideStage.tracking => '${driver?.name} is arriving... $seconds',
      RideStage.onboard => 'Ride started. Driver is heading to destination.',
      RideStage.completed => 'Trip completed. Fare deducted.',
      RideStage.cancelled => 'Ride cancelled.',
    };

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (stage == RideStage.matching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            )
          else
            _TrackingMap(
              animation: carAnimation,
              active: stage == RideStage.tracking,
            ),
          if (driver != null) ...[
            const SizedBox(height: 14),
            _DriverCard(driver: driver!),
          ],
          if (onCancel != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('Cancel Ride'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingMap extends StatelessWidget {
  const _TrackingMap({required this.animation, required this.active});

  final Animation<double> animation;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2742), Color(0xFF0B7CFF)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          const Positioned(
            right: 28,
            bottom: 34,
            child: Icon(Icons.location_pin, color: Color(0xFF00E2A7), size: 42),
          ),
          AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = active ? animation.value : 0.08;
              return Positioned(
                left: 24 + (MediaQuery.sizeOf(context).width - 120) * t,
                top: 164 - (104 * t),
                child: Transform.rotate(
                  angle: -.45 + t,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      color: Color(0xFF0B7CFF),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: driver.color,
          child: Text(driver.name.substring(0, 1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${driver.vehicle} / rating ${driver.rating}',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
        const Icon(Icons.star_rounded, color: Color(0xFFFFCE3D)),
      ],
    );
  }
}

class _ItineraryMap extends StatelessWidget {
  const _ItineraryMap({required this.spots, required this.accepted});

  final List<Attraction> spots;
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFFBDEBDE),
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          Positioned.fill(
            child: CustomPaint(painter: _PolylinePainter(spots.length)),
          ),
          for (var i = 0; i < spots.length; i++)
            Positioned(
              left: 34.0 + (i % 2) * 156,
              top: 30.0 + i * 38,
              child: _MapPin(number: i + 1, color: spots[i].color),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _GlassPanel(
              child: Text(
                accepted
                    ? 'Smart sequence accepted: tap Start on a stop for transit routing.'
                    : 'Preview route overlay: ${spots.length} generated stops.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttractionCard extends StatelessWidget {
  const _AttractionCard({
    required this.spot,
    required this.active,
    required this.onTransit,
    required this.onRemove,
  });

  final Attraction spot;
  final bool active;
  final VoidCallback onTransit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: spot.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.landscape_rounded, size: 42),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spot.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text('${spot.hours} / ${spot.isOpen ? 'OPEN' : 'CLOSED'}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFCE3D),
                      size: 18,
                    ),
                    Text(' ${spot.rating} / Cost RM ${spot.cost}'),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: active ? onTransit : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start'),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Cancel single spot',
                      onPressed: onRemove,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _SkylineBackdrop extends StatelessWidget {
  const _SkylineBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SkylinePainter());
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) => Container(
          width: index == 1 ? 10 : 8,
          height: index == 1 ? 10 : 8,
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: index == 1 ? 1 : .48),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Text(
        '$number',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..color = const Color(0xFF0A5CB9);
    canvas.drawRect(Offset.zero & size, sky);
    final cloud = Paint()..color = Colors.white.withValues(alpha: .88);
    for (final offset in [
      Offset(size.width * .18, size.height * .2),
      Offset(size.width * .78, size.height * .08),
      Offset(size.width * .84, size.height * .28),
    ]) {
      canvas.drawCircle(offset, 12, cloud);
      canvas.drawCircle(offset + const Offset(16, 4), 10, cloud);
      canvas.drawCircle(offset + const Offset(-14, 6), 8, cloud);
    }
    final building = Paint()..color = const Color(0xCC031B35);
    final randomHeights = [140.0, 190.0, 120.0, 210.0, 165.0, 132.0, 178.0];
    final width = size.width / randomHeights.length;
    for (var i = 0; i < randomHeights.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          i * width,
          size.height - randomHeights[i],
          width - 8,
          randomHeights[i],
        ),
        building,
      );
    }
    final water = Paint()..color = const Color(0xAA052B55);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * .76, size.width, size.height * .24),
      water,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavigationMapPainter extends CustomPainter {
  const _NavigationMapPainter({
    required this.routeColor,
    required this.navigating,
  });

  final Color routeColor;
  final bool navigating;

  @override
  void paint(Canvas canvas, Size size) {
    final land = Paint()..color = const Color(0xFFEAF1F4);
    canvas.drawRect(Offset.zero & size, land);

    final park = Paint()..color = const Color(0xFFD7F0DA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .58, 76, size.width * .35, 154),
        const Radius.circular(34),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(22, size.height * .48, size.width * .32, 130),
        const Radius.circular(32),
      ),
      park,
    );

    final water = Paint()
      ..color = const Color(0xFF6CB7FF).withValues(alpha: .75)
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final river = Path()
      ..moveTo(-40, size.height * .72)
      ..cubicTo(
        size.width * .28,
        size.height * .62,
        size.width * .44,
        size.height * .88,
        size.width + 42,
        size.height * .68,
      );
    canvas.drawPath(river, water);

    final minorRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final majorRoad = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final roadShadow = Paint()
      ..color = const Color(0xFFCBD7E4)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var y = 92.0; y < size.height; y += 92) {
      final path = Path()
        ..moveTo(-20, y)
        ..quadraticBezierTo(size.width * .45, y - 40, size.width + 20, y + 22);
      canvas.drawPath(path, minorRoad);
    }
    for (var x = 58.0; x < size.width; x += 88) {
      final path = Path()
        ..moveTo(x, -20)
        ..quadraticBezierTo(x + 38, size.height * .4, x - 24, size.height + 20);
      canvas.drawPath(path, minorRoad);
    }

    final route = Path()
      ..moveTo(size.width * .14, size.height * .68)
      ..cubicTo(
        size.width * .28,
        size.height * .54,
        size.width * .38,
        size.height * .46,
        size.width * .48,
        size.height * .36,
      )
      ..cubicTo(
        size.width * .62,
        size.height * .22,
        size.width * .76,
        size.height * .32,
        size.width * .86,
        size.height * .48,
      );
    canvas.drawPath(route, roadShadow);
    canvas.drawPath(route, majorRoad);
    final activeRoute = Paint()
      ..color = routeColor
      ..strokeWidth = navigating ? 8 : 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(route, activeRoute);

    final stationPaint = Paint()..color = routeColor;
    for (final point in [
      Offset(size.width * .14, size.height * .68),
      Offset(size.width * .36, size.height * .47),
      Offset(size.width * .58, size.height * .28),
      Offset(size.width * .86, size.height * .48),
    ]) {
      canvas.drawCircle(point, 8, Paint()..color = Colors.white);
      canvas.drawCircle(point, 5, stationPaint);
    }

    final labelStyle = TextStyle(
      color: const Color(0xFF8793A4).withValues(alpha: .9),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    for (final label in [
      ('Bukit Bintang', Offset(size.width * .14, size.height * .72)),
      ('Pasar Seni', Offset(size.width * .44, size.height * .41)),
      ('KLCC', Offset(size.width * .72, size.height * .26)),
      ('Ampang', Offset(size.width * .70, size.height * .56)),
    ]) {
      final painter = TextPainter(
        text: TextSpan(text: label.$1, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 120);
      painter.paint(canvas, label.$2);
    }
  }

  @override
  bool shouldRepaint(covariant _NavigationMapPainter oldDelegate) {
    return oldDelegate.routeColor != routeColor ||
        oldDelegate.navigating != navigating;
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: .38)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final river = Paint()
      ..color = const Color(0xFF40A9FF).withValues(alpha: .38)
      ..strokeWidth = 20
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(-20, size.height * .64)
      ..quadraticBezierTo(
        size.width * .42,
        size.height * .38,
        size.width + 20,
        size.height * .52,
      );
    canvas.drawPath(path, river);
    for (var y = 32.0; y < size.height; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 40), road);
    }
    for (var x = 36.0; x < size.width; x += 74) {
      canvas.drawLine(Offset(x, 0), Offset(x - 28, size.height), road);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .13)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final route = Paint()
      ..color = const Color(0xFF00E2A7)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(38, size.height - 44),
      Offset(size.width - 48, 58),
      route,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PolylinePainter extends CustomPainter {
  const _PolylinePainter(this.count);

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) {
      return;
    }
    final paint = Paint()
      ..color = const Color(0xFF0B7CFF)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final points = [
      for (var i = 0; i < count; i++)
        Offset(56.0 + (i % 2) * 156, 52.0 + i * 38),
    ];
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PolylinePainter oldDelegate) =>
      oldDelegate.count != count;
}

class DestinationCandidate {
  const DestinationCandidate({
    required this.name,
    required this.address,
    required this.location,
    required this.placeId,
  });

  final String name;
  final String address;
  final LatLng location;
  final String placeId;
}

class _GoogleMapsApi {
  static Future<List<DestinationCandidate>> findPlaces({
    required String query,
    required String apiKey,
  }) async {
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/textsearch/json',
      {'query': query, 'region': 'my', 'key': apiKey},
    );
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['status'] == 'ZERO_RESULTS') {
      return const [];
    }
    if (response.statusCode != 200 || body['status'] != 'OK') {
      throw body['error_message'] ??
          body['status'] ??
          'Unknown Places API error';
    }
    final results = body['results'] as List<dynamic>;
    final candidates = [
      for (final result in results.take(8))
        _candidateFromTextSearch(result as Map<String, dynamic>, query),
    ];
    for (final suggestion in _localSuggestions(query)) {
      final duplicate = candidates.any(
        (candidate) =>
            candidate.name.toLowerCase() == suggestion.name.toLowerCase() ||
            candidate.placeId == suggestion.placeId,
      );
      if (!duplicate) {
        candidates.add(suggestion);
      }
      if (candidates.length >= 6) {
        break;
      }
    }
    return candidates;
  }

  static DestinationCandidate _candidateFromTextSearch(
    Map<String, dynamic> place,
    String fallbackName,
  ) {
    final geometry = place['geometry'] as Map<String, dynamic>? ?? const {};
    final location = geometry['location'] as Map<String, dynamic>? ?? const {};
    return DestinationCandidate(
      name: (place['name'] as String?) ?? fallbackName,
      address: (place['formatted_address'] as String?) ?? 'Address unavailable',
      placeId: (place['place_id'] as String?) ?? '',
      location: LatLng(
        (location['lat'] as num?)?.toDouble() ?? 3.1478,
        (location['lng'] as num?)?.toDouble() ?? 101.6953,
      ),
    );
  }

  static List<DestinationCandidate> _localSuggestions(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }
    final suggestions = [
      const DestinationCandidate(
        name: 'Suria KLCC',
        address: 'Kuala Lumpur City Centre, 50088 Kuala Lumpur, Malaysia',
        location: LatLng(3.1579, 101.7123),
        placeId: 'local-suria-klcc',
      ),
      const DestinationCandidate(
        name: 'KLCC LRT Station',
        address: 'Kelana Jaya Line, Kuala Lumpur City Centre, Malaysia',
        location: LatLng(3.1590, 101.7132),
        placeId: 'local-klcc-lrt',
      ),
      const DestinationCandidate(
        name: 'Petronas Twin Towers',
        address: 'Kuala Lumpur City Centre, Kuala Lumpur, Malaysia',
        location: LatLng(3.1578, 101.7117),
        placeId: 'local-petronas-twin-towers',
      ),
      const DestinationCandidate(
        name: 'Aquaria KLCC',
        address: 'Kuala Lumpur Convention Centre, Kuala Lumpur, Malaysia',
        location: LatLng(3.1539, 101.7131),
        placeId: 'local-aquaria-klcc',
      ),
      const DestinationCandidate(
        name: 'KLCC Park',
        address: 'Kuala Lumpur City Centre, Kuala Lumpur, Malaysia',
        location: LatLng(3.1559, 101.7155),
        placeId: 'local-klcc-park',
      ),
    ];
    return [
      for (final suggestion in suggestions)
        if (suggestion.name.toLowerCase().contains(normalized) ||
            suggestion.address.toLowerCase().contains(normalized) ||
            normalized.contains('klcc'))
          suggestion,
    ];
  }

  static Future<List<TransitOption>> fetchTransitDirections({
    required LatLng origin,
    required DestinationCandidate destination,
    required String apiKey,
  }) async {
    final uri = Uri.https(
      'routes.googleapis.com',
      '/directions/v2:computeRoutes',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline,routes.legs.steps.travelMode,routes.legs.steps.navigationInstruction.instructions,routes.legs.steps.transitDetails',
      },
      body: jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.location.latitude,
              'longitude': destination.location.longitude,
            },
          },
        },
        'travelMode': 'TRANSIT',
        'computeAlternativeRoutes': true,
        'polylineQuality': 'HIGH_QUALITY',
        'polylineEncoding': 'ENCODED_POLYLINE',
        'languageCode': 'en',
        'regionCode': 'MY',
        'units': 'METRIC',
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final error = body['error'] as Map<String, dynamic>?;
      throw error?['message'] ?? 'Unknown Routes API error';
    }
    final routes = body['routes'] as List<dynamic>? ?? const [];
    return [
      for (var i = 0; i < routes.length; i++)
        _routeFromJson(routes[i] as Map<String, dynamic>, i),
    ];
  }

  static TransitOption _routeFromJson(Map<String, dynamic> route, int index) {
    final leg = (route['legs'] as List<dynamic>).first as Map<String, dynamic>;
    final steps = (leg['steps'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final chain = steps
        .map((step) {
          final mode = (step['travelMode'] as String? ?? '').toLowerCase();
          if (step['transitDetails'] case final Map<String, dynamic> details) {
            final line =
                details['transitLine'] as Map<String, dynamic>? ?? const {};
            return (line['nameShort'] as String?) ??
                (line['name'] as String?) ??
                'Transit';
          }
          return mode == 'walking' ? 'Walk' : mode;
        })
        .where((part) => part.isNotEmpty)
        .toList();
    final overviewPolyline = route['polyline'] as Map<String, dynamic>?;
    final points = _decodePolyline(
      (overviewPolyline?['encodedPolyline'] as String?) ?? '',
    );
    final firstInstruction = steps.isEmpty
        ? 'Head toward destination'
        : ((steps.first['navigationInstruction']
                      as Map<String, dynamic>?)?['instructions']
                  as String?) ??
              'Start route';
    final firstStopLabel = chain.isEmpty ? 'First stop' : chain.first;
    final colors = const [
      Color(0xFF22B8F2),
      Color(0xFF00C48C),
      Color(0xFFFFB000),
    ];
    final labels = const ['Recommended', 'Alternative', 'Low transfer'];
    return TransitOption(
      label: index < labels.length ? labels[index] : 'Route ${index + 1}',
      chain: chain.isEmpty ? 'Transit route' : chain.take(5).join(' -> '),
      time: _formatDuration(route['duration'] as String?),
      distance: _formatMeters(route['distanceMeters'] as int?),
      fare:
          ((route['fare'] as Map<String, dynamic>?)?['text'] as String?) ??
          'Fare varies',
      transfers: '${max(0, chain.length - 1)} steps',
      crowd: .45 + min(index, 2) * .15,
      color: colors[index % colors.length],
      legs: [
        RouteLeg(
          fromName: 'Current location',
          toName: firstStopLabel,
          mode: chain.isEmpty ? 'Transit' : chain.first,
          time: 'First leg',
          distance: 'Calculating',
          icon: Icons.directions_transit_rounded,
          points: points,
        ),
      ],
      firstLegPointCount: points.isEmpty
          ? 2
          : max(2, (points.length * .28).round()),
      firstStopLabel: firstStopLabel,
      nextInstruction: firstInstruction,
    );
  }

  static String _formatDuration(String? duration) {
    if (duration == null || !duration.endsWith('s')) {
      return '--';
    }
    final seconds = int.tryParse(duration.substring(0, duration.length - 1));
    if (seconds == null) {
      return '--';
    }
    final minutes = (seconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainder = minutes % 60;
    return remainder == 0 ? '$hours hr' : '$hours hr $remainder min';
  }

  static String _formatMeters(int? meters) {
    if (meters == null) {
      return '--';
    }
    if (meters < 1000) {
      return '$meters m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static List<LatLng> _decodePolyline(String encoded) {
    if (encoded.isEmpty) {
      return const [];
    }
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }
}

class TransitOption {
  const TransitOption({
    required this.label,
    required this.chain,
    required this.time,
    required this.distance,
    required this.fare,
    required this.transfers,
    required this.crowd,
    required this.color,
    this.legs = const [],
    this.firstLegPointCount = 2,
    this.firstStopLabel = 'First stop',
    this.nextInstruction = 'Start route',
  });

  final String label;
  final String chain;
  final String time;
  final String distance;
  final String fare;
  final String transfers;
  final double crowd;
  final Color color;
  final List<RouteLeg> legs;
  final int firstLegPointCount;
  final String firstStopLabel;
  final String nextInstruction;

  List<LatLng> get points {
    final all = <LatLng>[];
    for (final leg in legs) {
      if (all.isNotEmpty &&
          leg.points.isNotEmpty &&
          all.last == leg.points.first) {
        all.addAll(leg.points.skip(1));
      } else {
        all.addAll(leg.points);
      }
    }
    return all;
  }
}

class RouteLeg {
  const RouteLeg({
    required this.fromName,
    required this.toName,
    required this.mode,
    required this.time,
    required this.distance,
    required this.icon,
    required this.points,
  });

  final String fromName;
  final String toName;
  final String mode;
  final String time;
  final String distance;
  final IconData icon;
  final List<LatLng> points;
}

class _TransitStop {
  const _TransitStop(this.name, this.location);

  final String name;
  final LatLng location;
}

class Driver {
  const Driver(
    this.name,
    this.vehicle,
    this.rating,
    this.color, [
    this.startLocation = const LatLng(3.1478, 101.6953),
  ]);

  final String name;
  final String vehicle;
  final String rating;
  final Color color;
  final LatLng startLocation;
}

class Attraction {
  const Attraction(this.name, this.hours, this.rating, this.cost, this.color);

  final String name;
  final String hours;
  final double rating;
  final int cost;
  final Color color;

  bool get isOpen {
    final hour = DateTime.now().hour;
    return hour >= 9 && hour < 21;
  }
}
