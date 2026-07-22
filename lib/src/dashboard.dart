part of '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.role,
    required this.email,
    required this.credit,
    required this.savedTransitRoutes,
    required this.hubPoolTransactions,
    required this.carbonSavedKg,
    required this.onLogout,
    super.key,
  });

  final UserRole role;
  final String email;
  final double credit;
  final int savedTransitRoutes;
  final int hubPoolTransactions;
  final double carbonSavedKg;
  final Future<void> Function(BuildContext context) onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  late double _wallet;
  late int _savedTransitRoutes;
  late int _hubPoolTransactions;
  late double _carbonSavedKg;
  String _transitDestination = 'KLCC';
  int _transitRequest = 0;
  String? _ongoingDestination;
  LatLng? _sharedCurrentLocation;
  double? _sharedCurrentAccuracyMeters;
  bool _centeringOnLocation = false;

  bool _hasCenteredOnInitialLocation = false;

  @override
  void initState() {
    super.initState();
    _wallet = widget.credit;
    _savedTransitRoutes = widget.savedTransitRoutes;
    _hubPoolTransactions = widget.hubPoolTransactions;
    _carbonSavedKg = widget.carbonSavedKg;
    globalMapController.addListener(_onMapControllerChanged);
  }

  @override
  void dispose() {
    globalMapController.removeListener(_onMapControllerChanged);
    super.dispose();
  }

  void _onMapControllerChanged() {
    if (mounted) setState(() {});
    if (globalMapController.value != null && !_hasCenteredOnInitialLocation) {
      _hasCenteredOnInitialLocation = true;
    }
  }

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
    setState(() {
      _wallet = max(0, _wallet - fare);
      _hubPoolTransactions++;
      _carbonSavedKg += max(0.1, fare * .18);
    });
    _persistProfileStats();
  }

  void _topUp(double amount) {
    setState(() => _wallet += amount);
    _persistProfileStats();
  }

  void _saveTransitRoute() {
    setState(() => _savedTransitRoutes++);
    _persistProfileStats();
  }

  void _persistProfileStats() {
    if (!SupabaseConfig.isReady) {
      return;
    }
    unawaited(
      const AuthService().updateStats(
        credit: _wallet,
        savedTransitRoutes: _savedTransitRoutes,
        hubPoolTransactions: _hubPoolTransactions,
        carbonSavedKg: _carbonSavedKg,
      ),
    );
  }

  void _updateMapView(SharedMapView view) {
    final incomingLocation = view.currentLocation;
    if (incomingLocation != null && view.currentAccuracyMeters != null) {
      _sharedCurrentLocation = incomingLocation;
      _sharedCurrentAccuracyMeters = view.currentAccuracyMeters;
    }
    if (globalMapViewNotifier.value.signature == view.signature) {
      return;
    }
    final oldPrefix = globalMapViewNotifier.value.signature.split('|').first;
    final newPrefix = view.signature.split('|').first;
    globalMapViewNotifier.value = view;
    final target = view.initialTarget;
    final zoom = view.initialZoom;
    if (globalMapController.value != null &&
        target != null &&
        zoom != null &&
        oldPrefix != newPrefix) {
      unawaited(globalMapController.value!.flyToLatLngZoom(target, zoom));
    }
  }

  Future<void> _centerSharedMapOnCurrentLocation() async {
    final controller = globalMapController.value;
    if (controller == null || _centeringOnLocation) {
      return;
    }
    setState(() => _centeringOnLocation = true);
    try {
      final location = await _readDeviceLocation();
      if (!mounted || location == null) {
        return;
      }
      _setSharedSelfLocation(location, 0);
      await controller.flyToLatLngZoom(location, 17.0);
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
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        unawaited(_refreshSharedLocation());
        return LatLng(last.latitude, last.longitude);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 4),
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

  Future<void> _refreshSharedLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (!mounted) {
        return;
      }
      _setSharedSelfLocation(
        LatLng(position.latitude, position.longitude),
        position.accuracy,
      );
    } catch (_) {}
  }

  void _setSharedSelfLocation(LatLng location, double? accuracyMeters) {
    setState(() {
      _sharedCurrentLocation = location;
      _sharedCurrentAccuracyMeters = accuracyMeters;
    });
    final current = globalMapViewNotifier.value;
    final baseSignature = current.signature.split('|self:').first;
    globalMapViewNotifier.value = SharedMapView(
      signature:
          '$baseSignature|self:${location.latitude.toStringAsFixed(5)},${location.longitude.toStringAsFixed(5)}',
      currentLocation: location,
      currentAccuracyMeters: accuracyMeters,
      candidate: current.candidate,
      selectedRoute: current.selectedRoute,
      navigating: current.navigating,
      vehicleLocation: current.vehicleLocation,
      vehicleColor: current.vehicleColor,
      initialTarget: current.initialTarget,
      initialZoom: current.initialZoom,
      extraMarkers: current.extraMarkers,
      extraPolylines: current.extraPolylines,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TransitRouterScreen(
        active: _tab == 0,
        mapController: globalMapController.value,
        onMapViewChanged: _updateMapView,
        destination: _transitDestination,
        request: _transitRequest,
        ongoingDestination: _ongoingDestination,
        onNavigationCancelled: () => setState(() => _ongoingDestination = null),
        onTransitRouteSaved: _saveTransitRoute,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
      ),
      HubPoolScreen(
        active: _tab == 1,
        mapController: globalMapController.value,
        onMapViewChanged: _updateMapView,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
        wallet: _wallet,
        onFareDeducted: _deductFare,
      ),
      PelancongPlanScreen(
        active: _tab == 2,
        mapController: globalMapController.value,
        onMapViewChanged: _updateMapView,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
        ongoingDestination: _ongoingDestination,
        onGoNow: _openTransitFor,
        onCancelDestination: _cancelDestination,
      ),
      ColoredBox(
        color: TrasiaColors.background,
        child: SafeArea(
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
                  email: widget.email,
                  wallet: _wallet,
                  savedTransitRoutes: _savedTransitRoutes,
                  hubPoolTransactions: _hubPoolTransactions,
                  carbonSavedKg: _carbonSavedKg,
                  onTopUp: _topUp,
                  onLogout: () => widget.onLogout(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: _tab == 3 ? TrasiaColors.background : Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: _tab == 3,
            child: ValueListenableBuilder<SharedMapView>(
              valueListenable: globalMapViewNotifier,
              builder: (context, view, _) {
                return LiveMapboxSurface(
                  apiKeyReady: _GoogleMapsConfig.isReady,
                  currentLocation: view.currentLocation,
                  currentAccuracyMeters: view.currentAccuracyMeters,
                  candidate: view.candidate,
                  selectedRoute: view.selectedRoute,
                  navigating: view.navigating,
                  vehicleLocation: view.vehicleLocation,
                  vehicleColor: view.vehicleColor,
                  initialTarget: view.initialTarget,
                  initialZoom: view.initialZoom,
                  extraMarkers: view.extraMarkers,
                  extraPolylines: view.extraPolylines,
                  onMapCreated: (controller) {
                    globalMapController.value = controller;
                  },
                  onCameraMove: () {
                    // Update last center if needed by active tabs
                  },
                );
              },
            ),
          ),
          IndexedStack(index: _tab, children: pages),
          if (_tab != 3)
            ValueListenableBuilder<SharedMapView>(
              valueListenable: globalMapViewNotifier,
              builder: (context, view, _) {
                final isPlanEmpty =
                    _tab == 2 && view.signature.startsWith('plan-empty');
                if (isPlanEmpty) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  right: 16,
                  bottom: 128,
                  child: _MapLocationButton(
                    loading: _centeringOnLocation,
                    onPressed: _centerSharedMapOnCurrentLocation,
                  ),
                );
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 48, right: 48, bottom: 24),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.map_rounded, 'Transit', 0),
                _buildNavItem(Icons.directions_car_rounded, 'Ride', 1),
                _buildNavItem(Icons.backpack_rounded, 'Plan', 2),
                _buildNavItem(Icons.grid_view_rounded, 'Account', 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _tab == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        height: 48,
        width: 64,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.onPrimary : TrasiaColors.darkIcon,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : TrasiaColors.darkIcon,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
