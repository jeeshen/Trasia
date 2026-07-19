import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TrasiaApp());
}

enum UserRole { user, admin }

enum RideStage { idle, matching, tracking, onboard, completed, cancelled }

enum PriceTier { budget, midRange, luxury }

enum BlindBoxTravelMode { drive, transit }

enum FeatureCTripStatus { notStarted, traveling, arrived, completed }

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
  static const developmentApiKey =
      'AIzaSyDEDpjqw4CrmsiJSOGWtjeH4LnJSl715jw';
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
  int _transitRequest = 0;
  String? _ongoingDestination;
  GoogleMapController? _mapController;
  SharedMapView _mapView = SharedMapView.initial;
  LatLng? _sharedCurrentLocation;
  double? _sharedCurrentAccuracyMeters;
  bool _centeringOnLocation = false;

  void _openTransitFor(String destination) {
    setState(() {
      _transitDestination = destination;
      _transitRequest++;
      _ongoingDestination = destination;
      _tab = 0;
    });
  }

  void _cancelDestination(String destination) {
    setState(() {
      if (_ongoingDestination == destination) {
        _ongoingDestination = null;
      }
    });
  }

  void _deductFare(double fare) {
    setState(() => _wallet = max(0, _wallet - fare));
  }

  void _topUp(double amount) {
    setState(() => _wallet += amount);
  }

  void _updateMapView(SharedMapView view) {
    final incomingLocation = view.currentLocation;
    if (incomingLocation != null && view.currentAccuracyMeters != null) {
      _sharedCurrentLocation = incomingLocation;
      _sharedCurrentAccuracyMeters = view.currentAccuracyMeters;
    }
    if (_mapView.signature == view.signature) {
      return;
    }
    final oldPrefix = _mapView.signature.split('|').first;
    final newPrefix = view.signature.split('|').first;
    setState(() => _mapView = view);
    final target = view.initialTarget;
    final zoom = view.initialZoom;
    if (_mapController != null &&
        target != null &&
        zoom != null &&
        oldPrefix != newPrefix) {
      unawaited(
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom)),
      );
    }
  }

  Future<void> _centerSharedMapOnCurrentLocation() async {
    final controller = _mapController;
    if (controller == null || _centeringOnLocation) {
      return;
    }
    setState(() => _centeringOnLocation = true);
    try {
      final location = await _readDeviceLocation();
      if (!mounted || location == null) {
        return;
      }
      setState(() {
        _sharedCurrentLocation = location;
        _sharedCurrentAccuracyMeters = 0;
      });
      await controller.animateCamera(CameraUpdate.newLatLngZoom(location, 17));
    } finally {
      if (mounted) {
        setState(() => _centeringOnLocation = false);
      }
    }
  }

  Future<LatLng?> _readDeviceLocation() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Turn on location services first.')),
      );
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Location permission is needed.')),
      );
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Unable to read current location.')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TransitRouterScreen(
        active: _tab == 0,
        mapController: _mapController,
        onMapViewChanged: _updateMapView,
        destination: _transitDestination,
        request: _transitRequest,
        ongoingDestination: _ongoingDestination,
        onNavigationCancelled: () => setState(() => _ongoingDestination = null),
      ),
      HubPoolScreen(
        active: _tab == 1,
        mapController: _mapController,
        onMapViewChanged: _updateMapView,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
        wallet: _wallet,
        onFareDeducted: _deductFare,
      ),
      PelancongPlanScreen(
        active: _tab == 2,
        mapController: _mapController,
        onMapViewChanged: _updateMapView,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
        ongoingDestination: _ongoingDestination,
        onGoNow: _openTransitFor,
        onCancelDestination: _cancelDestination,
      ),
      SafeArea(
        child: Column(
          children: [
            _DashboardHeader(
              role: widget.role,
              wallet: _wallet,
              showWallet: true,
            ),
            Expanded(
              child: AccountConsoleScreen(
                role: widget.role,
                wallet: _wallet,
                onTopUp: _topUp,
              ),
            ),
          ],
        ),
      ),
    ];

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_tab != 3)
            _LiveGoogleMapSurface(
              apiKeyReady: _GoogleMapsConfig.isReady,
              currentLocation: _mapView.currentLocation,
              currentAccuracyMeters: _mapView.currentAccuracyMeters,
              candidate: _mapView.candidate,
              selectedRoute: _mapView.selectedRoute,
              navigating: _mapView.navigating,
              vehicleLocation: _mapView.vehicleLocation,
              vehicleColor: _mapView.vehicleColor,
              initialTarget: _mapView.initialTarget,
              initialZoom: _mapView.initialZoom,
              extraMarkers: _mapView.extraMarkers,
              extraPolylines: _mapView.extraPolylines,
              onMapCreated: (controller) {
                setState(() => _mapController = controller);
              },
              onCameraMove: (_) {},
            ),
          IndexedStack(index: _tab, children: pages),
          if (_tab != 3)
            Positioned(
              right: 16,
              bottom: 18,
              child: _MapLocationButton(
                loading: _centeringOnLocation,
                onPressed: _centerSharedMapOnCurrentLocation,
              ),
            ),
        ],
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
  const TransitRouterScreen({
    required this.active,
    required this.mapController,
    required this.onMapViewChanged,
    required this.destination,
    required this.request,
    required this.ongoingDestination,
    required this.onNavigationCancelled,
    super.key,
  });

  final bool active;
  final GoogleMapController? mapController;
  final ValueChanged<SharedMapView> onMapViewChanged;
  final String destination;
  final int request;
  final String? ongoingDestination;
  final VoidCallback onNavigationCancelled;

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
    _mapController = widget.mapController ?? _mapController;
    if (oldWidget.destination != widget.destination ||
        oldWidget.request != widget.request) {
      _toController.text = widget.destination;
      _candidate = null;
      _candidates = const [];
      _routes = const [];
      _selectedRoute = null;
      _navigating = false;
      _departureLocation = null;
      _departureName = null;
      unawaited(_searchDestination(autoCalculate: true));
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  SharedMapView get _currentMapView => SharedMapView(
        signature:
            'transit|${_pointKey(_currentLocation)}|${_currentAccuracyMeters?.round()}|${_candidate?.placeId}|${_selectedRoute?.label}|$_navigating|${_routes.length}',
        currentLocation: _currentLocation,
        currentAccuracyMeters: _currentAccuracyMeters,
        candidate: _candidate,
        selectedRoute: _selectedRoute,
        navigating: _navigating,
        initialTarget: _currentLocation ?? _lastMapCenter,
        initialZoom: _currentLocation == null ? 12 : 15,
      );

  void _publishMapView() {
    if (!widget.active) {
      return;
    }
    final view = _currentMapView;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) {
        widget.onMapViewChanged(view);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _mapController = widget.mapController ?? _mapController;
    _publishMapView();
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
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
              onTextChanged: () => setState(() {}),
              onSearch: _searchDestination,
              onClearDestination: _clearTransitDestination,
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
              ongoing: widget.ongoingDestination == _candidate?.name,
              onStop: _resetNavigation,
            ),
          ),
      ],
    );
  }

  bool get _hasGoogleMapsKey => _GoogleMapsConfig.isReady;

  void _clearTransitDestination() {
    setState(() {
      _toController.clear();
      _candidate = null;
      _candidates = const [];
      _routes = const [];
      _selectedRoute = null;
      _statusMessage = null;
      _navigating = false;
      _departureLocation = null;
      _departureName = null;
    });
  }

  Future<void> _warmCurrentLocation() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_hasGoogleMapsKey || _currentLocation != null) {
      return;
    }
    await _loadCurrentLocation(silent: true);
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

  Future<void> _searchDestination({bool autoCalculate = false}) async {
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
      if (autoCalculate && candidates.isNotEmpty) {
        await _calculateDirections(candidates.first);
      }
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
        apiKey: _GoogleMapsConfig.apiKey,
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
        if (autoCalculate && mounted) {
          await _calculateDirections(candidates.first);
        }
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

    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    final transitRoutes = _multimodalTransitRoutes(destination);
    final roadAlignedTransitRoutes = transitRoutes.isEmpty
        ? transitRoutes
        : await _roadAlignAccessTransitRoutes(transitRoutes);
    if (!_hasGoogleMapsKey) {
      final routes = roadAlignedTransitRoutes.isEmpty
          ? _previewRoutes(destination)
          : roadAlignedTransitRoutes;
      setState(() {
        _routes = routes;
        _selectedRoute = routes.isEmpty ? null : routes.first;
        _statusMessage = _usingFallbackDeparture
            ? 'Device GPS looks unreliable, so planning starts from the Kuala Lumpur map area until a precise current location is available.'
            : 'Preview routes shown. Connect Google Maps API for real travel time and path interpolation.';
        _loading = false;
      });
      return;
    }
    try {
      final routes = roadAlignedTransitRoutes;
      setState(() {
        _routes = routes;
        _selectedRoute = routes.isEmpty ? null : routes.first;
      });
      if (routes.isNotEmpty) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_routingOrigin, 15),
        );
      } else {
        setState(() => _statusMessage = 'No travel options found.');
      }
    } catch (error) {
      if (_isGoogleRoutesUnavailable(error)) {
        final routes = roadAlignedTransitRoutes.isEmpty
            ? _previewRoutes(destination)
            : roadAlignedTransitRoutes;
        setState(() {
          _routes = routes;
          _selectedRoute = routes.isEmpty ? null : routes.first;
          _statusMessage = _usingFallbackDeparture
              ? 'Device GPS looks unreliable, so planning starts from the Kuala Lumpur map area until a precise current location is available.'
              : 'Live road routing is unavailable, so estimated travel options are shown.';
        });
      } else {
        setState(() => _statusMessage = 'Travel options failed: $error');
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
    widget.onNavigationCancelled();
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

  List<TransitOption> _multimodalTransitRoutes(
    DestinationCandidate destination,
  ) {
    final origin = _routingOrigin;
    final target = destination.location;
    final startStop = _nearestTransitStop(origin);
    final endStop = _nearestTransitStop(target);
    if (startStop == null || endStop == null) {
      return const [];
    }
    final variants = [
      _TransitRouteVariant(
        label: 'Fastest Transit',
        color: const Color(0xFF22B8F2),
        crowdBias: .70,
        costFor: (edge) =>
            edge.minutes.toDouble() +
            (edge.mode == _TransitMode.walk ? 5.0 : 0.0),
      ),
      _TransitRouteVariant(
        label: 'Cheapest Route',
        color: const Color(0xFF00C48C),
        crowdBias: .48,
        costFor: (edge) => edge.fare * 20 + edge.minutes * .25,
      ),
      _TransitRouteVariant(
        label: 'Minimum Transfers',
        color: const Color(0xFFFFB000),
        crowdBias: .36,
        costFor: (edge) =>
            edge.minutes.toDouble() +
            (edge.operatorKey == 'walk' ? 2.0 : 0.0) +
            (edge.transferPenalty ? 18.0 : 0.0),
      ),
    ];
    final options = <TransitOption>[];
    final seenChains = <String>{};
    for (final variant in variants) {
      final path = _findTransitPath(startStop.id, endStop.id, variant);
      if (path.isEmpty) {
        continue;
      }
      final option = _transitOptionFromPath(
        variant: variant,
        origin: origin,
        destination: destination,
        startStop: startStop,
        endStop: endStop,
        path: path,
      );
      final chainKey = option.legs.map((leg) => leg.mode).join('|');
      if (seenChains.add('${variant.label}|$chainKey')) {
        options.add(option);
      }
    }
    return options.take(3).toList();
  }

  _TransitStopNode? _nearestTransitStop(LatLng location) {
    _TransitStopNode? nearest;
    var bestMeters = double.infinity;
    for (final stop in _klTransitStops) {
      final meters = _metersBetween(location, stop.location);
      if (meters < bestMeters) {
        bestMeters = meters;
        nearest = stop;
      }
    }
    return nearest;
  }

  List<_TransitEdge> _findTransitPath(
    String startId,
    String endId,
    _TransitRouteVariant variant,
  ) {
    final graph = <String, List<_TransitEdge>>{};
    for (final edge in _klTransitEdges) {
      graph.putIfAbsent(edge.fromId, () => []).add(edge);
      graph.putIfAbsent(edge.toId, () => []).add(edge.reversed);
    }
    final distances = <String, double>{startId: 0};
    final previous = <String, _TransitEdge>{};
    final visited = <String>{};
    while (true) {
      String? current;
      var best = double.infinity;
      for (final entry in distances.entries) {
        if (!visited.contains(entry.key) && entry.value < best) {
          current = entry.key;
          best = entry.value;
        }
      }
      if (current == null || current == endId) {
        break;
      }
      visited.add(current);
      for (final edge in graph[current] ?? const <_TransitEdge>[]) {
        final transferPenalty = previous[current] == null
            ? 0
            : previous[current]!.operatorKey == edge.operatorKey
                ? 0
                : 1;
        final score = best +
            variant.costFor(edge.copyWith(transferPenalty: transferPenalty > 0));
        if (score < (distances[edge.toId] ?? double.infinity)) {
          distances[edge.toId] = score;
          previous[edge.toId] =
              edge.copyWith(transferPenalty: transferPenalty > 0);
        }
      }
    }
    if (!previous.containsKey(endId) && startId != endId) {
      return const [];
    }
    final path = <_TransitEdge>[];
    var cursor = endId;
    while (cursor != startId) {
      final edge = previous[cursor];
      if (edge == null) {
        break;
      }
      path.insert(0, edge);
      cursor = edge.fromId;
    }
    return path;
  }

  TransitOption _transitOptionFromPath({
    required _TransitRouteVariant variant,
    required LatLng origin,
    required DestinationCandidate destination,
    required _TransitStopNode startStop,
    required _TransitStopNode endStop,
    required List<_TransitEdge> path,
  }) {
    final legs = <RouteLeg>[];
    final firstWalkMeters = _metersBetween(origin, startStop.location);
    final lastWalkMeters = _metersBetween(endStop.location, destination.location);
    var totalMinutes = 0;
    var totalMeters = firstWalkMeters + lastWalkMeters;
    var totalFare = 0.0;
    var transfers = 0;
    if (firstWalkMeters > 60) {
      final minutes = max(2, (firstWalkMeters / 75).round());
      totalMinutes += minutes;
      legs.add(
        _leg(
          _routingOriginName,
          startStop.name,
          'Walk',
          _formatLegMinutes(minutes),
          _formatLegDistance(firstWalkMeters),
          Icons.directions_walk_rounded,
          [origin, startStop.location],
        ),
      );
    }
    _TransitEdge? previousEdge;
    for (final edge in path) {
      final from = _stopById(edge.fromId);
      final to = _stopById(edge.toId);
      if (from == null || to == null) {
        continue;
      }
      if (previousEdge != null &&
          previousEdge.operatorKey != edge.operatorKey) {
        transfers++;
        totalMinutes += 3;
      }
      previousEdge = edge;
      totalMinutes += edge.minutes;
      totalMeters += _metersBetween(from.location, to.location);
      totalFare += edge.fare;
      legs.add(
        _leg(
          from.name,
          to.name,
          edge.modeLabel,
          _formatLegMinutes(edge.minutes),
          _formatLegDistance(_metersBetween(from.location, to.location)),
          edge.icon,
          edge.pointsFor(from.location, to.location),
        ),
      );
    }
    if (lastWalkMeters > 60) {
      final minutes = max(2, (lastWalkMeters / 75).round());
      totalMinutes += minutes;
      legs.add(
        _leg(
          endStop.name,
          destination.name,
          'Walk',
          _formatLegMinutes(minutes),
          _formatLegDistance(lastWalkMeters),
          Icons.directions_walk_rounded,
          [endStop.location, destination.location],
        ),
      );
    }
    totalMinutes += 4; // Published schedules still need average wait time.
    final chain = legs.map((leg) => leg.mode).toSet().join(' -> ');
    final fare = totalFare <= 0 ? 'Free' : 'RM ${totalFare.toStringAsFixed(2)}';
    return TransitOption(
      label: variant.label,
      chain: chain,
      time: _formatLegMinutes(totalMinutes),
      distance: _formatLegDistance(totalMeters),
      fare: fare,
      transfers: transfers == 0 ? 'No transfer' : '$transfers transfer',
      crowd: variant.crowdBias,
      color: variant.color,
      legs: legs,
      firstLegPointCount: legs.isEmpty ? 2 : legs.first.points.length,
      firstStopLabel: legs.isEmpty ? destination.name : legs.first.toName,
      nextInstruction:
          'Use ${legs.where((leg) => leg.mode != 'Walk').map((leg) => leg.mode).take(3).join(' + ')}',
    );
  }

  _TransitStopNode? _stopById(String id) {
    for (final stop in _klTransitStops) {
      if (stop.id == id) {
        return stop;
      }
    }
    return null;
  }

  Future<List<TransitOption>> _roadAlignAccessTransitRoutes(
    List<TransitOption> routes,
  ) async {
    final alignedRoutes = <TransitOption>[];
    for (final route in routes) {
      final alignedLegs = <RouteLeg>[];
      for (final leg in route.legs) {
        if (!_needsRoadGeometry(leg) || leg.points.length < 2) {
          alignedLegs.add(leg);
          continue;
        }
        try {
          final roadRoute = await _GoogleMapsApi.fetchDrivingRoute(
            origin: leg.points.first,
            destination: leg.points.last,
            apiKey: _GoogleMapsConfig.apiKey,
          );
          alignedLegs.add(_copyLegWithPoints(leg, roadRoute.points));
        } catch (_) {
          alignedLegs.add(_copyLegWithPoints(leg, const []));
        }
      }
      alignedRoutes.add(
        route.copyWith(
          legs: alignedLegs,
          firstLegPointCount:
              alignedLegs.isEmpty ? 2 : max(2, alignedLegs.first.points.length),
        ),
      );
    }
    return alignedRoutes;
  }

  bool _needsRoadGeometry(RouteLeg leg) {
    final mode = leg.mode.toLowerCase();
    return mode == 'walk' ||
        mode.contains('bus') ||
        mode.contains('feeder') ||
        mode.contains('linkway');
  }

  RouteLeg _copyLegWithPoints(RouteLeg leg, List<LatLng> points) {
    return RouteLeg(
      fromName: leg.fromName,
      toName: leg.toName,
      mode: leg.mode,
      time: leg.time,
      distance: leg.distance,
      icon: leg.icon,
      points: points,
    );
  }

  List<TransitOption> _previewRoutes([DestinationCandidate? destination]) {
    final destinationLocation = destination?.location;
    final target = destinationLocation != null &&
            _isGreaterKlLocation(destinationLocation)
        ? destinationLocation
        : const LatLng(3.1579, 101.7123);
    final origin = _routingOrigin;
    final originName = _routingOriginName;
    final distanceMeters = _metersBetween(origin, target);
    final distanceKm = max(.2, distanceMeters / 1000);
    final driveMinutes = max(4, (distanceMeters / 400).round());
    final transitMinutes = max(12, (distanceKm / 24 * 60 + 10).round());
    final walkMinutes = max(4, (distanceKm / 4.8 * 60).round());
    final transitFare = (1.20 + distanceKm * .55).clamp(1.20, 8.00);
    return [
      TransitOption(
        label: 'Drive',
        chain: 'Car route',
        time: _formatLegMinutes(driveMinutes),
        distance: _formatLegDistance(distanceMeters),
        fare: 'Fare varies',
        transfers: 'Direct',
        crowd: .52,
        color: const Color(0xFF22B8F2),
        legs: [
          _leg(
            originName,
            _candidate?.name ?? 'Destination',
            'Drive',
            _formatLegMinutes(driveMinutes),
            _formatLegDistance(distanceMeters),
            Icons.directions_car_rounded,
            const [],
          ),
        ],
        firstStopLabel: _candidate?.name ?? 'Destination',
        nextInstruction: 'Connect Google driving routes to show the road path',
      ),
      TransitOption(
        label: 'Transit',
        chain: 'Walk -> Rail/Bus -> Walk',
        time: _formatLegMinutes(transitMinutes),
        distance: _formatLegDistance(distanceMeters),
        fare: 'RM ${transitFare.toStringAsFixed(2)}',
        transfers: distanceKm > 7 ? '2 transfers' : '1 transfer',
        crowd: .58,
        color: const Color(0xFF00C48C),
        legs: [
          _leg(
            originName,
            _candidate?.name ?? 'Destination',
            'Transit',
            _formatLegMinutes(transitMinutes),
            _formatLegDistance(distanceMeters),
            Icons.directions_transit_rounded,
            const [],
          ),
        ],
        firstStopLabel: 'Nearest station',
        nextInstruction: 'Use the nearest rail or bus connection',
      ),
      TransitOption(
        label: 'Walk',
        chain: 'Walking route',
        time: _formatLegMinutes(walkMinutes),
        distance: _formatLegDistance(distanceMeters),
        fare: 'Free',
        transfers: 'No transfer',
        crowd: .12,
        color: const Color(0xFFFFB000),
        legs: [
          _leg(
            originName,
            _candidate?.name ?? 'Destination',
            'Walk',
            _formatLegMinutes(walkMinutes),
            _formatLegDistance(distanceMeters),
            Icons.directions_walk_rounded,
            const [],
          ),
        ],
        firstStopLabel: _candidate?.name ?? 'Destination',
        nextInstruction: 'Walk toward ${_candidate?.name ?? 'destination'}',
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

  double _metersBetween(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
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
    required this.active,
    required this.mapController,
    required this.onMapViewChanged,
    required this.currentLocation,
    required this.currentAccuracyMeters,
    required this.wallet,
    required this.onFareDeducted,
    super.key,
  });

  final bool active;
  final GoogleMapController? mapController;
  final ValueChanged<SharedMapView> onMapViewChanged;
  final LatLng? currentLocation;
  final double? currentAccuracyMeters;
  final double wallet;
  final ValueChanged<double> onFareDeducted;

  @override
  State<HubPoolScreen> createState() => _HubPoolScreenState();
}

class _HubPoolScreenState extends State<HubPoolScreen>
    with SingleTickerProviderStateMixin {
  final _destinationController = TextEditingController();
  GoogleMapController? _mapController;
  static const _maxApproachSeconds = 60;
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
  Timer? _destinationRouteRefreshTimer;
  StreamSubscription<Position>? _hubPositionSubscription;
  RideStage _stage = RideStage.idle;
  Driver? _driver;
  DestinationCandidate? _destination;
  List<DestinationCandidate> _destinationCandidates = const [];
  TransitOption? _route;
  List<LatLng> _approachAnimationPoints = const [];
  String? _destinationStatusMessage;
  int _seconds = 0;
  bool _fareDeducted = false;
  bool _searchingDestination = false;
  bool _loadingPickupLocation = false;
  LatLng? _hubCurrentLocation;
  double? _hubCurrentAccuracyMeters;
  static const _origin = LatLng(3.1478, 101.6953);
  static const _originName = 'Current pickup point';
  LatLng get _pickupLocation =>
      _hubCurrentLocation ?? widget.currentLocation ?? _origin;
  LatLng get _rideCurrentLocation =>
      _hubCurrentLocation ?? widget.currentLocation ?? _pickupLocation;

  double? get _pickupAccuracyMeters =>
      _hubCurrentAccuracyMeters ?? widget.currentAccuracyMeters;
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
    if (widget.active) {
      unawaited(_loadPickupLocation(silent: true));
    }
  }

  @override
  void didUpdateWidget(covariant HubPoolScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mapController = widget.mapController ?? _mapController;
    if (widget.active && !oldWidget.active) {
      unawaited(_loadPickupLocation(silent: true));
    }
    if (_pointKey(oldWidget.currentLocation) ==
        _pointKey(widget.currentLocation)) {
      return;
    }
    _refreshRouteForPickupChange();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _destinationRouteRefreshTimer?.cancel();
    _hubPositionSubscription?.cancel();
    _carController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _refreshRouteForPickupChange() {
    final driver = _driver;
    final destination = _destination;
    if (_stage == RideStage.tracking && driver != null) {
      _approachAnimationPoints = const [];
      final route = _pendingApproachRoute(driver);
      setState(() => _route = route);
      unawaited(_replaceWithDrivingApproachRoute(driver));
      return;
    }
    if (_stage == RideStage.onboard && destination != null) {
      final route = _destinationRoute(destination);
      setState(() => _route = route);
      unawaited(_fitRoute(route.points));
      unawaited(_replaceWithDrivingDestinationRoute(destination));
    }
  }

  Future<void> _loadPickupLocation({required bool silent}) async {
    if (_loadingPickupLocation) {
      return;
    }
    _loadingPickupLocation = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
      if (!mounted ||
          !_isGreaterKlLocation(location) ||
          position.accuracy > 120) {
        return;
      }
      setState(() {
        _hubCurrentLocation = location;
        _hubCurrentAccuracyMeters = position.accuracy;
      });
      if ((_stage == RideStage.tracking && _driver != null) ||
          (_stage == RideStage.onboard && _destination != null)) {
        _refreshRouteForPickupChange();
      }
    } catch (_) {
      // Keep the last known pickup when location services cannot refresh.
    } finally {
      _loadingPickupLocation = false;
    }
  }

  void _startRideLocationUpdates() {
    _hubPositionSubscription?.cancel();
    _hubPositionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 8,
      ),
    ).listen(_handleRidePosition, onError: (_) {});
  }

  void _stopRideLocationUpdates() {
    _destinationRouteRefreshTimer?.cancel();
    _destinationRouteRefreshTimer = null;
    _hubPositionSubscription?.cancel();
    _hubPositionSubscription = null;
  }

  void _handleRidePosition(Position position) {
    if (!mounted || _stage != RideStage.onboard) {
      return;
    }
    final location = LatLng(position.latitude, position.longitude);
    if (!_isGreaterKlLocation(location) || position.accuracy > 120) {
      return;
    }
    final previous = _hubCurrentLocation;
    if (previous != null && _distanceMeters(previous, location) < 8) {
      return;
    }
    setState(() {
      _hubCurrentLocation = location;
      _hubCurrentAccuracyMeters = position.accuracy;
    });
    _scheduleDestinationRouteRefresh();
  }

  void _scheduleDestinationRouteRefresh() {
    final destination = _destination;
    if (_stage != RideStage.onboard || destination == null) {
      return;
    }
    _destinationRouteRefreshTimer?.cancel();
    _destinationRouteRefreshTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _stage == RideStage.onboard && _destination != null) {
        unawaited(_replaceWithDrivingDestinationRoute(_destination!));
      }
    });
  }

  bool _isGreaterKlLocation(LatLng location) {
    return location.latitude >= 2.85 &&
        location.latitude <= 3.35 &&
        location.longitude >= 101.45 &&
        location.longitude <= 102.05;
  }

  Future<void> _bookRide() async {
    await _loadPickupLocation(silent: true);
    final destination = _destination;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search and choose a destination first.')),
      );
      return;
    }
    final rideDistanceKm = _rideDistanceKm(destination.location);
    final fare = _fareForDistance(rideDistanceKm);
    if (widget.wallet < fare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Top up credit before booking.')),
      );
      return;
    }
    _timer?.cancel();
    _stopRideLocationUpdates();
    _carController.reset();
    setState(() {
      _stage = RideStage.matching;
      _seconds = 10;
      _driver = null;
      _destination = destination;
      _route = null;
      _destinationStatusMessage = null;
      _fareDeducted = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        unawaited(_confirmDriverMatch());
      } else {
        setState(() => _seconds--);
      }
    });
  }

  Future<void> _confirmDriverMatch() async {
    if (!mounted || _stage != RideStage.matching) {
      return;
    }
    final index = DateTime.now().millisecond % _drivers.length;
    final driverProfile = _drivers[index];
    try {
      final arrival = await _findNearbyDriverArrival(driverProfile);
      if (!mounted || _stage != RideStage.matching) {
        return;
      }
      final arrivalSeconds = _arrivalSecondsFor(arrival.route);
      final drivingRoute = _drivingApproachRoute(arrival.driver, arrival.route);
      _timer?.cancel();
      _carController.duration = Duration(seconds: arrivalSeconds);
      setState(() {
        _stage = RideStage.tracking;
        _driver = arrival.driver;
        _approachAnimationPoints = arrival.route.points;
        _route = drivingRoute;
        _seconds = arrivalSeconds;
        _destinationStatusMessage = null;
      });
      _carController.forward(from: 0);
      unawaited(_fitRoute(drivingRoute.points));
      _startTrackingTimer();
    } catch (_) {
      if (!mounted || _stage != RideStage.matching) {
        return;
      }
      final nearbyDriver = driverProfile.copyWith(
        startLocation: _nearbyDriverCandidates(_pickupLocation).first,
      );
      _timer?.cancel();
      setState(() {
        _stage = RideStage.tracking;
        _driver = nearbyDriver;
        _approachAnimationPoints = const [];
        _route = _pendingApproachRoute(nearbyDriver);
        _seconds = _maxApproachSeconds;
      });
      unawaited(_replaceWithDrivingApproachRoute(nearbyDriver));
      _startTrackingTimer();
    }
  }

  void _startTrackingTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds <= 1) {
        timer.cancel();
        final destination = _destination;
        if (destination == null) {
          setState(() {
            _stage = RideStage.idle;
            _seconds = 0;
            _route = null;
          });
          return;
        }
        final fare = _fareForDistance(_rideDistanceKm(destination.location));
        if (!_fareDeducted) {
          widget.onFareDeducted(fare);
        }
        setState(() {
          _seconds = 0;
          _stage = RideStage.onboard;
          _route = _destinationRoute(destination);
          _approachAnimationPoints = const [];
          _fareDeducted = true;
        });
        _startRideLocationUpdates();
        unawaited(_fitRoute(_route?.points ?? const []));
        unawaited(_replaceWithDrivingDestinationRoute(destination));
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void _cancelRide() {
    _timer?.cancel();
    _carController.stop();
    _stopRideLocationUpdates();
    setState(() {
      _stage = RideStage.cancelled;
      _seconds = 0;
      _route = null;
      _approachAnimationPoints = const [];
    });
  }

  void _resetRide() {
    _timer?.cancel();
    _carController.reset();
    _stopRideLocationUpdates();
    setState(() {
      _stage = RideStage.idle;
      _seconds = 0;
      _driver = null;
      _destination = null;
      _route = null;
      _approachAnimationPoints = const [];
      _fareDeducted = false;
    });
  }

  List<DestinationCandidate> get _visibleDestinations {
    final query = _destinationController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _destinationCandidates;
    }
    final matches = _destinationCandidates
        .where(
          (destination) =>
              destination.name.toLowerCase().contains(query) ||
              destination.address.toLowerCase().contains(query),
        )
        .toList();
    return matches.isEmpty ? _destinationCandidates : matches;
  }

  LatLng? get _vehicleLocation {
    final driver = _driver;
    if (driver == null) {
      return null;
    }
    if (_stage == RideStage.tracking) {
      final routePoints = _route?.points ?? const <LatLng>[];
      final animationPoints =
          routePoints.isEmpty ? _approachAnimationPoints : routePoints;
      return animationPoints.isEmpty
          ? driver.startLocation
          : _pointAlongPath(animationPoints, _carController.value);
    }
    if (_stage == RideStage.onboard) {
      return _rideCurrentLocation;
    }
    return driver.startLocation;
  }

  double get _selectedDistanceKm =>
      _destination == null ? 0 : _rideDistanceKm(_destination!.location);

  double get _selectedFare => _fareForDistance(_selectedDistanceKm);

  SharedMapView get _currentMapView => SharedMapView(
        signature:
            'hub|${_pointKey(_pickupLocation)}|${_destination?.placeId}|${_route?.label}|${_route?.time}|${_route?.distance}|${_route?.points.length}|$_stage|${_driver?.name}|${_pointKey(_vehicleLocation)}|${_destinationCandidates.length}',
        currentLocation: _pickupLocation,
        currentAccuracyMeters: _pickupAccuracyMeters,
        candidate: _destination,
        selectedRoute: _route,
        navigating:
            _stage == RideStage.tracking || _stage == RideStage.onboard,
        vehicleLocation: _vehicleLocation,
        vehicleColor: _driver?.color,
        initialTarget: _destination?.location ?? _pickupLocation,
        initialZoom: _destination == null ? 13 : 14.5,
      );

  void _publishMapView() {
    if (!widget.active) {
      return;
    }
    final view = _currentMapView;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) {
        widget.onMapViewChanged(view);
      }
    });
  }

  Future<_DriverArrival> _findNearbyDriverArrival(Driver driverProfile) async {
    final pickup = _pickupLocation;
    final candidates = _nearbyDriverCandidates(pickup);
    _DriverArrival? bestArrival;
    double? bestFullRouteSeconds;
    for (final candidate in candidates) {
      final driver = driverProfile.copyWith(startLocation: candidate);
      try {
        final route = await _GoogleMapsApi.fetchDrivingRoute(
          origin: candidate,
          destination: pickup,
          apiKey: _GoogleMapsConfig.apiKey,
        );
        if (route.points.length < 2 || route.distanceMeters < 25) {
          continue;
        }
        final arrival = _DriverArrival(driver: driver, route: route);
        if (route.durationSeconds <= _maxApproachSeconds) {
          return arrival;
        }
        if (bestArrival == null ||
            route.durationSeconds < (bestFullRouteSeconds ?? double.infinity)) {
          bestArrival = _arrivalFromFinalRoadSegment(driverProfile, route);
          bestFullRouteSeconds = route.durationSeconds;
        }
      } catch (_) {
        // Try the next nearby road point.
      }
    }
    if (bestArrival != null) {
      return bestArrival;
    }
    throw 'No nearby driver road route found';
  }

  _DriverArrival _arrivalFromFinalRoadSegment(
    Driver driverProfile,
    _DrivingRoute route,
  ) {
    final points = _lastRoadSegment(route.points, 420);
    final distanceMeters = _pathDistanceMeters(points);
    final averageMetersPerSecond =
        route.durationSeconds <= 0 || route.distanceMeters <= 0
            ? 9.0
            : max(7.0, route.distanceMeters / route.durationSeconds);
    final durationSeconds =
        (distanceMeters / averageMetersPerSecond)
            .clamp(20, _maxApproachSeconds)
            .toDouble();
    final approachRoute = _DrivingRoute(
      points: points,
      time: _GoogleMapsApi._formatSeconds(durationSeconds),
      distance: _GoogleMapsApi._formatMeters(distanceMeters.round()),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
    return _DriverArrival(
      driver: driverProfile.copyWith(startLocation: points.first),
      route: approachRoute,
    );
  }

  List<LatLng> _lastRoadSegment(List<LatLng> points, double maxMeters) {
    if (points.length <= 2) {
      return points;
    }
    final segment = <LatLng>[points.last];
    var remainingMeters = maxMeters;
    for (var i = points.length - 2; i >= 0; i--) {
      final current = points[i];
      final next = segment.first;
      final length = _distanceMeters(current, next);
      if (length >= remainingMeters) {
        final ratio = remainingMeters / length;
        segment.insert(
          0,
          LatLng(
            next.latitude + (current.latitude - next.latitude) * ratio,
            next.longitude + (current.longitude - next.longitude) * ratio,
          ),
        );
        break;
      }
      segment.insert(0, current);
      remainingMeters -= length;
    }
    return segment;
  }

  double _pathDistanceMeters(List<LatLng> points) {
    var meters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      meters += _distanceMeters(points[i], points[i + 1]);
    }
    return meters;
  }

  List<LatLng> _nearbyDriverCandidates(LatLng pickup) {
    final random = Random(DateTime.now().millisecondsSinceEpoch);
    final angles = <double>[
      -pi / 2,
      -pi / 3,
      -pi / 4,
      -pi / 6,
      0,
      pi / 6,
      pi / 4,
      pi / 3,
      pi / 2,
      pi * 2 / 3,
      pi * 3 / 4,
      pi * 5 / 6,
      pi,
    ]..shuffle(random);
    final distancesMeters = <double>[70, 100, 140, 190, 250, 320, 420];
    final candidates = <LatLng>[];
    for (final distanceMeters in distancesMeters) {
      for (final angle in angles.take(4)) {
        candidates.add(
          _offsetLocation(
            pickup,
            distanceMeters,
            angle + random.nextDouble() * .2 - .1,
          ),
        );
      }
    }
    return candidates;
  }

  LatLng _offsetLocation(LatLng origin, double meters, double bearingRadians) {
    final latMeters = 111320.0;
    final lngMeters = latMeters * cos(origin.latitude * pi / 180);
    return LatLng(
      origin.latitude + cos(bearingRadians) * meters / latMeters,
      origin.longitude + sin(bearingRadians) * meters / lngMeters,
    );
  }

  int _arrivalSecondsFor(_DrivingRoute route) {
    final seconds = route.durationSeconds.round();
    return seconds.clamp(20, _maxApproachSeconds).toInt();
  }

  TransitOption _pendingApproachRoute(Driver driver) {
    return _approachRoute(
      driver,
      points: const [],
      time: 'Calculating',
      distance: '--',
      legTime: 'Calculating',
      legDistance: '--',
    );
  }

  TransitOption _drivingApproachRoute(Driver driver, _DrivingRoute route) {
    return _approachRoute(
      driver,
      points: route.points,
      time: route.time,
      distance: route.distance,
      legTime: route.time,
      legDistance: route.distance,
    );
  }

  TransitOption _approachRoute(
    Driver driver, {
    required List<LatLng> points,
    required String time,
    required String distance,
    required String legTime,
    required String legDistance,
  }) {
    return TransitOption(
      label: 'Driver approach',
      chain: '${driver.vehicle} -> Pickup',
      time: time,
      distance: distance,
      fare: 'No charge yet',
      transfers: 'Pickup',
      crowd: .2,
      color: driver.color,
      legs: [
        RouteLeg(
          fromName: '${driver.name} nearby',
          toName: _originName,
          mode: driver.vehicle,
          time: legTime,
          distance: legDistance,
          icon: Icons.local_taxi_rounded,
          points: points,
        ),
      ],
      firstStopLabel: _originName,
      nextInstruction: '${driver.name} is driving to your pickup point',
    );
  }

  Future<void> _replaceWithDrivingApproachRoute(Driver driver) async {
    try {
      final pickup = _pickupLocation;
      final route = await _GoogleMapsApi.fetchDrivingRoute(
        origin: driver.startLocation,
        destination: pickup,
        apiKey: _GoogleMapsConfig.apiKey,
      );
      if (!mounted || _stage != RideStage.tracking || _driver != driver) {
        return;
      }
      final drivingRoute = _drivingApproachRoute(driver, route);
      final arrivalSeconds = _arrivalSecondsFor(route);
      _carController.duration = Duration(seconds: arrivalSeconds);
      setState(() {
        _approachAnimationPoints = route.points;
        _route = drivingRoute;
        _seconds = arrivalSeconds;
        _destinationStatusMessage = null;
      });
      _carController.forward(from: 0);
      await _fitRoute(drivingRoute.points);
    } catch (error) {
      if (mounted && _stage == RideStage.tracking && _driver == driver) {
        setState(() {
          _approachAnimationPoints = const [];
          _route = _pendingApproachRoute(driver);
          _destinationStatusMessage =
              'Road route is temporarily unavailable. Retrying...';
        });
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted && _stage == RideStage.tracking && _driver == driver) {
            unawaited(_replaceWithDrivingApproachRoute(driver));
          }
        });
      }
    }
  }

  TransitOption _destinationRoute(DestinationCandidate destination) {
    final origin = _stage == RideStage.onboard
        ? _rideCurrentLocation
        : _pickupLocation;
    final distanceKm = _rideDistanceKm(destination.location, to: origin);
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
          points: const [],
        ),
      ],
      firstStopLabel: destination.name,
      nextInstruction: 'Getting road route to ${destination.name}',
    );
  }

  Future<void> _replaceWithDrivingDestinationRoute(
    DestinationCandidate destination,
  ) async {
    try {
      final origin = _rideCurrentLocation;
      final route = await _GoogleMapsApi.fetchDrivingRoute(
        origin: origin,
        destination: destination.location,
        apiKey: _GoogleMapsConfig.apiKey,
      );
      if (!mounted ||
          _stage != RideStage.onboard ||
          _destination != destination) {
        return;
      }
      final distanceKm = max(.2, route.distanceMeters / 1000);
      final drivingRoute = _destinationRoute(destination).copyWith(
        time: route.time,
        distance: route.distance,
        fare: '${_fareForDistance(distanceKm).toStringAsFixed(2)} credit',
        legs: [
          RouteLeg(
            fromName: _originName,
            toName: destination.name,
            mode: _driver?.vehicle ?? 'Hub-Pool',
            time: route.time,
            distance: route.distance,
            icon: Icons.directions_car_rounded,
            points: route.points,
          ),
        ],
      );
      setState(() => _route = drivingRoute);
      _publishMapView();
      await _fitRoute(drivingRoute.points);
    } catch (_) {
      // Do not draw guessed ride lines; only road polylines are shown.
    }
  }

  LatLng? _pointAlongPath(List<LatLng> points, double progress) {
    if (points.isEmpty) {
      return null;
    }
    if (points.length == 1) {
      return points.first;
    }
    final clamped = progress.clamp(0, 1).toDouble();
    final segmentLengths = <double>[];
    var totalMeters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = _distanceMeters(points[i], points[i + 1]);
      segmentLengths.add(length);
      totalMeters += length;
    }
    if (totalMeters == 0) {
      return points.last;
    }
    var remainingMeters = totalMeters * clamped;
    for (var i = 0; i < segmentLengths.length; i++) {
      final segmentLength = segmentLengths[i];
      if (remainingMeters > segmentLength && i < segmentLengths.length - 1) {
        remainingMeters -= segmentLength;
        continue;
      }
      final segmentProgress = segmentLength == 0
          ? 0.0
          : (remainingMeters / segmentLength).clamp(0, 1).toDouble();
      final from = points[i];
      final to = points[i + 1];
      return LatLng(
        from.latitude + (to.latitude - from.latitude) * segmentProgress,
        from.longitude + (to.longitude - from.longitude) * segmentProgress,
      );
    }
    return points.last;
  }

  double _distanceMeters(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  double _rideDistanceKm(LatLng location, {LatLng? to}) {
    final from = to ?? _pickupLocation;
    final meters = _distanceMeters(from, location);
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

  void _handleDestinationTextChanged() {
    setState(() {
      _destination = null;
      _destinationStatusMessage = null;
      _destinationCandidates = const [];
    });
  }

  Future<void> _searchDestination() async {
    final query = _destinationController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _destination = null;
        _destinationCandidates = const [];
        _destinationStatusMessage = null;
      });
      return;
    }

    setState(() {
      _searchingDestination = true;
      _destination = null;
      _destinationStatusMessage = null;
    });

    try {
      final candidates = await _GoogleMapsApi.findPlaces(
        query: query,
        apiKey: _GoogleMapsConfig.apiKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _destinationCandidates = candidates;
        _destination = candidates.isEmpty ? null : candidates.first;
        _destinationStatusMessage = candidates.isEmpty
            ? 'No places found. Try a more specific address or landmark.'
            : null;
      });
      final destination = candidates.isEmpty ? null : candidates.first;
      if (destination != null) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(destination.location, 14.5),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _destinationCandidates = const [];
        _destination = null;
        _destinationStatusMessage = 'Place search failed. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _searchingDestination = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _mapController = widget.mapController ?? _mapController;
    _publishMapView();
    final topInset = MediaQuery.paddingOf(context).top;
    final destination = _destination;
    return Stack(
      children: [
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
            statusMessage: _destinationStatusMessage,
            searchingDestination: _searchingDestination,
            onTextChanged: _handleDestinationTextChanged,
            onClearInput: _clearDestinationInput,
            onSearch: _searchDestination,
            onSelectDestination: (candidate) {
              setState(() {
                _destinationController.text = candidate.name;
                _destination = candidate;
                _destinationStatusMessage = null;
              });
              unawaited(
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(candidate.location, 14.5),
                ),
              );
            },
            onBook: destination == null ? null : _bookRide,
            onCancel: _stage == RideStage.matching ||
                    _stage == RideStage.tracking ||
                    _stage == RideStage.onboard
                ? _cancelRide
                : null,
          ),
        ),
      ],
    );
  }

  void _clearDestinationInput() {
    _timer?.cancel();
    _carController.reset();
    _stopRideLocationUpdates();
    setState(() {
      _destinationController.clear();
      _stage = RideStage.idle;
      _seconds = 0;
      _driver = null;
      _destination = null;
      _destinationCandidates = const [];
      _route = null;
      _approachAnimationPoints = const [];
      _destinationStatusMessage = null;
      _fareDeducted = false;
    });
  }
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
    required this.statusMessage,
    required this.searchingDestination,
    required this.onTextChanged,
    required this.onClearInput,
    required this.onSearch,
    required this.onSelectDestination,
    required this.onBook,
    required this.onCancel,
  });

  final TextEditingController controller;
  final RideStage stage;
  final int seconds;
  final double wallet;
  final double fare;
  final double distanceKm;
  final Driver? driver;
  final List<DestinationCandidate> destinations;
  final DestinationCandidate? selectedDestination;
  final String? statusMessage;
  final bool searchingDestination;
  final VoidCallback onTextChanged;
  final VoidCallback onClearInput;
  final VoidCallback onSearch;
  final ValueChanged<DestinationCandidate> onSelectDestination;
  final VoidCallback? onBook;
  final VoidCallback? onCancel;

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
      RideStage.idle => selectedDestination == null
          ? 'Search any destination'
          : '${distanceKm.toStringAsFixed(1)} km / ${fare.toStringAsFixed(2)} credit',
      RideStage.matching => 'Confirmed. Matching in $seconds sec',
      RideStage.tracking => 'Arrives in $seconds sec',
      RideStage.onboard =>
        '${driver?.vehicle ?? 'Vehicle'} to ${selectedDestination?.name ?? 'destination'}',
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('feature-b-destination'),
                    controller: controller,
                    onChanged: (_) => onTextChanged(),
                    onSubmitted: (_) => onSearch(),
                    style: const TextStyle(color: Color(0xFF172033)),
                    decoration: InputDecoration(
                      hintText: 'Search destination',
                      hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: controller.text.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear destination',
                              onPressed: onClearInput,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF0F4FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Search destinations',
                  onPressed: searchingDestination ? null : onSearch,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0B7CFF),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFB9D7FF),
                    disabledForegroundColor: Colors.white,
                  ),
                  icon: searchingDestination
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.near_me_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (statusMessage != null) ...[
              _SheetNotice(message: statusMessage!),
              const SizedBox(height: 10),
            ],
            for (final destination in destinations.take(6)) ...[
              _HubDestinationTile(
                destination: destination,
                selected: destination.placeId == selectedDestination?.placeId,
                onTap: () => onSelectDestination(destination),
              ),
              const SizedBox(height: 8),
            ],
            if (destinations.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('book-ride'),
                  onPressed: onBook,
                  icon: const Icon(Icons.local_taxi_rounded),
                  label: const Text('Book Ride'),
                ),
              ),
            ],
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
            if (statusMessage != null) ...[
              const SizedBox(height: 10),
              _SheetNotice(message: statusMessage!),
            ],
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
  const PelancongPlanScreen({
    required this.active,
    required this.mapController,
    required this.onMapViewChanged,
    required this.currentLocation,
    required this.currentAccuracyMeters,
    required this.ongoingDestination,
    required this.onGoNow,
    required this.onCancelDestination,
    super.key,
  });

  final bool active;
  final GoogleMapController? mapController;
  final ValueChanged<SharedMapView> onMapViewChanged;
  final LatLng? currentLocation;
  final double? currentAccuracyMeters;
  final String? ongoingDestination;
  final ValueChanged<String> onGoNow;
  final ValueChanged<String> onCancelDestination;

  @override
  State<PelancongPlanScreen> createState() => _PelancongPlanScreenState();
}

class _PelancongPlanScreenState extends State<PelancongPlanScreen> {
  double _attractionCount = 3;
  double _distanceKm = 10;
  double _priceIndex = 1;
  BlindBoxTravelMode _travelMode = BlindBoxTravelMode.drive;
  List<ItineraryStop> _itinerary = const [];
  bool _itineraryListVisible = false;
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _featureCMarkerIcons = {};
  List<LatLng> _featureCRoutePoints = const [];
  int _markerIconRevision = 0;
  int _routeRevision = 0;
  FeatureCTripStatus _tripStatus = FeatureCTripStatus.notStarted;
  int _activeStopIndex = 0;
  int _tripTotalStops = 0;
  int _completedStopCount = 0;
  late final List<Attraction> _blindBoxLocations = _buildBlindBoxLocations();
  PriceTier get _priceTier => PriceTier.values[_priceIndex.round()];

  @override
  void didUpdateWidget(covariant PelancongPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mapController = widget.mapController ?? _mapController;
    if (widget.active &&
        (!oldWidget.active || oldWidget.mapController != widget.mapController) &&
        _itinerary.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) {
          unawaited(_fitItineraryMap());
        }
      });
    }
    if (_itinerary.isNotEmpty &&
        _pointKey(oldWidget.currentLocation) != _pointKey(widget.currentLocation)) {
      unawaited(_loadFeatureCDrivingRoute());
    }
  }

  void _generate() {
    setState(() {
      _itinerary = _buildItinerary(
        stopCount: _attractionCount.round(),
        totalDistanceKm: _distanceKm,
        priceTier: _priceTier,
        travelMode: _travelMode,
      );
      _itineraryListVisible = false;
      _featureCRoutePoints = const [];
      _tripStatus = FeatureCTripStatus.notStarted;
      _activeStopIndex = 0;
      _tripTotalStops = _itinerary.length;
      _completedStopCount = 0;
      _routeRevision++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_fitItineraryMap());
    });
    unawaited(_loadFeatureCMarkerIcons());
    unawaited(_loadFeatureCDrivingRoute());
  }

  void _removeStop(ItineraryStop stop) {
    widget.onCancelDestination(stop.attraction.name);
    final removedIndex = _itinerary.indexOf(stop);
    setState(() {
      _itinerary = [
        for (final item in _itinerary)
          if (item != stop) item,
      ];
      _tripTotalStops = max(0, _tripTotalStops - 1);
      if (_itinerary.isEmpty) {
        _itineraryListVisible = false;
        _tripStatus = FeatureCTripStatus.notStarted;
        _activeStopIndex = 0;
        _tripTotalStops = 0;
        _completedStopCount = 0;
      } else if (removedIndex >= 0 && removedIndex < _activeStopIndex) {
        _activeStopIndex--;
      } else if (_activeStopIndex >= _itinerary.length) {
        _activeStopIndex = _itinerary.length - 1;
      }
    });
  }

  Future<void> _focusItineraryStop(ItineraryStop stop) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(stop.attraction.location, 16),
    );
  }

  ItineraryStop? get _activeTripStop {
    if (_itinerary.isEmpty ||
        _activeStopIndex < 0 ||
        _activeStopIndex >= _itinerary.length) {
      return null;
    }
    return _itinerary[_activeStopIndex];
  }

  void _startFeatureCTrip() {
    if (_itinerary.isEmpty) {
      return;
    }
    setState(() {
      _activeStopIndex = 0;
      _tripStatus = FeatureCTripStatus.traveling;
      _itineraryListVisible = true;
    });
    unawaited(_focusActiveTripStop());
  }

  void _markActiveStopArrived() {
    final stop = _activeTripStop;
    if (stop == null) {
      return;
    }
    widget.onCancelDestination(stop.attraction.name);
    setState(() {
      _itinerary = [
        for (final item in _itinerary)
          if (item != stop) item,
      ];
      _completedStopCount =
          min(_tripTotalStops, _completedStopCount + 1);
      if (_itinerary.isEmpty) {
        _tripStatus = FeatureCTripStatus.completed;
        _activeStopIndex = 0;
        _featureCRoutePoints = const [];
        _routeRevision++;
        return;
      }
      if (_activeStopIndex >= _itinerary.length) {
        _activeStopIndex = _itinerary.length - 1;
      }
      _tripStatus = FeatureCTripStatus.traveling;
      _routeRevision++;
    });
    unawaited(_focusActiveTripStop());
  }

  void _goToNextFeatureCStop() {
    if (_itinerary.isEmpty) {
      return;
    }
    if (_activeStopIndex >= _itinerary.length - 1) {
      setState(() => _tripStatus = FeatureCTripStatus.completed);
      return;
    }
    setState(() {
      _activeStopIndex++;
      _tripStatus = FeatureCTripStatus.traveling;
    });
    unawaited(_focusActiveTripStop());
  }

  void _finishFeatureCTrip() {
    setState(() => _tripStatus = FeatureCTripStatus.completed);
  }

  void _resetFeatureCPlanner() {
    setState(() {
      _itinerary = const [];
      _itineraryListVisible = false;
      _featureCRoutePoints = const [];
      _tripStatus = FeatureCTripStatus.notStarted;
      _activeStopIndex = 0;
      _tripTotalStops = 0;
      _completedStopCount = 0;
      _routeRevision++;
    });
  }

  Future<void> _focusActiveTripStop() async {
    final stop = _activeTripStop;
    if (stop == null) {
      return;
    }
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(stop.attraction.location, 15.5),
    );
  }

  Future<void> _showMapStopAction(ItineraryStop stop) async {
    final action = await showModalBottomSheet<_MapStopAction>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _MapStopActionSheet(stop: stop),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MapStopAction.continueTrip:
        break;
      case _MapStopAction.proceed:
        final index = _itinerary.indexOf(stop);
        if (index >= 0) {
          setState(() {
            _activeStopIndex = index;
            _tripStatus = FeatureCTripStatus.traveling;
            _itineraryListVisible = true;
          });
        }
        break;
      case _MapStopAction.cancel:
        final confirmed = await _confirmCancel(stop);
        if (confirmed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${stop.attraction.name} removed')),
          );
        }
        break;
    }
  }

  Future<bool> _confirmCancel(ItineraryStop stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel destination?'),
        content: Text('Remove ${stop.attraction.name} from this itinerary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _removeStop(stop);
      return true;
    }
    return false;
  }

  Future<void> _fitItineraryMap() async {
    final controller = _mapController;
    if (controller == null || _itinerary.isEmpty) {
      return;
    }
    var minLat = _itinerary.first.attraction.location.latitude;
    var maxLat = minLat;
    var minLng = _itinerary.first.attraction.location.longitude;
    var maxLng = minLng;
    for (final stop in _itinerary) {
      final location = stop.attraction.location;
      minLat = min(minLat, location.latitude);
      maxLat = max(maxLat, location.latitude);
      minLng = min(minLng, location.longitude);
      maxLng = max(maxLng, location.longitude);
    }
    if (minLat == maxLat && minLng == maxLng) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(_itinerary.first.attraction.location, 14.5),
      );
      return;
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        88,
      ),
    );
  }

  SharedMapView get _currentMapView {
    if (_itinerary.isEmpty) {
      return SharedMapView(
        signature: 'plan-empty|${_pointKey(widget.currentLocation)}',
        currentLocation: widget.currentLocation,
        currentAccuracyMeters: widget.currentAccuracyMeters,
        initialTarget:
            widget.currentLocation ?? const LatLng(3.1478, 101.6953),
        initialZoom: widget.currentLocation == null ? 12 : 15,
      );
    }
    return SharedMapView(
      signature:
          'plan|${_pointKey(widget.currentLocation)}|mode:${_travelMode.name}|trip:${_tripStatus.name}:$_activeStopIndex|icons:$_markerIconRevision|route:$_routeRevision|${_itinerary.map((stop) => '${stop.order}:${stop.attraction.name}').join('|')}',
      currentLocation: widget.currentLocation,
      currentAccuracyMeters: widget.currentAccuracyMeters,
      initialTarget: _itinerary.first.attraction.location,
      initialZoom: 13.2,
      extraMarkers: _featureCMarkers(),
      extraPolylines: _featureCPolylines(),
    );
  }

  Future<void> _loadFeatureCMarkerIcons() async {
    final stops = List<ItineraryStop>.of(_itinerary);
    var changed = false;
    for (final stop in stops) {
      final key = _featureCMarkerKey(stop);
      if (_featureCMarkerIcons.containsKey(key)) {
        continue;
      }
      _featureCMarkerIcons[key] = await _createFeatureCMarkerIcon(stop);
      changed = true;
    }
    if (!mounted || !changed) {
      return;
    }
    setState(() {
      _markerIconRevision++;
    });
  }

  Future<void> _loadFeatureCDrivingRoute() async {
    if (_travelMode == BlindBoxTravelMode.transit) {
      setState(() {
        _featureCRoutePoints = const [];
        _routeRevision++;
      });
      return;
    }
    if (!_GoogleMapsConfig.isReady || _itinerary.length < 2) {
      return;
    }
    final routeTargets = [
      if (widget.currentLocation != null) widget.currentLocation!,
      for (final stop in _itinerary) stop.attraction.location,
    ];
    if (routeTargets.length < 2) {
      return;
    }
    try {
      final roadPoints = <LatLng>[];
      for (var i = 0; i < routeTargets.length - 1; i++) {
        final segment = await _GoogleMapsApi.fetchDrivingRoute(
          origin: routeTargets[i],
          destination: routeTargets[i + 1],
          apiKey: _GoogleMapsConfig.apiKey,
        );
        if (roadPoints.isNotEmpty && segment.points.isNotEmpty) {
          roadPoints.addAll(segment.points.skip(1));
        } else {
          roadPoints.addAll(segment.points);
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _featureCRoutePoints = roadPoints;
        _routeRevision++;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _featureCRoutePoints = const [];
        _routeRevision++;
      });
    }
  }

  String _featureCMarkerKey(ItineraryStop stop) {
    return [
      stop.attraction.name,
      stop.attraction.imageAsset,
      stop.startMinute,
      stop.cost,
      stop.attraction.color.toARGB32(),
    ].join('|');
  }

  Future<BitmapDescriptor> _createFeatureCMarkerIcon(ItineraryStop stop) async {
    const width = 264.0;
    const height = 112.0;
    const cardHeight = 74.0;
    const imageSize = 54.0;
    const cardRadius = 16.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, width, cardHeight),
      const Radius.circular(cardRadius),
    );

    canvas.drawRRect(
      cardRect.shift(const Offset(0, 4)),
      Paint()
        ..isAntiAlias = true
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      cardRect,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white,
    );

    final attractionImage = await _loadFeatureCMarkerImage(
      stop.attraction.imageAsset,
    );
    final imageRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 10, imageSize, imageSize),
      const Radius.circular(12),
    );
    canvas.save();
    canvas.clipRRect(imageRect);
    canvas.drawImageRect(
      attractionImage,
      Rect.fromLTWH(
        0,
        0,
        attractionImage.width.toDouble(),
        attractionImage.height.toDouble(),
      ),
      imageRect.outerRect,
      Paint()..isAntiAlias = true,
    );
    canvas.restore();

    final titlePainter = TextPainter(
      text: TextSpan(
        text: stop.attraction.name,
        style: const TextStyle(
          color: Color(0xFF101828),
          fontSize: 15,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: width - 84);
    titlePainter.paint(canvas, const Offset(74, 11));

    final metaPainter = TextPainter(
      text: TextSpan(
        text: '${_formatClock(stop.startMinute)} / RM ${stop.cost}',
        style: const TextStyle(
          color: Color(0xFF475467),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    )..layout(maxWidth: width - 84);
    metaPainter.paint(canvas, const Offset(74, 51));

    final pinCenter = Offset(width / 2, height - 18);
    final pinPaint = Paint()
      ..isAntiAlias = true
      ..color = stop.attraction.color;
    final pinPath = Path()
      ..moveTo(width / 2 - 13, cardHeight - 2)
      ..quadraticBezierTo(width / 2, height - 2, width / 2 + 13, cardHeight - 2)
      ..close();
    canvas.drawPath(pinPath, pinPaint);
    canvas.drawCircle(pinCenter, 14, pinPaint);
    canvas.drawCircle(
      pinCenter,
      5,
      Paint()
        ..isAntiAlias = true
        ..color = Colors.white,
    );

    final markerImage = await recorder.endRecording().toImage(
          width.toInt(),
          height.toInt(),
        );
    final byteData = await markerImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.bytes(
      byteData!.buffer.asUint8List(),
    );
  }

  Future<ui.Image> _loadFeatureCMarkerImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 108,
      targetHeight: 108,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Set<Marker> _featureCMarkers() {
    return {
      for (final stop in _itinerary)
        Marker(
          markerId: MarkerId('feature_c_stop_${stop.order}'),
          position: stop.attraction.location,
          infoWindow: InfoWindow(
            title: stop.attraction.name,
            snippet: '${_formatClock(stop.startMinute)} / RM ${stop.cost}',
          ),
          icon: _featureCMarkerIcons[_featureCMarkerKey(stop)] ??
              BitmapDescriptor.defaultMarkerWithHue(
                _attractionMarkerHue(stop.attraction.color),
              ),
          anchor: const Offset(0.5, 0.98),
          zIndexInt: 20 + stop.order,
          onTap: () => _showMapStopAction(stop),
        ),
    };
  }

  Set<Polyline> _featureCPolylines() {
    final routePoints = _featureCRoutePoints;
    return {
      if (routePoints.length > 1)
        Polyline(
          polylineId: const PolylineId('feature_c_route_shadow'),
          points: routePoints,
          width: 8,
          color: const Color(0xFFFFD43B),
          zIndex: 1,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      if (routePoints.length > 1)
        Polyline(
          polylineId: const PolylineId('feature_c_route'),
          points: routePoints,
          width: 4,
          color: const Color(0xFF0B7CFF),
          zIndex: 2,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
    };
  }

  double _attractionMarkerHue(Color color) {
    if (color == const Color(0xFFFFCE3D)) {
      return BitmapDescriptor.hueYellow;
    }
    if (color == const Color(0xFF00E2A7) ||
        color == const Color(0xFF3CCB7F)) {
      return BitmapDescriptor.hueGreen;
    }
    if (color == const Color(0xFFFF7A59)) {
      return BitmapDescriptor.hueOrange;
    }
    if (color == const Color(0xFF7C5CFF)) {
      return BitmapDescriptor.hueViolet;
    }
    if (color == const Color(0xFF38D9FF) ||
        color == const Color(0xFF40A9FF) ||
        color == const Color(0xFF00A9CE)) {
      return BitmapDescriptor.hueAzure;
    }
    return BitmapDescriptor.hueRose;
  }

  void _publishMapView() {
    if (!widget.active) {
      return;
    }
    final view = _currentMapView;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) {
        widget.onMapViewChanged(view);
      }
    });
  }

  List<ItineraryStop> _buildItinerary({
    required int stopCount,
    required double totalDistanceKm,
    required PriceTier priceTier,
    required BlindBoxTravelMode travelMode,
  }) {
    final attractions = _pickBlindBoxMatches(
      stopCount: stopCount,
      totalDistanceKm: totalDistanceKm,
      priceTier: priceTier,
    );
    final distanceTotal = attractions.fold<double>(
      0,
      (sum, attraction) => sum + attraction.suggestedDistanceKm,
    );
    var clock = 9 * 60;

    return [
      for (var i = 0; i < attractions.length; i++)
        (() {
          final attraction = attractions[i];
          final distance = distanceTotal == 0
              ? totalDistanceKm / attractions.length
              : attraction.suggestedDistanceKm * totalDistanceKm / distanceTotal;
          final travelMinutes = travelMode.travelMinutesFor(distance);
          final arrival = clock + travelMinutes;
          final start = max(arrival, attraction.openMinute);
          final end = min(
            start + attraction.stayMinutes,
            attraction.closeMinute,
          );
          clock = end;
          return ItineraryStop(
            order: i + 1,
            attraction: attraction,
            startMinute: start,
            endMinute: end,
            distanceKm: distance,
            travelMinutes: travelMinutes,
            travelMode: travelMode,
            cost: attraction.costFor(priceTier),
          );
        })(),
    ];
  }

  List<Attraction> _pickBlindBoxMatches({
    required int stopCount,
    required double totalDistanceKm,
    required PriceTier priceTier,
  }) {
    final distanceLimit = max(1.0, totalDistanceKm);
    var expandedDistanceLimit = distanceLimit;
    var exactMatches = _matchingLocations(
      priceTier: priceTier,
      distanceLimit: expandedDistanceLimit,
    );
    while (_uniqueImageCount(exactMatches) < stopCount &&
        expandedDistanceLimit < 50) {
      expandedDistanceLimit = min(50, expandedDistanceLimit + 5);
      exactMatches = _matchingLocations(
        priceTier: priceTier,
        distanceLimit: expandedDistanceLimit,
      );
    }
    final distanceMatches = _blindBoxLocations
        .where((location) => location.suggestedDistanceKm <= distanceLimit)
        .toList();
    final pool = _uniqueImageCount(exactMatches) >= stopCount
        ? exactMatches
        : _uniqueImageCount(distanceMatches) >= stopCount
            ? distanceMatches
            : _blindBoxLocations;
    return _sampleUniquePhotoLocations(pool, stopCount);
  }

  int _uniqueImageCount(List<Attraction> locations) =>
      locations.map((location) => location.imageAsset).toSet().length;

  List<Attraction> _matchingLocations({
    required PriceTier priceTier,
    required double distanceLimit,
  }) {
    return _blindBoxLocations
        .where(
          (location) =>
              location.priceTier == priceTier &&
              location.suggestedDistanceKm <= distanceLimit,
        )
        .toList();
  }

  List<Attraction> _sampleUniquePhotoLocations(
    List<Attraction> pool,
    int stopCount,
  ) {
    final shuffled = List<Attraction>.of(pool)..shuffle(Random());
    final usedImages = <String>{};
    final selected = <Attraction>[];
    for (final location in shuffled) {
      if (usedImages.add(location.imageAsset)) {
        selected.add(location);
      }
      if (selected.length == stopCount) {
        return selected;
      }
    }
    for (final location in shuffled) {
      if (!selected.contains(location)) {
        selected.add(location);
      }
      if (selected.length == stopCount) {
        break;
      }
    }
    return selected;
  }

  @override
  Widget build(BuildContext context) {
    _mapController = widget.mapController ?? _mapController;
    _publishMapView();
    if (_itinerary.isNotEmpty || _tripStatus == FeatureCTripStatus.completed) {
      return Stack(
        key: const Key('feature-c-results-map'),
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: Column(
                children: [
                  const _SectionTitle(
                    icon: Icons.explore_rounded,
                    title: 'KL Blind Box',
                    trailing: 'Map results',
                  ),
                  const Spacer(),
                  if (_itinerary.isNotEmpty)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: _FeatureCResultsToggle(
                        count: _itinerary.length,
                        expanded: _itineraryListVisible,
                        onTap: () => setState(
                          () => _itineraryListVisible = !_itineraryListVisible,
                        ),
                      ),
                    )
                  else
                    _FeatureCTripCompletedBanner(
                      onPlanAnotherTrip: _resetFeatureCPlanner,
                    ),
                ],
              ),
            ),
          ),
          if (_itineraryListVisible && _itinerary.isNotEmpty)
            _FeatureCResultsSheet(
              stops: _itinerary,
              priceTier: _priceTier,
              ongoingDestination: widget.ongoingDestination,
              tripStatus: _tripStatus,
              activeStopIndex: _activeStopIndex,
              tripTotalStops: _tripTotalStops,
              completedStopCount: _completedStopCount,
              onClose: () => setState(() => _itineraryListVisible = false),
              onCancel: _confirmCancel,
              onFocusStop: _focusItineraryStop,
              onChooseRoute: widget.onGoNow,
              onStartTrip: _startFeatureCTrip,
              onArrived: _markActiveStopArrived,
              onNextPlace: _goToNextFeatureCStop,
              onFinishTrip: _finishFeatureCTrip,
            ),
        ],
      );
    }

    return _BlueShell(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          MediaQuery.paddingOf(context).top + 8,
          18,
          22,
        ),
        children: [
          const _SectionTitle(
            icon: Icons.explore_rounded,
            title: 'KL Blind Box',
            trailing: '1000 places',
          ),
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PlanSlider(
                  icon: Icons.place_rounded,
                  label: 'Attractions',
                  valueLabel: '${_attractionCount.round()} stops',
                  value: _attractionCount,
                  min: 3,
                  max: 6,
                  divisions: 3,
                  onChanged: (value) => setState(() {
                    _attractionCount = value;
                    _itinerary = const [];
                  }),
                ),
                _PlanSlider(
                  icon: Icons.route_rounded,
                  label: 'Trip distance',
                  valueLabel: '${_distanceKm.round()} km',
                  value: _distanceKm,
                  min: 1,
                  max: 50,
                  divisions: 49,
                  onChanged: (value) => setState(() {
                    _distanceKm = value;
                    _itinerary = const [];
                  }),
                ),
                _BlindBoxTravelModeSelector(
                  value: _travelMode,
                  onChanged: (value) => setState(() {
                    _travelMode = value;
                    _itinerary = const [];
                    _featureCRoutePoints = const [];
                  }),
                ),
                const SizedBox(height: 8),
                _PlanSlider(
                  icon: Icons.payments_rounded,
                  label: 'Pricing',
                  valueLabel: _priceTier.label,
                  value: _priceIndex,
                  min: 0,
                  max: 2,
                  divisions: 2,
                  onChanged: (value) => setState(() {
                    _priceIndex = value;
                    _itinerary = const [];
                  }),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('generate-route'),
                    onPressed: _generate,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Open Blind Box'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _GlassPanel(
            child: Row(
              children: [
                const Icon(Icons.event_note_rounded, color: Color(0xFF40A9FF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Choose attraction count, distance, and pricing, then open a blind box from 1000 KL locations.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  const _DashboardHeader({
    required this.role,
    required this.wallet,
    required this.showWallet,
  });

  final UserRole role;
  final double wallet;
  final bool showWallet;

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
                      : showWallet
                          ? 'Wallet RM ${wallet.toStringAsFixed(2)}'
                          : 'Classic destination itinerary',
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
    required this.onTextChanged,
    required this.onSearch,
    required this.onClearDestination,
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
  final VoidCallback onTextChanged;
  final VoidCallback onSearch;
  final VoidCallback onClearDestination;
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
                  onChanged: (_) => onTextChanged(),
                  onSubmitted: (_) => onSearch(),
                  style: const TextStyle(color: Color(0xFF172033)),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF2F6FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: toController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear destination',
                            onPressed: onClearDestination,
                            icon: const Icon(Icons.close_rounded),
                          ),
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
    this.initialTarget,
    this.initialZoom,
    this.extraMarkers = const <Marker>{},
    this.extraPolylines = const <Polyline>{},
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
  final LatLng? initialTarget;
  final double? initialZoom;
  final Set<Marker> extraMarkers;
  final Set<Polyline> extraPolylines;
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
    final currentAndVehicleTogether =
        widget.currentLocation != null &&
        widget.vehicleLocation != null &&
        _pointKey(widget.currentLocation) == _pointKey(widget.vehicleLocation);
    final firstStopIsDestination =
        firstStop != null &&
        widget.candidate != null &&
        _distanceBetweenPoints(firstStop, widget.candidate!.location) < 80;
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
      ...widget.extraPolylines,
    };
    final markers = <Marker>{
      if (widget.currentLocation != null && !currentAndVehicleTogether)
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
      if (firstStop != null && widget.navigating && !firstStopIsDestination)
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
      ...widget.extraMarkers,
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
                  widget.initialTarget ??
                  widget.currentLocation ??
                  _LiveGoogleMapSurface._defaultKualaLumpur,
              zoom:
                  widget.initialZoom ?? (widget.currentLocation == null ? 12 : 15),
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

  double _distanceBetweenPoints(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }
}

class _MapLocationButton extends StatelessWidget {
  const _MapLocationButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-current-location'),
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: const Color(0x33001844),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onPressed,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF0B7CFF),
                    size: 23,
                  ),
          ),
        ),
      ),
    );
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
            const SizedBox(height: 10),
            Row(
              children: [
                _DarkMiniMetric(Icons.sync_alt_rounded, route.transfers),
                const SizedBox(width: 8),
                Expanded(child: _PeakCrowdBars(crowd: route.crowd)),
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

class _PeakCrowdBars extends StatelessWidget {
  const _PeakCrowdBars({required this.crowd});

  final double crowd;

  @override
  Widget build(BuildContext context) {
    final levels = [
      (crowd * .75).clamp(.08, 1).toDouble(),
      crowd.clamp(.08, 1).toDouble(),
      (crowd * .62).clamp(.08, 1).toDouble(),
      (crowd * .9).clamp(.08, 1).toDouble(),
    ];
    return Row(
      children: [
        const Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF0B7CFF)),
        const SizedBox(width: 4),
        SizedBox(
          height: 20,
          width: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final level in levels) ...[
                Expanded(
                  child: Container(
                    height: 18 * level,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B7CFF).withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
              ],
            ],
          ),
        ),
        const Text(
          'Peak',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TripDetailsDropdown extends StatefulWidget {
  const _TripDetailsDropdown({
    required this.destination,
    required this.route,
    required this.ongoing,
    required this.onStop,
  });

  final DestinationCandidate? destination;
  final TransitOption route;
  final bool ongoing;
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
                    if (widget.ongoing)
                      const Text(
                        'On Going',
                        style: TextStyle(
                          color: Color(0xFF0B7CFF),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
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

class _PlanSlider extends StatelessWidget {
  const _PlanSlider({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF40A9FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _BlindBoxTravelModeSelector extends StatelessWidget {
  const _BlindBoxTravelModeSelector({
    required this.value,
    required this.onChanged,
  });

  final BlindBoxTravelMode value;
  final ValueChanged<BlindBoxTravelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(value.icon, size: 18, color: const Color(0xFF40A9FF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Travel mode',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                value.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<BlindBoxTravelMode>(
            segments: const [
              ButtonSegment(
                value: BlindBoxTravelMode.drive,
                icon: Icon(Icons.directions_car_rounded),
                label: Text('Drive'),
              ),
              ButtonSegment(
                value: BlindBoxTravelMode.transit,
                icon: Icon(Icons.directions_transit_rounded),
                label: Text('Transit'),
              ),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _ItinerarySummary extends StatelessWidget {
  const _ItinerarySummary({required this.stops, required this.priceTier});

  final List<ItineraryStop> stops;
  final PriceTier priceTier;

  @override
  Widget build(BuildContext context) {
    final totalCost = stops.fold<int>(0, (sum, stop) => sum + stop.cost);
    final totalDistance = stops.fold<double>(
      0,
      (sum, stop) => sum + stop.distanceKm,
    );
    final totalTravel = stops.fold<int>(
      0,
      (sum, stop) => sum + stop.travelMinutes,
    );
    final travelMode = stops.first.travelMode;
    final start = stops.first.startMinute;
    final end = stops.last.endMinute;

    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Itinerary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                icon: Icons.schedule_rounded,
                label: '${_formatClock(start)} - ${_formatClock(end)}',
              ),
              _SummaryChip(
                icon: Icons.route_rounded,
                label: '${totalDistance.toStringAsFixed(1)} km',
              ),
              _SummaryChip(
                icon: travelMode.icon,
                label: '${travelMode.label} / $totalTravel min',
              ),
              _SummaryChip(
                icon: Icons.payments_rounded,
                label: '${priceTier.label} / RM $totalCost',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MapStopAction { continueTrip, proceed, cancel }

class _FeatureCResultsToggle extends StatelessWidget {
  const _FeatureCResultsToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      key: const Key('feature-c-results-toggle'),
      heroTag: 'feature-c-results-toggle',
      onPressed: onTap,
      backgroundColor: const Color(0xFF0B7CFF),
      foregroundColor: Colors.white,
      icon: Icon(expanded ? Icons.close_rounded : Icons.list_alt_rounded),
      label: Text(expanded ? 'Hide results' : '$count results'),
    );
  }
}

class _FeatureCTripCompletedBanner extends StatelessWidget {
  const _FeatureCTripCompletedBanner({required this.onPlanAnotherTrip});

  final VoidCallback onPlanAnotherTrip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33001844),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.flag_rounded, color: Color(0xFF0B7CFF)),
              const Text(
                'Trip completed',
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
              FilledButton.icon(
                onPressed: onPlanAnotherTrip,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Plan another trip'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 8,
              value: 1,
              backgroundColor: Color(0x3322C7F4),
              color: Color(0xFF0B7CFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCResultsSheet extends StatelessWidget {
  const _FeatureCResultsSheet({
    required this.stops,
    required this.priceTier,
    required this.ongoingDestination,
    required this.tripStatus,
    required this.activeStopIndex,
    required this.tripTotalStops,
    required this.completedStopCount,
    required this.onClose,
    required this.onCancel,
    required this.onFocusStop,
    required this.onChooseRoute,
    required this.onStartTrip,
    required this.onArrived,
    required this.onNextPlace,
    required this.onFinishTrip,
  });

  final List<ItineraryStop> stops;
  final PriceTier priceTier;
  final String? ongoingDestination;
  final FeatureCTripStatus tripStatus;
  final int activeStopIndex;
  final int tripTotalStops;
  final int completedStopCount;
  final VoidCallback onClose;
  final Future<bool> Function(ItineraryStop stop) onCancel;
  final ValueChanged<ItineraryStop> onFocusStop;
  final ValueChanged<String> onChooseRoute;
  final VoidCallback onStartTrip;
  final VoidCallback onArrived;
  final VoidCallback onNextPlace;
  final VoidCallback onFinishTrip;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          key: const Key('feature-c-results-list'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .56,
          ),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: const Color(0xEE102D4A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: .14)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44001844),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, color: Color(0xFF40A9FF)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Results',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hide results',
                      onPressed: onClose,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FeatureCTripProgressPanel(
                  stops: stops,
                  status: tripStatus,
                  activeStopIndex: activeStopIndex,
                  totalStops: tripTotalStops,
                  completedStops: completedStopCount,
                  onChooseRoute: onChooseRoute,
                  onStartTrip: onStartTrip,
                  onArrived: onArrived,
                  onNextPlace: onNextPlace,
                  onFinishTrip: onFinishTrip,
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < stops.length; i++) ...[
                  Dismissible(
                    key: ValueKey('itinerary-${stops[i].attraction.name}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => onCancel(stops[i]),
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B43),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                      ),
                    ),
                    child: _ItineraryStopCard(
                      stop: stops[i],
                      active: i == activeStopIndex &&
                          tripStatus != FeatureCTripStatus.notStarted,
                      completed: tripStatus == FeatureCTripStatus.completed ||
                          i < activeStopIndex,
                      arrived: i == activeStopIndex &&
                          tripStatus == FeatureCTripStatus.arrived,
                      ongoing: ongoingDestination == stops[i].attraction.name,
                      onFocus: () => onFocusStop(stops[i]),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapStopActionSheet extends StatelessWidget {
  const _MapStopActionSheet({required this.stop});

  final ItineraryStop stop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    stop.attraction.imageAsset,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 76,
                      height: 76,
                      color: stop.attraction.color,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.attraction.name,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${_formatClock(stop.startMinute)} - ${_formatClock(stop.endMinute)} / ${stop.attraction.hours}',
                        style: const TextStyle(color: Color(0xFF687386)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_MapStopAction.proceed),
                icon: const Icon(Icons.near_me_rounded),
                label: const Text('Proceed'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.of(context).pop(_MapStopAction.continueTrip),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Continue itinerary'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_MapStopAction.cancel),
                icon: const Icon(Icons.cancel_rounded),
                label: const Text('Cancel this stop'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCTripProgressPanel extends StatelessWidget {
  const _FeatureCTripProgressPanel({
    required this.stops,
    required this.status,
    required this.activeStopIndex,
    required this.totalStops,
    required this.completedStops,
    required this.onChooseRoute,
    required this.onStartTrip,
    required this.onArrived,
    required this.onNextPlace,
    required this.onFinishTrip,
  });

  final List<ItineraryStop> stops;
  final FeatureCTripStatus status;
  final int activeStopIndex;
  final int totalStops;
  final int completedStops;
  final ValueChanged<String> onChooseRoute;
  final VoidCallback onStartTrip;
  final VoidCallback onArrived;
  final VoidCallback onNextPlace;
  final VoidCallback onFinishTrip;

  @override
  Widget build(BuildContext context) {
    final safeIndex = activeStopIndex.clamp(0, max(0, stops.length - 1)).toInt();
    final activeStop = stops.isEmpty ? null : stops[safeIndex];
    final total = max(1, totalStops == 0 ? stops.length : totalStops);
    final completed = completedStops.clamp(0, total).toDouble();
    final progress = switch (status) {
      FeatureCTripStatus.notStarted => 0.0,
      FeatureCTripStatus.traveling => completed / total,
      FeatureCTripStatus.arrived => min(1.0, (completed + .5) / total),
      FeatureCTripStatus.completed => 1.0,
    };
    final title = switch (status) {
      FeatureCTripStatus.notStarted => 'Ready to start',
      FeatureCTripStatus.traveling =>
        'Going to ${activeStop?.attraction.name ?? 'next place'}',
      FeatureCTripStatus.arrived =>
        'Arrived at ${activeStop?.attraction.name ?? 'this place'}',
      FeatureCTripStatus.completed => 'Trip completed',
    };
    final subtitle = switch (status) {
      FeatureCTripStatus.notStarted => '$total places queued',
      FeatureCTripStatus.traveling =>
        'Completed ${completed.toInt()} of $total',
      FeatureCTripStatus.arrived => completedStops >= total - 1
          ? 'Last place reached'
          : 'Current place will be removed from the list',
      FeatureCTripStatus.completed => 'End of itinerary',
    };
    final String actionLabel;
    final VoidCallback? actionCallback;
    switch (status) {
      case FeatureCTripStatus.notStarted:
        actionLabel = 'Start Trip';
        actionCallback = onStartTrip;
        break;
      case FeatureCTripStatus.traveling:
        actionLabel = 'Arrived';
        actionCallback = onArrived;
        break;
      case FeatureCTripStatus.arrived:
        actionLabel =
            safeIndex >= stops.length - 1 ? 'Finish Trip' : 'Next Place';
        actionCallback =
            safeIndex >= stops.length - 1 ? onFinishTrip : onNextPlace;
        break;
      case FeatureCTripStatus.completed:
        actionLabel = 'Completed';
        actionCallback = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x3322C7F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x6638D9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Color(0xFF40A9FF)),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: status == FeatureCTripStatus.traveling &&
                          activeStop != null
                      ? () => onChooseRoute(activeStop.attraction.name)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (status == FeatureCTripStatus.traveling &&
                                activeStop != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.alt_route_rounded,
                                  size: 16,
                                  color: Color(0xFF40A9FF),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .72),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton(
                    onPressed: actionCallback,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0, 1).toDouble(),
              backgroundColor: const Color(0x3322C7F4),
              color: const Color(0xFF0B7CFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      backgroundColor: Colors.white.withValues(alpha: .12),
      side: BorderSide(color: Colors.white.withValues(alpha: .14)),
    );
  }
}

class _ItineraryStopCard extends StatelessWidget {
  const _ItineraryStopCard({
    required this.stop,
    required this.active,
    required this.completed,
    required this.arrived,
    required this.ongoing,
    required this.onFocus,
  });

  final ItineraryStop stop;
  final bool active;
  final bool completed;
  final bool arrived;
  final bool ongoing;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final statusLabel = completed
        ? 'Completed'
        : arrived
            ? 'Arrived'
            : active
                ? 'Going'
                : 'Queued';
    final statusIcon = completed
        ? Icons.check_circle_rounded
        : arrived
            ? Icons.place_rounded
            : active
                ? Icons.navigation_rounded
                : Icons.radio_button_unchecked_rounded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFocus,
      child: _GlassPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                stop.attraction.imageAsset,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 84,
                  height: 84,
                  color: stop.attraction.color,
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.attraction.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ItineraryDetailRow(
                    icon: Icons.schedule_rounded,
                    text:
                        '${_formatClock(stop.startMinute)} - ${_formatClock(stop.endMinute)}',
                  ),
                  _ItineraryDetailRow(
                    icon: Icons.access_time_rounded,
                    text: 'Opening hours: ${stop.attraction.hours}',
                  ),
                  _ItineraryDetailRow(
                    icon: Icons.route_rounded,
                    text: 'Distance: ${stop.distanceKm.toStringAsFixed(1)} km',
                  ),
                  _ItineraryDetailRow(
                    icon: stop.travelMode.icon,
                    text: stop.travelMinutes == 0
                        ? 'Start point / ${stop.travelMode.label}'
                        : '${stop.travelMode.label}: ${stop.travelMinutes} min',
                  ),
                  _ItineraryDetailRow(
                    icon: Icons.payments_rounded,
                    text: 'Cost: RM ${stop.cost}',
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: onFocus,
                      icon: Icon(statusIcon),
                      label: Text(ongoing ? 'On Going' : statusLabel),
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

class _ItineraryDetailRow extends StatelessWidget {
  const _ItineraryDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: .72)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.white.withValues(alpha: .76)),
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
  static String drivingRouteErrorMessage(Object error) {
    final message = error.toString();
    final normalized = message.toLowerCase();
    if (normalized.contains('legacyapinotactivated') ||
        normalized.contains('not enabled') ||
        normalized.contains('not been used') ||
        normalized.contains('api_not_activated') ||
        normalized.contains('request_denied')) {
      return 'Google route API is not enabled for this key. Enable Routes Preferred API or Routes API in Google Cloud.';
    }
    if (normalized.contains('api key') ||
        normalized.contains('permission') ||
        normalized.contains('forbidden')) {
      return 'Google Maps API key cannot request driving routes.';
    }
    return 'Google driving route failed.';
  }

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

  static Future<List<TransitOption>> fetchTravelOptions({
    required LatLng origin,
    required DestinationCandidate destination,
    required String apiKey,
  }) async {
    final route = await fetchDrivingRoute(
      origin: origin,
      destination: destination.location,
      apiKey: apiKey,
    );
    final distanceKm = max(.2, route.distanceMeters / 1000);
    final transitMinutes = max(12, (distanceKm / 24 * 60 + 10).round());
    final walkMinutes = max(4, (distanceKm / 4.8 * 60).round());
    final transitFare = (1.20 + distanceKm * .55).clamp(1.20, 8.00);
    return [
      TransitOption(
        label: 'Drive',
        chain: 'Car route',
        time: route.time,
        distance: route.distance,
        fare: 'Fare varies',
        transfers: 'Direct',
        crowd: .35,
        color: const Color(0xFF22B8F2),
        legs: [
          RouteLeg(
            fromName: 'Current location',
            toName: destination.name,
            mode: 'Drive',
            time: route.time,
            distance: route.distance,
            icon: Icons.directions_car_rounded,
            points: route.points,
          ),
        ],
        firstLegPointCount: route.points.length,
        firstStopLabel: destination.name,
        nextInstruction: 'Drive to ${destination.name}',
      ),
      TransitOption(
        label: 'Transit',
        chain: 'Walk -> Rail/Bus -> Walk',
        time: _formatMinutes(transitMinutes),
        distance: route.distance,
        fare: 'RM ${transitFare.toStringAsFixed(2)}',
        transfers: distanceKm > 7 ? '2 transfers' : '1 transfer',
        crowd: .58,
        color: const Color(0xFF00C48C),
        legs: [
          RouteLeg(
            fromName: 'Current location',
            toName: destination.name,
            mode: 'Transit',
            time: _formatMinutes(transitMinutes),
            distance: route.distance,
            icon: Icons.directions_transit_rounded,
            points: const [],
          ),
        ],
        firstStopLabel: 'Nearest station',
        nextInstruction: 'Use the nearest rail or bus connection',
      ),
      TransitOption(
        label: 'Walk',
        chain: 'Walking route',
        time: _formatMinutes(walkMinutes),
        distance: route.distance,
        fare: 'Free',
        transfers: 'No transfer',
        crowd: .12,
        color: const Color(0xFFFFB000),
        legs: [
          RouteLeg(
            fromName: 'Current location',
            toName: destination.name,
            mode: 'Walk',
            time: _formatMinutes(walkMinutes),
            distance: route.distance,
            icon: Icons.directions_walk_rounded,
            points: const [],
          ),
        ],
        firstStopLabel: destination.name,
        nextInstruction: 'Walk toward ${destination.name}',
      ),
    ];
  }

  static Future<_DrivingRoute> fetchDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
  }) async {
    Object? roadServiceError;
    try {
      return await _fetchOsrmDrivingRoute(
        origin: origin,
        destination: destination,
      );
    } catch (error) {
      roadServiceError = error;
    }
    if (apiKey.isEmpty) {
      throw roadServiceError ?? 'No road route found';
    }
    Object? routesError;
    try {
      return await _fetchRoutesDrivingRoute(
        origin: origin,
        destination: destination,
        apiKey: apiKey,
      );
    } catch (error) {
      routesError = error;
    }
    try {
      return await _fetchDirectionsDrivingRoute(
        origin: origin,
        destination: destination,
        apiKey: apiKey,
      );
    } catch (directionsError) {
      throw 'Road service: $roadServiceError / '
          'Google Routes API: $routesError / '
          'Google Directions API: $directionsError';
    }
  }

  static Future<_DrivingRoute> _fetchRoutesDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
  }) async {
    final uri = Uri.https(
      'routespreferred.googleapis.com',
      '/v1:computeRoutes',
    );
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
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
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
        'computeAlternativeRoutes': false,
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
    if (routes.isEmpty) {
      throw 'No driving route found';
    }
    final route = routes.first as Map<String, dynamic>;
    final overviewPolyline = route['polyline'] as Map<String, dynamic>?;
    final points = _decodePolyline(
      (overviewPolyline?['encodedPolyline'] as String?) ?? '',
    );
    if (points.isEmpty) {
      throw 'Driving route did not include a road polyline';
    }
    final distanceMeters = (route['distanceMeters'] as num?)?.toDouble() ?? 0;
    final durationSeconds =
        _parseGoogleDurationSeconds(route['duration'] as String?);
    return _DrivingRoute(
      points: points,
      time: _formatDuration(route['duration'] as String?),
      distance: _formatMeters(distanceMeters.round()),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  static Future<_DrivingRoute> _fetchDirectionsDrivingRoute({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'driving',
      'region': 'my',
      'alternatives': 'false',
      'key': apiKey,
    });
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (response.statusCode != 200 || status != 'OK') {
      throw body['error_message'] ?? status ?? 'Unknown Directions API error';
    }
    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw 'No driving route found';
    }
    final route = routes.first as Map<String, dynamic>;
    final overviewPolyline =
        route['overview_polyline'] as Map<String, dynamic>?;
    final points = _decodePolyline(
      (overviewPolyline?['points'] as String?) ?? '',
    );
    if (points.isEmpty) {
      throw 'Driving route did not include a road polyline';
    }
    final legs = route['legs'] as List<dynamic>? ?? const [];
    final leg = legs.isEmpty
        ? const <String, dynamic>{}
        : legs.first as Map<String, dynamic>;
    final duration = leg['duration'] as Map<String, dynamic>? ?? const {};
    final distance = leg['distance'] as Map<String, dynamic>? ?? const {};
    final distanceMeters = (distance['value'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (duration['value'] as num?)?.toDouble() ?? 0;
    return _DrivingRoute(
      points: points,
      time: (duration['text'] as String?) ?? '--',
      distance: (distance['text'] as String?) ??
          _formatMeters(distanceMeters.round()),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  static Future<_DrivingRoute> _fetchOsrmDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final coordinates =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    Object? lastError;
    for (final server in const [
      ('router.project-osrm.org', '/route/v1/driving/'),
      ('routing.openstreetmap.de', '/routed-car/route/v1/driving/'),
    ]) {
      try {
        return await _fetchOsrmRouteFromServer(
          host: server.$1,
          pathPrefix: server.$2,
          coordinates: coordinates,
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? 'No road routing service available';
  }

  static Future<_DrivingRoute> _fetchOsrmRouteFromServer({
    required String host,
    required String pathPrefix,
    required String coordinates,
  }) async {
    final uri = Uri.https(host, '$pathPrefix$coordinates', {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'false',
      'alternatives': 'false',
    });
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 8));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final code = body['code'] as String?;
    if (response.statusCode != 200 || code != 'Ok') {
      throw (body['message'] as String?) ?? code ?? 'Unknown OSRM error';
    }
    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw 'No OSRM driving route found';
    }
    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry'] as Map<String, dynamic>? ?? const {};
    final coordinatesList =
        geometry['coordinates'] as List<dynamic>? ?? const [];
    final points = [
      for (final coordinate in coordinatesList)
        if (coordinate is List && coordinate.length >= 2)
          LatLng(
            (coordinate[1] as num).toDouble(),
            (coordinate[0] as num).toDouble(),
          ),
    ];
    if (points.isEmpty) {
      throw 'OSRM route did not include road geometry';
    }
    final distanceMeters = (route['distance'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (route['duration'] as num?)?.toDouble() ?? 0;
    return _DrivingRoute(
      points: points,
      time: _formatSeconds(durationSeconds),
      distance: _formatMeters(distanceMeters.round()),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  static double _parseGoogleDurationSeconds(String? duration) {
    if (duration == null || !duration.endsWith('s')) {
      return 0;
    }
    return double.tryParse(duration.substring(0, duration.length - 1)) ?? 0;
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

  static String _formatSeconds(num seconds) {
    final minutes = max(1, (seconds / 60).round());
    return _formatMinutes(minutes);
  }

  static String _formatMinutes(num minutesValue) {
    final minutes = max(1, minutesValue.round());
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

class _DrivingRoute {
  const _DrivingRoute({
    required this.points,
    required this.time,
    required this.distance,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<LatLng> points;
  final String time;
  final String distance;
  final double distanceMeters;
  final double durationSeconds;
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

  TransitOption copyWith({
    String? label,
    String? chain,
    String? time,
    String? distance,
    String? fare,
    String? transfers,
    double? crowd,
    Color? color,
    List<RouteLeg>? legs,
    int? firstLegPointCount,
    String? firstStopLabel,
    String? nextInstruction,
  }) {
    return TransitOption(
      label: label ?? this.label,
      chain: chain ?? this.chain,
      time: time ?? this.time,
      distance: distance ?? this.distance,
      fare: fare ?? this.fare,
      transfers: transfers ?? this.transfers,
      crowd: crowd ?? this.crowd,
      color: color ?? this.color,
      legs: legs ?? this.legs,
      firstLegPointCount: firstLegPointCount ?? this.firstLegPointCount,
      firstStopLabel: firstStopLabel ?? this.firstStopLabel,
      nextInstruction: nextInstruction ?? this.nextInstruction,
    );
  }

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

enum _TransitMode { rail, bus, feeder, walk }

class _TransitStopNode {
  const _TransitStopNode(this.id, this.name, this.location);

  final String id;
  final String name;
  final LatLng location;
}

class _TransitEdge {
  const _TransitEdge({
    required this.fromId,
    required this.toId,
    required this.mode,
    required this.operatorName,
    required this.routeName,
    required this.minutes,
    required this.fare,
    this.transferPenalty = false,
  });

  final String fromId;
  final String toId;
  final _TransitMode mode;
  final String operatorName;
  final String routeName;
  final int minutes;
  final double fare;
  final bool transferPenalty;

  String get operatorKey => mode == _TransitMode.walk
      ? 'walk'
      : '$operatorName|$routeName';

  String get modeLabel {
    return switch (mode) {
      _TransitMode.rail => routeName,
      _TransitMode.bus => '$operatorName Bus $routeName',
      _TransitMode.feeder => '$operatorName Feeder $routeName',
      _TransitMode.walk => 'Walk',
    };
  }

  IconData get icon {
    return switch (mode) {
      _TransitMode.rail => Icons.train_rounded,
      _TransitMode.bus => Icons.directions_bus_rounded,
      _TransitMode.feeder => Icons.airport_shuttle_rounded,
      _TransitMode.walk => Icons.directions_walk_rounded,
    };
  }

  _TransitEdge get reversed => copyWith(fromId: toId, toId: fromId);

  _TransitEdge copyWith({
    String? fromId,
    String? toId,
    bool? transferPenalty,
  }) {
    return _TransitEdge(
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      mode: mode,
      operatorName: operatorName,
      routeName: routeName,
      minutes: minutes,
      fare: fare,
      transferPenalty: transferPenalty ?? this.transferPenalty,
    );
  }

  List<LatLng> pointsFor(LatLng from, LatLng to) => [from, to];
}

class _TransitRouteVariant {
  const _TransitRouteVariant({
    required this.label,
    required this.color,
    required this.crowdBias,
    required this.costFor,
  });

  final String label;
  final Color color;
  final double crowdBias;
  final double Function(_TransitEdge edge) costFor;
}

const gtfsStaticRapidRailKlEndpoint =
    'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';
const gtfsStaticRapidBusKlEndpoint =
    'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl';
const gtfsStaticMrtFeederEndpoint =
    'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-mrtfeeder';
const gtfsStaticKtmbEndpoint = 'https://api.data.gov.my/gtfs-static/ktmb';

const _klTransitStops = [
  _TransitStopNode('kl_sentral', 'KL Sentral', LatLng(3.1340, 101.6869)),
  _TransitStopNode('muzium', 'Muzium Negara MRT', LatLng(3.1379, 101.6870)),
  _TransitStopNode('pasar_seni', 'Pasar Seni', LatLng(3.1426, 101.6955)),
  _TransitStopNode('masjid_jamek', 'Masjid Jamek', LatLng(3.1489, 101.6956)),
  _TransitStopNode('dang_wangi', 'Dang Wangi', LatLng(3.1567, 101.7018)),
  _TransitStopNode('bukit_nanas', 'Bukit Nanas', LatLng(3.1562, 101.7042)),
  _TransitStopNode('klcc', 'KLCC', LatLng(3.1590, 101.7132)),
  _TransitStopNode('ampang_park', 'Ampang Park', LatLng(3.1605, 101.7197)),
  _TransitStopNode('trx', 'Tun Razak Exchange', LatLng(3.1423, 101.7206)),
  _TransitStopNode('bukit_bintang', 'Bukit Bintang', LatLng(3.1468, 101.7113)),
  _TransitStopNode('merdeka', 'Merdeka MRT', LatLng(3.1416, 101.7020)),
  _TransitStopNode('maluri', 'Maluri', LatLng(3.1237, 101.7271)),
  _TransitStopNode('titiwangsa', 'Titiwangsa', LatLng(3.1736, 101.6959)),
  _TransitStopNode('bts', 'Bandar Tasik Selatan', LatLng(3.0766, 101.7115)),
  _TransitStopNode('kajang', 'Kajang', LatLng(2.9833, 101.7909)),
  _TransitStopNode('ampang', 'Ampang', LatLng(3.1490, 101.7601)),
  _TransitStopNode('sri_petaling', 'Sri Petaling', LatLng(3.0615, 101.6876)),
];

const _klTransitEdges = [
  _TransitEdge(
    fromId: 'kl_sentral',
    toId: 'pasar_seni',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Kelana Jaya',
    minutes: 4,
    fare: 1.30,
  ),
  _TransitEdge(
    fromId: 'pasar_seni',
    toId: 'masjid_jamek',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Kelana Jaya',
    minutes: 3,
    fare: .60,
  ),
  _TransitEdge(
    fromId: 'masjid_jamek',
    toId: 'dang_wangi',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Kelana Jaya',
    minutes: 3,
    fare: .70,
  ),
  _TransitEdge(
    fromId: 'dang_wangi',
    toId: 'klcc',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Kelana Jaya',
    minutes: 3,
    fare: .70,
  ),
  _TransitEdge(
    fromId: 'klcc',
    toId: 'ampang_park',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Kelana Jaya',
    minutes: 2,
    fare: .60,
  ),
  _TransitEdge(
    fromId: 'kl_sentral',
    toId: 'muzium',
    mode: _TransitMode.feeder,
    operatorName: 'Rapid KL',
    routeName: 'Linkway',
    minutes: 5,
    fare: 0,
  ),
  _TransitEdge(
    fromId: 'muzium',
    toId: 'pasar_seni',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 4,
    fare: 1.20,
  ),
  _TransitEdge(
    fromId: 'pasar_seni',
    toId: 'merdeka',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 3,
    fare: .70,
  ),
  _TransitEdge(
    fromId: 'merdeka',
    toId: 'bukit_bintang',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 3,
    fare: .70,
  ),
  _TransitEdge(
    fromId: 'bukit_bintang',
    toId: 'trx',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 3,
    fare: .70,
  ),
  _TransitEdge(
    fromId: 'trx',
    toId: 'maluri',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 5,
    fare: 1.10,
  ),
  _TransitEdge(
    fromId: 'maluri',
    toId: 'kajang',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 34,
    fare: 4.70,
  ),
  _TransitEdge(
    fromId: 'kl_sentral',
    toId: 'bukit_nanas',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'KL Monorail',
    minutes: 13,
    fare: 2.50,
  ),
  _TransitEdge(
    fromId: 'bukit_nanas',
    toId: 'titiwangsa',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'KL Monorail',
    minutes: 9,
    fare: 1.70,
  ),
  _TransitEdge(
    fromId: 'masjid_jamek',
    toId: 'ampang',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Ampang',
    minutes: 22,
    fare: 3.20,
  ),
  _TransitEdge(
    fromId: 'masjid_jamek',
    toId: 'bts',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Sri Petaling',
    minutes: 20,
    fare: 3.00,
  ),
  _TransitEdge(
    fromId: 'bts',
    toId: 'sri_petaling',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Sri Petaling',
    minutes: 9,
    fare: 1.40,
  ),
  _TransitEdge(
    fromId: 'kl_sentral',
    toId: 'bts',
    mode: _TransitMode.rail,
    operatorName: 'KTMB',
    routeName: 'KTM Komuter',
    minutes: 18,
    fare: 2.80,
  ),
  _TransitEdge(
    fromId: 'bts',
    toId: 'kajang',
    mode: _TransitMode.rail,
    operatorName: 'KTMB',
    routeName: 'KTM Komuter',
    minutes: 24,
    fare: 3.10,
  ),
  _TransitEdge(
    fromId: 'klcc',
    toId: 'trx',
    mode: _TransitMode.bus,
    operatorName: 'Rapid KL',
    routeName: 'GOKL/Rapid',
    minutes: 16,
    fare: 1.00,
  ),
  _TransitEdge(
    fromId: 'ampang_park',
    toId: 'ampang',
    mode: _TransitMode.bus,
    operatorName: 'Rapid KL',
    routeName: 'T300',
    minutes: 24,
    fare: 1.00,
  ),
  _TransitEdge(
    fromId: 'kajang',
    toId: 'ampang',
    mode: _TransitMode.bus,
    operatorName: 'Smart Selangor',
    routeName: 'Feeder',
    minutes: 46,
    fare: 0,
  ),
];

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

  Driver copyWith({LatLng? startLocation}) {
    return Driver(
      name,
      vehicle,
      rating,
      color,
      startLocation ?? this.startLocation,
    );
  }
}

class _DriverArrival {
  const _DriverArrival({
    required this.driver,
    required this.route,
  });

  final Driver driver;
  final _DrivingRoute route;
}

class Attraction {
  const Attraction({
    required this.name,
    required this.hours,
    required this.openMinute,
    required this.closeMinute,
    required this.baseCost,
    required this.stayMinutes,
    required this.suggestedDistanceKm,
    required this.priceTier,
    required this.imageAsset,
    required this.color,
    required this.location,
  });

  final String name;
  final String hours;
  final int openMinute;
  final int closeMinute;
  final int baseCost;
  final int stayMinutes;
  final double suggestedDistanceKm;
  final PriceTier priceTier;
  final String imageAsset;
  final Color color;
  final LatLng location;

  int costFor(PriceTier tier) {
    final multiplier = switch (tier) {
      PriceTier.budget => .7,
      PriceTier.midRange => 1.0,
      PriceTier.luxury => 1.8,
    };
    return max(0, (baseCost * multiplier).round());
  }
}

class ItineraryStop {
  const ItineraryStop({
    required this.order,
    required this.attraction,
    required this.startMinute,
    required this.endMinute,
    required this.distanceKm,
    required this.travelMinutes,
    required this.travelMode,
    required this.cost,
  });

  final int order;
  final Attraction attraction;
  final int startMinute;
  final int endMinute;
  final double distanceKm;
  final int travelMinutes;
  final BlindBoxTravelMode travelMode;
  final int cost;
}

extension on PriceTier {
  String get label => switch (this) {
        PriceTier.budget => 'Budget',
        PriceTier.midRange => 'Mid-range',
        PriceTier.luxury => 'Luxury',
      };
}

String _formatClock(int minutes) {
  final normalized = minutes % (24 * 60);
  final hour = normalized ~/ 60;
  final minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _pointKey(LatLng? point) {
  if (point == null) {
    return 'none';
  }
  return '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
}

List<Attraction> _buildBlindBoxLocations() {
  final verifiedPlaces = [
    const Attraction(
      name: 'Batu Caves',
      hours: '07:00 - 21:00',
      openMinute: 7 * 60,
      closeMinute: 21 * 60,
      baseCost: 12,
      stayMinutes: 75,
      suggestedDistanceKm: 16,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/batu_caves.jpg',
      color: Color(0xFFFFCE3D),
      location: LatLng(3.2379, 101.6840),
    ),
    const Attraction(
      name: 'National Mosque',
      hours: '09:00 - 17:30',
      openMinute: 9 * 60,
      closeMinute: 17 * 60 + 30,
      baseCost: 0,
      stayMinutes: 45,
      suggestedDistanceKm: 6,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/national_mosque.jpg',
      color: Color(0xFF38D9FF),
      location: LatLng(3.1412, 101.6915),
    ),
    const Attraction(
      name: 'Central Market',
      hours: '10:00 - 20:00',
      openMinute: 10 * 60,
      closeMinute: 20 * 60,
      baseCost: 35,
      stayMinutes: 70,
      suggestedDistanceKm: 5,
      priceTier: PriceTier.midRange,
      imageAsset: 'assets/attractions/central_market.jpg',
      color: Color(0xFF00E2A7),
      location: LatLng(3.1457, 101.6953),
    ),
    const Attraction(
      name: 'Merdeka Square',
      hours: 'Open 24 hours',
      openMinute: 0,
      closeMinute: 24 * 60,
      baseCost: 0,
      stayMinutes: 40,
      suggestedDistanceKm: 4,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/merdeka_square.jpg',
      color: Color(0xFF7C5CFF),
      location: LatLng(3.1478, 101.6937),
    ),
    const Attraction(
      name: 'Petronas Twin Towers',
      hours: '09:00 - 21:00',
      openMinute: 9 * 60,
      closeMinute: 21 * 60,
      baseCost: 98,
      stayMinutes: 90,
      suggestedDistanceKm: 7,
      priceTier: PriceTier.luxury,
      imageAsset: 'assets/attractions/petronas_twin_towers.jpg',
      color: Color(0xFF40A9FF),
      location: LatLng(3.1579, 101.7116),
    ),
    const Attraction(
      name: 'KLCC Park',
      hours: '10:00 - 22:00',
      openMinute: 10 * 60,
      closeMinute: 22 * 60,
      baseCost: 0,
      stayMinutes: 45,
      suggestedDistanceKm: 3,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/klcc_park.jpg',
      color: Color(0xFFFF7A59),
      location: LatLng(3.1555, 101.7153),
    ),
    const Attraction(
      name: 'Aquaria KLCC',
      hours: '10:00 - 20:00',
      openMinute: 10 * 60,
      closeMinute: 20 * 60,
      baseCost: 62,
      stayMinutes: 75,
      suggestedDistanceKm: 6,
      priceTier: PriceTier.luxury,
      imageAsset: 'assets/attractions/aquaria_klcc.jpg',
      color: Color(0xFF00A9CE),
      location: LatLng(3.1538, 101.7134),
    ),
    const Attraction(
      name: 'Perdana Botanical Garden',
      hours: '07:00 - 20:00',
      openMinute: 7 * 60,
      closeMinute: 20 * 60,
      baseCost: 0,
      stayMinutes: 70,
      suggestedDistanceKm: 8,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/perdana_botanical_garden.jpg',
      color: Color(0xFF3CCB7F),
      location: LatLng(3.1390, 101.6889),
    ),
    const Attraction(
      name: 'Thean Hou Temple',
      hours: '08:00 - 22:00',
      openMinute: 8 * 60,
      closeMinute: 22 * 60,
      baseCost: 0,
      stayMinutes: 55,
      suggestedDistanceKm: 9,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/thean_hou_temple.jpg',
      color: Color(0xFFFF7A59),
      location: LatLng(3.1219, 101.6870),
    ),
    const Attraction(
      name: 'Islamic Arts Museum Malaysia',
      hours: '09:30 - 18:00',
      openMinute: 9 * 60 + 30,
      closeMinute: 18 * 60,
      baseCost: 20,
      stayMinutes: 80,
      suggestedDistanceKm: 7,
      priceTier: PriceTier.midRange,
      imageAsset: 'assets/attractions/islamic_arts_museum.jpg',
      color: Color(0xFF38D9FF),
      location: LatLng(3.1418, 101.6897),
    ),
    const Attraction(
      name: 'KL Tower',
      hours: '09:00 - 22:00',
      openMinute: 9 * 60,
      closeMinute: 22 * 60,
      baseCost: 110,
      stayMinutes: 80,
      suggestedDistanceKm: 8,
      priceTier: PriceTier.luxury,
      imageAsset: 'assets/attractions/kl_tower.jpg',
      color: Color(0xFF40A9FF),
      location: LatLng(3.1528, 101.7037),
    ),
    const Attraction(
      name: 'Masjid Jamek',
      hours: '10:00 - 18:00',
      openMinute: 10 * 60,
      closeMinute: 18 * 60,
      baseCost: 0,
      stayMinutes: 40,
      suggestedDistanceKm: 4,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/jamek_mosque.jpg',
      color: Color(0xFF38D9FF),
      location: LatLng(3.1489, 101.6956),
    ),
    const Attraction(
      name: 'River of Life',
      hours: '07:00 - 23:00',
      openMinute: 7 * 60,
      closeMinute: 23 * 60,
      baseCost: 0,
      stayMinutes: 45,
      suggestedDistanceKm: 4,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/river_of_life.jpg',
      color: Color(0xFF40A9FF),
      location: LatLng(3.1483, 101.6965),
    ),
    const Attraction(
      name: 'Royal Selangor Visitor Centre',
      hours: '09:00 - 17:00',
      openMinute: 9 * 60,
      closeMinute: 17 * 60,
      baseCost: 80,
      stayMinutes: 85,
      suggestedDistanceKm: 12,
      priceTier: PriceTier.luxury,
      imageAsset: 'assets/attractions/royal_selangor.jpg',
      color: Color(0xFF8793A4),
      location: LatLng(3.1967, 101.7246),
    ),
    const Attraction(
      name: 'Muzium Negara',
      hours: '09:00 - 17:00',
      openMinute: 9 * 60,
      closeMinute: 17 * 60,
      baseCost: 5,
      stayMinutes: 60,
      suggestedDistanceKm: 7,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/museum_negara.jpg',
      color: Color(0xFF7C5CFF),
      location: LatLng(3.1379, 101.6870),
    ),
    const Attraction(
      name: 'Little India Brickfields',
      hours: '10:00 - 22:00',
      openMinute: 10 * 60,
      closeMinute: 22 * 60,
      baseCost: 25,
      stayMinutes: 65,
      suggestedDistanceKm: 8,
      priceTier: PriceTier.midRange,
      imageAsset: 'assets/attractions/little_india_brickfields.jpg',
      color: Color(0xFFFFCE3D),
      location: LatLng(3.1291, 101.6841),
    ),
    const Attraction(
      name: 'Jalan Alor',
      hours: '17:00 - 00:00',
      openMinute: 17 * 60,
      closeMinute: 24 * 60,
      baseCost: 45,
      stayMinutes: 75,
      suggestedDistanceKm: 6,
      priceTier: PriceTier.midRange,
      imageAsset: 'assets/attractions/jalan_alor.jpg',
      color: Color(0xFFFF7A59),
      location: LatLng(3.1466, 101.7088),
    ),
    const Attraction(
      name: 'Kwai Chai Hong',
      hours: '09:00 - 00:00',
      openMinute: 9 * 60,
      closeMinute: 24 * 60,
      baseCost: 25,
      stayMinutes: 55,
      suggestedDistanceKm: 5,
      priceTier: PriceTier.midRange,
      imageAsset: 'assets/attractions/kwai_chai_hong.jpg',
      color: Color(0xFF7C5CFF),
      location: LatLng(3.1415, 101.6979),
    ),
    const Attraction(
      name: 'REXKL',
      hours: '10:00 - 22:00',
      openMinute: 10 * 60,
      closeMinute: 22 * 60,
      baseCost: 40,
      stayMinutes: 70,
      suggestedDistanceKm: 5,
      priceTier: PriceTier.midRange,
      imageAsset: 'assets/attractions/rexkl.jpg',
      color: Color(0xFF00E2A7),
      location: LatLng(3.1420, 101.6992),
    ),
    const Attraction(
      name: 'Tugu Negara',
      hours: '07:00 - 18:00',
      openMinute: 7 * 60,
      closeMinute: 18 * 60,
      baseCost: 0,
      stayMinutes: 45,
      suggestedDistanceKm: 9,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/tugu_negara.jpg',
      color: Color(0xFF8793A4),
      location: LatLng(3.1490, 101.6839),
    ),
    const Attraction(
      name: 'Berjaya Times Square',
      hours: '10:00 - 22:00',
      openMinute: 10 * 60,
      closeMinute: 22 * 60,
      baseCost: 80,
      stayMinutes: 80,
      suggestedDistanceKm: 7,
      priceTier: PriceTier.luxury,
      imageAsset: 'assets/attractions/berjaya_times_square.jpg',
      color: Color(0xFFFFCE3D),
      location: LatLng(3.1426, 101.7106),
    ),
    const Attraction(
      name: 'Pavilion Kuala Lumpur',
      hours: '10:00 - 22:00',
      openMinute: 10 * 60,
      closeMinute: 22 * 60,
      baseCost: 120,
      stayMinutes: 90,
      suggestedDistanceKm: 6,
      priceTier: PriceTier.luxury,
      imageAsset: 'assets/attractions/pavilion_kl.jpg',
      color: Color(0xFF40A9FF),
      location: LatLng(3.1490, 101.7132),
    ),
    const Attraction(
      name: 'Titiwangsa Lake Gardens',
      hours: '06:00 - 22:00',
      openMinute: 6 * 60,
      closeMinute: 22 * 60,
      baseCost: 0,
      stayMinutes: 60,
      suggestedDistanceKm: 10,
      priceTier: PriceTier.budget,
      imageAsset: 'assets/attractions/titiwangsa_lake_gardens.jpg',
      color: Color(0xFF3CCB7F),
      location: LatLng(3.1781, 101.7044),
    ),
    const Attraction(
      name: 'Bank Negara Malaysia Museum',
      hours: '10:00 - 17:00',
      openMinute: 10 * 60,
      closeMinute: 17 * 60,
      baseCost: 10,
      stayMinutes: 70,
      suggestedDistanceKm: 8,
      priceTier: PriceTier.midRange,
      imageAsset: 'assets/attractions/bank_negara_museum.jpg',
      color: Color(0xFF7C5CFF),
      location: LatLng(3.1592, 101.6925),
    ),
  ];

  return List<Attraction>.generate(1000, (index) {
    final place = verifiedPlaces[index % verifiedPlaces.length];
    return Attraction(
      name: place.name,
      hours: place.hours,
      openMinute: place.openMinute,
      closeMinute: place.closeMinute,
      baseCost: place.baseCost,
      stayMinutes: place.stayMinutes,
      suggestedDistanceKm: place.suggestedDistanceKm,
      priceTier: place.priceTier,
      imageAsset: place.imageAsset,
      color: place.color,
      location: place.location,
    );
  });
}
