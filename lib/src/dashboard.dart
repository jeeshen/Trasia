part of '../main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.profile,
    required this.onLogout,
    super.key,
  });

  final AuthProfile profile;
  final Future<void> Function(BuildContext context) onLogout;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  
  int _tab = 0;
  int _previousTab = 0;
  late double _wallet;
  late int _savedTransitRoutes;
  late int _hubPoolTransactions;
  late double _carbonSavedKg;
  int _rewardPoints = 600;
  List<RedeemedVoucher> _redeemedVouchers = const [];
  Map<String, CheckedInPlace> _checkedInPlaces = const {};
  String _transitDestination = 'KLCC';
  int _transitRequest = 0;
  DestinationCandidate? _hubPoolRequestedDestination;
  int _hubPoolRequest = 0;
  BlindBoxTravelMode? _transitRequestedMode;
  String? _ongoingDestination;
  LatLng? _sharedCurrentLocation;
  double? _sharedCurrentAccuracyMeters;
  bool _centeringOnLocation = false;
  bool _mapFocusOnCurrentLocation = false;
  List<FavoritePlace> _favoritePlaces = const [];
  List<TripHistoryEntry> _tripHistory = const [];
  int _transitDemoArrivalRequest = 0;
  int _hubPoolDemoArrivalRequest = 0;
  int _planDemoArrivalRequest = 0;
  String? _username;
  late AuthProfile _currentProfile;

  bool _hasCenteredOnInitialLocation = false;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
    _username = _currentProfile.username;
    _wallet = _currentProfile.credit;
    _savedTransitRoutes = _currentProfile.savedTransitRoutes;
    _hubPoolTransactions = _currentProfile.hubPoolTransactions;
    _carbonSavedKg = _currentProfile.carbonSavedKg;
    _rewardPoints = _currentProfile.rewardPoints;
    _redeemedVouchers = _currentProfile.redeemedVouchers;
    _checkedInPlaces = _currentProfile.checkedInPlaces;
    _favoritePlaces = _currentProfile.favoritePlaces;
    _tripHistory = _currentProfile.tripHistory;
    
    globalMapController.addListener(_onMapControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadInitialLocation());
      }
    });
  }

  @override
  void dispose() {
    globalMapController.removeListener(_onMapControllerChanged);
    super.dispose();
  }

  Future<void> _refreshProfile() async {
    final updated = await const AuthService().currentProfile();
    if (updated != null && mounted) {
      setState(() {
        _currentProfile = updated;
        _username = updated.username;
        _wallet = updated.credit;
        _savedTransitRoutes = updated.savedTransitRoutes;
        _hubPoolTransactions = updated.hubPoolTransactions;
        _carbonSavedKg = updated.carbonSavedKg;
        _rewardPoints = updated.rewardPoints;
        _redeemedVouchers = updated.redeemedVouchers;
        _checkedInPlaces = updated.checkedInPlaces;
        _favoritePlaces = updated.favoritePlaces;
        _tripHistory = updated.tripHistory;
      });
    }
  }

  void _onMapControllerChanged() {
    if (mounted) setState(() {});
    final controller = globalMapController.value;
    final location =
        _sharedCurrentLocation ?? globalMapViewNotifier.value.currentLocation;
    if (controller != null &&
        location != null &&
        !_hasCenteredOnInitialLocation) {
      _hasCenteredOnInitialLocation = true;
      unawaited(controller.flyToLatLngZoom(location, 17.0));
    }
  }

  void _openTransitFor(String destination, BlindBoxTravelMode? travelMode) {
    setState(() {
      _transitDestination = destination;
      _transitRequest++;
      _transitRequestedMode = travelMode;
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
    });
    _saveProfile();
  }

  void _topUp(double amount) {
    setState(() => _wallet += amount);
    _saveProfile();
  }

  bool _redeemReward(String voucherId, int pointCost, double hubPoolCredit) {
    if (_rewardPoints < pointCost) {
      return false;
    }
    setState(() {
      _rewardPoints -= pointCost;
      _wallet += hubPoolCredit;
      if (voucherId == 'kfc-5') {
        _redeemedVouchers = [
          RedeemedVoucher(
            id: 'kfc-5-${DateTime.now().millisecondsSinceEpoch}',
            title: 'RM5 KFC Voucher',
            description: 'Show this demo code to KFC staff for RM5 off.',
            code: 'TRASIA-KFC-RM5',
            redeemedAt: DateTime.now(),
          ),
          ..._redeemedVouchers,
        ];
      }
    });
    
    _saveProfile();
    _saveProfile();
    return true;
  }

  bool _checkInPlace(String placeName) {
    final placeKey = _placeCheckInKey(placeName);
    if (_checkedInPlaces.containsKey(placeKey)) {
      return false;
    }
    setState(() {
      _checkedInPlaces = {
        ..._checkedInPlaces,
        placeKey: CheckedInPlace(
          placeKey: placeKey,
          checkedInAt: DateTime.now(),
        ),
      };
      _rewardPoints += 50;
    });
    _saveProfile();
    
    return true;
  }

  void _markVoucherUsed(String voucherId) {
    final index = _redeemedVouchers.indexWhere(
      (voucher) => voucher.id == voucherId,
    );
    if (index < 0 || _redeemedVouchers[index].usedAt != null) {
      return;
    }
    setState(() {
      _redeemedVouchers = [
        for (var i = 0; i < _redeemedVouchers.length; i++)
          if (i == index)
            _redeemedVouchers[i].copyWith(usedAt: DateTime.now())
          else
            _redeemedVouchers[i],
      ];
    });
    _saveProfile();
  }

  void _saveTransitRoute(DestinationCandidate? destination) {
    setState(() {
      _savedTransitRoutes++;
      _addTripHistory(
        placeName: destination?.name ?? _transitDestination,
        category: 'Transit',
        detail: '',
      );
    });
    _saveProfile();
    _saveProfile();
  }

  Future<void> _saveDemoPlanCompletion(List<ItineraryStop> stops) async {
    setState(() {
      _savedTransitRoutes++;
      _ongoingDestination = null;
      for (final stop in stops) {
        _addTripHistory(
          placeName: stop.attraction.name,
          category: 'Plan',
          detail:
              '${_formatClock(stop.startMinute)} - ${_formatClock(stop.endMinute)}',
        );
      }
    });
    _saveProfile();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Plan trip saved to History')),
    );
  }

  void _saveRideCompletion(DestinationCandidate? destination, double fare) {
    setState(() {
      _addTripHistory(
        placeName: destination?.name ?? 'Hub-Pool ride',
        category: 'Ride',
        detail: '',
        amountPaid: fare,
      );
    });
    _saveProfile();
  }

  void _completeDemoArrival() {
    setState(() {
      switch (_tab) {
        case 0:
          _transitDemoArrivalRequest++;
        case 1:
          _hubPoolDemoArrivalRequest++;
        case 3:
          _planDemoArrivalRequest++;
      }
    });
  }

  void _revisitHistoryEntry(TripHistoryEntry entry) {
    final travelMode = entry.category == 'Ride'
        ? BlindBoxTravelMode.drive
        : BlindBoxTravelMode.transit;
    _openTransitFor(entry.placeName, travelMode);
  }

  void _revisitFavoritePlace(FavoritePlace place) {
    final sourceTab = _tab == 4 ? _previousTab : _tab;
    if (sourceTab == 1) {
      final destination = DestinationCandidate(
        name: place.name,
        address: place.address,
        location: place.location,
        placeId: 'favorite-${place.key}',
      );
      setState(() {
        _previousTab = _tab;
        _hubPoolRequestedDestination = destination;
        _hubPoolRequest++;
        _tab = 1;
      });
      return;
    }
    _openTransitFor(place.name, null);
  }

  

  

  

  

  

  

  

  

  

  

  

  void _addTripHistory({
    required String placeName,
    required String category,
    required String detail,
    double? amountPaid,
  }) {
    final trimmedName = placeName.trim().isEmpty ? 'Destination' : placeName;
    _tripHistory = [
      TripHistoryEntry(
        placeName: trimmedName,
        category: category,
        detail: detail,
        amountPaid: amountPaid,
        completedAt: DateTime.now(),
      ),
      ..._tripHistory,
    ].take(50).toList();
  }

  

  void _toggleFavoritePlace(Attraction attraction) {
    final place = FavoritePlace.fromAttraction(attraction);
    _toggleFavorite(place);
  }

  void _toggleFavoriteDestination(DestinationCandidate destination) {
    final place = FavoritePlace.fromDestinationCandidate(destination);
    _toggleFavorite(place);
  }

  void _toggleFavorite(FavoritePlace place) {
    final exists = _favoritePlaces.any((favorite) => favorite.key == place.key);
    setState(() {
      _favoritePlaces = exists
          ? [
              for (final favorite in _favoritePlaces)
                if (favorite.key != place.key) favorite,
            ]
          : [place, ..._favoritePlaces];
    });
    _saveProfile();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          exists
              ? '${place.name} removed from Favorites'
              : '${place.name} saved to Favorites',
        ),
      ),
    );
  }

  void _removeFavoritePlace(FavoritePlace place) {
    setState(() {
      _favoritePlaces = [
        for (final favorite in _favoritePlaces)
          if (favorite.key != place.key) favorite,
      ];
    });
    _saveProfile();
  }

  void _showMapFavorites() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .42,
        maxChildSize: .92,
        builder: (context, scrollController) => _FavoritesSheet(
          places: _favoritePlaces,
          scrollController: scrollController,
          onRemove: _removeFavoritePlace,
          onRevisit: _revisitFavoritePlace,
        ),
      ),
    );
  }

  void _saveProfile() {
    if (!SupabaseConfig.isReady) return;
    final updatedProfile = widget.profile.copyWith(
      credit: _wallet,
      savedTransitRoutes: _savedTransitRoutes,
      hubPoolTransactions: _hubPoolTransactions,
      carbonSavedKg: _carbonSavedKg,
      rewardPoints: _rewardPoints,
      redeemedVouchers: _redeemedVouchers,
      checkedInPlaces: _checkedInPlaces,
      favoritePlaces: _favoritePlaces,
      tripHistory: _tripHistory,
    );
    unawaited(const AuthService().updateProfile(updatedProfile));
  }

  void _updateMapView(SharedMapView view) {
    final incomingLocation = view.currentLocation;
    if (incomingLocation != null) {
      _sharedCurrentLocation = incomingLocation;
      _sharedCurrentAccuracyMeters = view.currentAccuracyMeters;
    }
    final effectiveView = _mapViewWithSharedSelfLocation(view);
    if (globalMapViewNotifier.value.signature == effectiveView.signature) {
      return;
    }
    final previousView = globalMapViewNotifier.value;
    final oldPrefix = previousView.signature.split('|').first;
    final newPrefix = effectiveView.signature.split('|').first;
    if (oldPrefix != newPrefix ||
        previousView.candidate?.placeId != effectiveView.candidate?.placeId ||
        previousView.focusDestination != effectiveView.focusDestination) {
      _mapFocusOnCurrentLocation = false;
    }
    globalMapViewNotifier.value = effectiveView;
    final target = effectiveView.vehicleLocation ?? effectiveView.initialTarget;
    final zoom = effectiveView.vehicleLocation != null
        ? 17.5
        : effectiveView.initialZoom;
    if (globalMapController.value != null &&
        target != null &&
        zoom != null &&
        oldPrefix != newPrefix) {
      unawaited(globalMapController.value!.flyToLatLngZoom(target, zoom));
    }
  }

  SharedMapView _mapViewWithSharedSelfLocation(SharedMapView view) {
    final location = view.currentLocation ?? _sharedCurrentLocation;
    if (location == null) {
      return view;
    }
    final accuracy = view.currentAccuracyMeters ?? _sharedCurrentAccuracyMeters;
    final baseSignature = view.signature.split('|self:').first;
    return SharedMapView(
      signature:
          '$baseSignature|self:${location.latitude.toStringAsFixed(5)},${location.longitude.toStringAsFixed(5)}',
      currentLocation: location,
      currentAccuracyMeters: accuracy,
      candidate: view.candidate,
      focusDestination: view.focusDestination,
      selectedRoute: view.selectedRoute,
      mapRefreshRevision: view.mapRefreshRevision,
      navigating: view.navigating,
      vehicleLocation: view.vehicleLocation,
      vehicleColor: view.vehicleColor,
      vehicleBearing: view.vehicleBearing,
      routeProgress: view.routeProgress,
      showCurrentLocationMarker: view.showCurrentLocationMarker,
      showRouteEndpoints: view.showRouteEndpoints,
      initialTarget: view.initialTarget,
      initialZoom: view.initialZoom,
      extraMarkers: view.extraMarkers,
      extraPolylines: view.extraPolylines,
    );
  }

  Future<void> _centerSharedMapOnCurrentLocation() async {
    final controller = globalMapController.value;
    if (controller == null || _centeringOnLocation) {
      return;
    }
    setState(() => _centeringOnLocation = true);
    try {
      final view = globalMapViewNotifier.value;
      final routePoints = view.selectedRoute?.points ?? const <LatLng>[];
      final destination =
          view.focusDestination ??
          view.candidate?.location ??
          (routePoints.isEmpty ? null : routePoints.last);
      if (destination != null && _mapFocusOnCurrentLocation) {
        await controller.flyToLatLngZoom(destination, 14.5);
        _mapFocusOnCurrentLocation = false;
        return;
      }
      final location = await _readDeviceLocation();
      if (!mounted || location == null) {
        return;
      }
      _setSharedSelfLocation(location, 0);
      await controller.flyToLatLngZoom(location, 17.0);
      _mapFocusOnCurrentLocation = destination != null;
    } finally {
      if (mounted) {
        setState(() => _centeringOnLocation = false);
      }
    }
  }

  Future<void> _loadInitialLocation() async {
    if (_centeringOnLocation) {
      return;
    }
    _centeringOnLocation = true;
    try {
      final location = await _readDeviceLocation();
      if (!mounted || location == null) {
        return;
      }
      _setSharedSelfLocation(location, 0, centerMap: true);
    } finally {
      _centeringOnLocation = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<LatLng?> _readDeviceLocation() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        await _showLocationSettingsDialog();
      }
      return null;
    }
    if (permission == LocationPermission.denied) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Allow location while using the app to continue.'),
        ),
      );
      return null;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      messenger?.showSnackBar(
        SnackBar(
          content: const Text('Turn on location services first.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: Geolocator.openLocationSettings,
          ),
        ),
      );
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
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

  Future<void> _showLocationSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Location permission needed'),
        content: const Text(
          'Location access is blocked. Open Android settings and allow '
          'location while using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(Geolocator.openAppSettings());
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  void _setSharedSelfLocation(
    LatLng location,
    double? accuracyMeters, {
    bool centerMap = false,
  }) {
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
      focusDestination: current.focusDestination,
      selectedRoute: current.selectedRoute,
      mapRefreshRevision: current.mapRefreshRevision,
      navigating: current.navigating,
      vehicleLocation: current.vehicleLocation,
      vehicleColor: current.vehicleColor,
      vehicleBearing: current.vehicleBearing,
      routeProgress: current.routeProgress,
      showCurrentLocationMarker: current.showCurrentLocationMarker,
      showRouteEndpoints: current.showRouteEndpoints,
      initialTarget: centerMap ? location : current.initialTarget,
      initialZoom: centerMap ? 17.0 : current.initialZoom,
      extraMarkers: current.extraMarkers,
      extraPolylines: current.extraPolylines,
    );
    final controller = globalMapController.value;
    if (centerMap && controller != null) {
      _hasCenteredOnInitialLocation = true;
      unawaited(controller.flyToLatLngZoom(location, 17.0));
    }
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
        requestedMode: _transitRequestedMode,
        ongoingDestination: _ongoingDestination,
        onNavigationCancelled: () => setState(() {
          _ongoingDestination = null;
          _transitRequestedMode = null;
        }),
        onTransitRouteSaved: _saveTransitRoute,
        demoArrivalRequest: _transitDemoArrivalRequest,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
        favoritePlaceNames: {for (final place in _favoritePlaces) place.key},
        onToggleFavorite: _toggleFavoriteDestination,
      ),
      HubPoolScreen(
        active: _tab == 1,
        mapController: globalMapController.value,
        onMapViewChanged: _updateMapView,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
        wallet: _wallet,
        onFareDeducted: _deductFare,
        onRideCompleted: _saveRideCompletion,
        demoArrivalRequest: _hubPoolDemoArrivalRequest,
        favoritePlaceNames: {for (final place in _favoritePlaces) place.key},
        onToggleFavorite: _toggleFavoriteDestination,
        requestedDestination: _hubPoolRequestedDestination,
        request: _hubPoolRequest,
      ),
      _DashboardOverviewPage(active: _tab == 2),
      PelancongPlanScreen(
        active: _tab == 3,
        mapController: globalMapController.value,
        onMapViewChanged: _updateMapView,
        currentLocation: _sharedCurrentLocation,
        currentAccuracyMeters: _sharedCurrentAccuracyMeters,
        ongoingDestination: _ongoingDestination,
        favoritePlaceNames: {for (final place in _favoritePlaces) place.key},
        onToggleFavorite: _toggleFavoritePlace,
        demoArrivalRequest: _planDemoArrivalRequest,
        onDemoArrivalCompleted: _saveDemoPlanCompletion,
        onGoNow: _openTransitFor,
        onCancelDestination: _cancelDestination,
        rewardPoints: _rewardPoints,
        onRedeemReward: _redeemReward,
        checkedInPlaces: _checkedInPlaces,
        onCheckInPlace: _checkInPlace,
      ),
      ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: AccountConsoleScreen(
            role: _currentProfile.role,
            username: _username,
            onUsernameChanged: (_) => _refreshProfile(),
            email: _currentProfile.email,
            wallet: _wallet,
            savedTransitRoutes: _savedTransitRoutes,
            hubPoolTransactions: _hubPoolTransactions,
            carbonSavedKg: _carbonSavedKg,
            favoritePlaces: _favoritePlaces,
            tripHistory: _tripHistory,
            vouchers: _redeemedVouchers,
            onVoucherUsed: _markVoucherUsed,
            onTopUp: _topUp,
            onRemoveFavorite: _removeFavoritePlace,
            onRevisitFavorite: _revisitFavoritePlace,
            onRevisitHistory: _revisitHistoryEntry,
            onLogout: () => widget.onLogout(context),
          ),
        ),
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: _tab == 2 || _tab == 4
          ? Colors.white
          : Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: _tab == 2 || _tab == 4,
            child: ValueListenableBuilder<SharedMapView>(
              valueListenable: globalMapViewNotifier,
              builder: (context, view, _) {
                return LiveMapboxSurface(
                  apiKeyReady: _GoogleMapsConfig.isReady,
                  currentLocation: view.currentLocation,
                  currentAccuracyMeters: view.currentAccuracyMeters,
                  candidate: view.candidate,
                  selectedRoute: view.selectedRoute,
                  mapRefreshRevision: view.mapRefreshRevision,
                  navigating: view.navigating,
                  vehicleLocation: view.vehicleLocation,
                  vehicleColor: view.vehicleColor,
                  vehicleBearing: view.vehicleBearing,
                  routeProgress: view.routeProgress,
                  showCurrentLocationMarker: view.showCurrentLocationMarker,
                  showRouteEndpoints: view.showRouteEndpoints,
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
          if (_tab == 0 || _tab == 1 || _tab == 3)
            _buildMapControls(behindExpandedResults: true),
          IndexedStack(
            key: const ValueKey('dashboard-pages'),
            index: _tab,
            children: pages,
          ),
          if (_tab != 2 && _tab != 4) _buildMapControls(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 2),
                _buildNavItem(Icons.backpack_rounded, 'Plan', 3),
                _buildNavItem(Icons.grid_view_rounded, 'Account', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls({bool behindExpandedResults = false}) {
    return ValueListenableBuilder<SharedMapView>(
      valueListenable: globalMapViewNotifier,
      builder: (context, view, _) {
        if (_tab == 0 || _tab == 1 || _tab == 3) {
          final resultsExpanded = view.signature.contains('results:expanded');
          if (behindExpandedResults != resultsExpanded) {
            return const SizedBox.shrink();
          }
        } else if (behindExpandedResults) {
          return const SizedBox.shrink();
        }
        final isPlanEmpty =
            _tab == 3 && view.signature.startsWith('plan-empty');
        if (isPlanEmpty) {
          return const SizedBox.shrink();
        }
        final showDemoArrival =
            view.navigating ||
            (_tab == 1 &&
                (view.signature.contains('RideStage.matching') ||
                    view.signature.contains('RideStage.tracking') ||
                    view.signature.contains('RideStage.onboard'))) ||
            (_tab == 3 &&
                view.signature.startsWith('plan|') &&
                !view.signature.contains('trip:completed'));
        return Positioned(
          right: 16,
          bottom: 128,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDemoArrival) ...[
                _DemoArrivalButton(onPressed: _completeDemoArrival),
                const SizedBox(height: 12),
              ] else ...[
                _MapFavoritesButton(onPressed: _showMapFavorites),
                const SizedBox(height: 12),
              ],
              _MapLocationButton(
                loading: _centeringOnLocation,
                onPressed: _centerSharedMapOnCurrentLocation,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _tab == index;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isSelected,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            key: Key('nav-${label.toLowerCase()}'),
            onTap: () => setState(() {
              _previousTab = _tab;
              _tab = index;
            }),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : TrasiaColors.darkIcon,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardOverviewPage extends StatefulWidget {
  const _DashboardOverviewPage({required this.active});

  final bool active;

  @override
  State<_DashboardOverviewPage> createState() => _DashboardOverviewPageState();
}

class _DashboardOverviewPageState extends State<_DashboardOverviewPage> {
  static const _sourceUrls = [
    'https://data.gov.my/data-catalogue/fuelprice',
    'https://data.gov.my/dashboard/rapid-explorer',
    'https://data.gov.my/dashboard/public-transportation',
    'https://data.gov.my/dashboard/ktmb-explorer',
  ];

  final Map<int, Map<String, dynamic>> _sourceData = {};
  int _section = 0;
  bool _loading = true;
  bool _comparisonLoading = false;
  String? _error;
  String? _rapidOrigin;
  String? _rapidDestination;
  String _ktmbService = 'ets';
  String? _ktmbOrigin;
  String? _ktmbDestination;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      unawaited(_loadGovernmentData());
    }
  }

  @override
  void didUpdateWidget(covariant _DashboardOverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _sourceData.isEmpty) {
      unawaited(_loadGovernmentData());
    }
  }

  Future<Map<String, dynamic>> _fetchPageData(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Government data returned ${response.statusCode}');
    }
    final match = RegExp(
      '<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(response.body);
    if (match == null) {
      throw const FormatException('Official data was not found on the page.');
    }
    final root = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    final props = root['props'] as Map<String, dynamic>?;
    final pageProps = props?['pageProps'] as Map<String, dynamic>?;
    if (pageProps == null) {
      throw const FormatException('Official data format is unavailable.');
    }
    return pageProps;
  }

  Future<void> _loadGovernmentData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        for (final url in _sourceUrls) _fetchPageData(Uri.parse(url)),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _sourceData
          ..clear()
          ..addEntries([
            for (var i = 0; i < results.length; i++) MapEntry(i, results[i]),
          ]);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Unable to load the latest government data.';
      });
    }
  }

  Future<void> _loadRapidComparison() async {
    final origin = _rapidOrigin;
    final destination = _rapidDestination;
    if (origin == null || destination == null) {
      return;
    }
    await _loadComparison(
      index: 1,
      uri: Uri(
        scheme: 'https',
        host: 'data.gov.my',
        pathSegments: [
          'dashboard',
          'rapid-explorer',
          'rail',
          origin,
          destination,
        ],
      ),
    );
  }

  Future<void> _loadKtmbComparison() async {
    final origin = _ktmbOrigin;
    final destination = _ktmbDestination;
    if (origin == null || destination == null) {
      return;
    }
    await _loadComparison(
      index: 3,
      uri: Uri(
        scheme: 'https',
        host: 'data.gov.my',
        pathSegments: [
          'dashboard',
          'ktmb-explorer',
          _ktmbService,
          origin,
          destination,
        ],
      ),
    );
  }

  Future<void> _loadComparison({required int index, required Uri uri}) async {
    setState(() => _comparisonLoading = true);
    try {
      final data = await _fetchPageData(uri);
      if (mounted) {
        setState(() => _sourceData[index] = data);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Unable to load this government comparison.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _comparisonLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TrasiaColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        snackBarTheme: _trasiaSnackBarTheme,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Government Data',
                          style: TextStyle(
                            color: Color(0xFF102033),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Live insights from data.gov.my',
                          style: TextStyle(
                            color: Color(0xFF68788C),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh government data',
                    onPressed: _loading ? null : _loadGovernmentData,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _AnimatedSegmentedBar(
                tabs: const ['Fuel', 'Rapid', 'Public', 'KTMB'],
                selectedIndex: _section,
                onChanged: (index) {
                  setState(() => _section = index);
                },
              ),
              const SizedBox(height: 18),
              if (_loading)
                const _GovernmentLoading()
              else if (_error != null)
                _GovernmentError(message: _error!, onRetry: _loadGovernmentData)
              else
                switch (_section) {
                  0 => _buildFuelData(),
                  1 => _buildRapidData(),
                  2 => _buildPublicTransportData(),
                  _ => _buildKtmbData(),
                },
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuelData() {
    final page = _sourceData[0]!;
    final rows =
        (page['data'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .where((row) => row['series_type'] == 'level')
            .toList()
          ..sort(
            (a, b) => (a['date'] as String? ?? '').compareTo(
              b['date'] as String? ?? '',
            ),
          );
    if (rows.isEmpty) {
      return const _GovernmentEmpty();
    }
    final latest = rows.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GovernmentSectionHeader(
          icon: Icons.local_gas_station_rounded,
          title: 'Malaysia Fuel Prices',
          description: page['description'] as String? ?? '',
          updated: page['data_as_of'] as String?,
        ),
        const SizedBox(height: 14),
        _FuelPriceGrid(latest: latest),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.directions_transit_rounded,
                color: TrasiaColors.primary,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Use Trasia Transit to plan public transport journeys and spend less on fuel.',
                  style: TextStyle(
                    color: Color(0xFF23405F),
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GovernmentSourceNote(
          url: _sourceUrls[0],
          updated: page['last_updated'] as String?,
        ),
      ],
    );
  }

  Widget _buildRapidData() {
    final page = _sourceData[1]!;
    final dropdown =
        (page['dropdown'] as Map<String, dynamic>?)?['rail']
            as Map<String, dynamic>? ??
        const {};
    final origins = dropdown.keys.toList();
    final destinations = _rapidOrigin == null
        ? const <String>[]
        : (dropdown[_rapidOrigin] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GovernmentSectionHeader(
          icon: Icons.train_rounded,
          title: 'Rapid Rail Explorer',
          description:
              'Compare official ridership between two Rapid Rail stations.',
          updated: page['last_updated'] as String?,
        ),
        const SizedBox(height: 14),
        _GovernmentDropdown(
          label: 'Origin station',
          value: _rapidOrigin,
          options: origins,
          onChanged: (value) {
            setState(() {
              _rapidOrigin = value;
              _rapidDestination = null;
            });
          },
        ),
        const SizedBox(height: 10),
        _GovernmentDropdown(
          label: 'Destination station',
          value: _rapidDestination,
          options: destinations,
          onChanged: (value) {
            setState(() => _rapidDestination = value);
            unawaited(_loadRapidComparison());
          },
        ),
        const SizedBox(height: 16),
        _comparisonResult(page, _rapidOrigin, _rapidDestination),
        const SizedBox(height: 14),
        _GovernmentSourceNote(
          url: _sourceUrls[1],
          updated: page['last_updated'] as String?,
        ),
      ],
    );
  }

  Widget _buildPublicTransportData() {
    final page = _sourceData[2]!;
    final callout =
        (page['timeseries_callout'] as Map<String, dynamic>?)?['data']
            as Map<String, dynamic>? ??
        const {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GovernmentSectionHeader(
          icon: Icons.directions_bus_rounded,
          title: 'Public Transportation',
          description:
              'Compare the latest official ridership across Malaysia\'s public transport services.',
          updated:
              (page['timeseries_callout']
                      as Map<String, dynamic>?)?['data_as_of']
                  as String?,
        ),
        const SizedBox(height: 14),
        for (final metric in const [
          ('overall', 'All public transport', Color(0xFF0B7CFF)),
          ('rail', 'Rail', Color(0xFF005BD8)),
          ('bus', 'Bus', Color(0xFF6BB8FF)),
        ]) ...[
          _PublicTransportMetric(
            label: metric.$2,
            color: metric.$3,
            data: callout[metric.$1] as Map<String, dynamic>?,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        _GovernmentSourceNote(
          url: _sourceUrls[2],
          updated: page['last_updated'] as String?,
        ),
      ],
    );
  }

  Widget _buildKtmbData() {
    final page = _sourceData[3]!;
    final dropdown = page['dropdown'] as Map<String, dynamic>? ?? const {};
    final services = dropdown.keys.toList();
    final stationMap =
        dropdown[_ktmbService] as Map<String, dynamic>? ?? const {};
    final origins = stationMap.keys.toList();
    final destinations = _ktmbOrigin == null
        ? const <String>[]
        : (stationMap[_ktmbOrigin] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GovernmentSectionHeader(
          icon: Icons.directions_railway_rounded,
          title: 'KTMB Explorer',
          description:
              'Compare official KTMB ridership between services and stations.',
          updated: page['last_updated'] as String?,
        ),
        const SizedBox(height: 14),
        _GovernmentDropdown(
          label: 'Service',
          value: services.contains(_ktmbService) ? _ktmbService : null,
          options: services,
          displayLabel: _ktmbServiceLabel,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _ktmbService = value;
              _ktmbOrigin = null;
              _ktmbDestination = null;
            });
          },
        ),
        const SizedBox(height: 10),
        _GovernmentDropdown(
          label: 'Origin station',
          value: _ktmbOrigin,
          options: origins,
          onChanged: (value) {
            setState(() {
              _ktmbOrigin = value;
              _ktmbDestination = null;
            });
          },
        ),
        const SizedBox(height: 10),
        _GovernmentDropdown(
          label: 'Destination station',
          value: _ktmbDestination,
          options: destinations,
          onChanged: (value) {
            setState(() => _ktmbDestination = value);
            unawaited(_loadKtmbComparison());
          },
        ),
        const SizedBox(height: 16),
        _comparisonResult(page, _ktmbOrigin, _ktmbDestination),
        const SizedBox(height: 14),
        _GovernmentSourceNote(
          url: _sourceUrls[3],
          updated: page['last_updated'] as String?,
        ),
      ],
    );
  }

  Widget _comparisonResult(
    Map<String, dynamic> page,
    String? origin,
    String? destination,
  ) {
    if (origin == null || destination == null) {
      return const _GovernmentSelectionPrompt();
    }
    if (_comparisonLoading) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(20), child: _MapLoadingPill()),
      );
    }
    final forward = page['A_to_B_callout'] as Map<String, dynamic>?;
    final reverse = page['B_to_A_callout'] as Map<String, dynamic>?;
    if (forward == null || reverse == null) {
      return const _GovernmentEmpty();
    }
    return _RidershipComparison(
      origin: origin,
      destination: destination,
      forwardDaily: (forward['daily'] as num?)?.toDouble() ?? 0,
      reverseDaily: (reverse['daily'] as num?)?.toDouble() ?? 0,
      forwardMonthly: (forward['monthly'] as num?)?.toDouble() ?? 0,
      reverseMonthly: (reverse['monthly'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _GovernmentLoading extends StatelessWidget {
  const _GovernmentLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          _MapLoadingPill(),
          SizedBox(height: 14),
          Text(
            'Loading official government data...',
            style: TextStyle(color: Color(0xFF68788C)),
          ),
        ],
      ),
    );
  }
}

class _GovernmentError extends StatelessWidget {
  const _GovernmentError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 42,
            color: Color(0xFF68788C),
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _GovernmentEmpty extends StatelessWidget {
  const _GovernmentEmpty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        'No official data is available for this selection.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF68788C)),
      ),
    );
  }
}

class _GovernmentSelectionPrompt extends StatelessWidget {
  const _GovernmentSelectionPrompt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF5)),
      ),
      child: const Text(
        'Choose an origin and destination to compare official ridership.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF68788C), height: 1.35),
      ),
    );
  }
}

class _GovernmentSectionHeader extends StatelessWidget {
  const _GovernmentSectionHeader({
    required this.icon,
    required this.title,
    required this.description,
    this.updated,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? updated;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: TrasiaColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF102033),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: const TextStyle(
            color: Color(0xFF536477),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        if (updated != null) ...[
          const SizedBox(height: 7),
          Text(
            'Data as of ${updated!}',
            style: const TextStyle(
              color: Color(0xFF8A98AA),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _FuelPriceGrid extends StatelessWidget {
  const _FuelPriceGrid({required this.latest});

  final Map<String, dynamic> latest;

  @override
  Widget build(BuildContext context) {
    final prices = [
      ('RON95', latest['ron95']),
      ('RON97', latest['ron97']),
      ('Diesel', latest['diesel']),
      ('East MY Diesel', latest['diesel_eastmsia']),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.7,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (final price in prices)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE1EAF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  price.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF68788C),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  price.$2 is num
                      ? 'RM ${(price.$2 as num).toStringAsFixed(2)}/L'
                      : 'Unavailable',
                  style: const TextStyle(
                    color: Color(0xFF102033),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GovernmentDropdown extends StatelessWidget {
  const _GovernmentDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.displayLabel,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final String Function(String)? displayLabel;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(
              displayLabel?.call(option) ?? option,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: options.isEmpty ? null : onChanged,
    );
  }
}

class _RidershipComparison extends StatelessWidget {
  const _RidershipComparison({
    required this.origin,
    required this.destination,
    required this.forwardDaily,
    required this.reverseDaily,
    required this.forwardMonthly,
    required this.reverseMonthly,
  });

  final String origin;
  final String destination;
  final double forwardDaily;
  final double reverseDaily;
  final double forwardMonthly;
  final double reverseMonthly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ridership comparison',
            style: TextStyle(
              color: Color(0xFF102033),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _ComparisonBar(
            label: '$origin to $destination',
            value: forwardDaily,
            maxValue: max(forwardDaily, reverseDaily),
            color: const Color(0xFF0B7CFF),
            suffix: 'daily',
          ),
          const SizedBox(height: 13),
          _ComparisonBar(
            label: '$destination to $origin',
            value: reverseDaily,
            maxValue: max(forwardDaily, reverseDaily),
            color: const Color(0xFF005BD8),
            suffix: 'daily',
          ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: _MonthlyRidership(
                  label: 'A to B monthly',
                  value: forwardMonthly,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MonthlyRidership(
                  label: 'B to A monthly',
                  value: reverseMonthly,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
    required this.suffix,
  });

  final String label;
  final double value;
  final double maxValue;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue <= 0
        ? 0.0
        : (value / maxValue).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF536477),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_formatDashboardNumber(value)} $suffix',
              style: const TextStyle(
                color: Color(0xFF102033),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 9,
            backgroundColor: const Color(0xFFE1EAF5),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MonthlyRidership extends StatelessWidget {
  const _MonthlyRidership({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF68788C), fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          _formatDashboardNumber(value),
          style: const TextStyle(
            color: Color(0xFF102033),
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _PublicTransportMetric extends StatelessWidget {
  const _PublicTransportMetric({
    required this.label,
    required this.color,
    required this.data,
  });

  final String label;
  final Color color;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final daily =
        ((data?['daily'] as Map<String, dynamic>?)?['value'] as num?)
            ?.toDouble() ??
        0;
    final growth =
        ((data?['growth_mom'] as Map<String, dynamic>?)?['value'] as num?)
            ?.toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF5)),
      ),
      child: Row(
        children: [
          Container(width: 5, height: 46, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF536477),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDashboardNumber(daily)} daily riders',
                  style: const TextStyle(
                    color: Color(0xFF102033),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (growth != null)
            Text(
              '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(1)}%',
              style: TextStyle(
                color: growth >= 0
                    ? const Color(0xFF008A5A)
                    : const Color(0xFFC03545),
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _GovernmentSourceNote extends StatelessWidget {
  const _GovernmentSourceNote({required this.url, this.updated});

  final String url;
  final String? updated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: TrasiaColors.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Official source: $url'
              '${updated == null ? '' : '\nLast updated: $updated'}',
              style: const TextStyle(
                color: Color(0xFF536477),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDashboardNumber(double value) {
  final rounded = value.round().toString();
  return rounded.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

String _ktmbServiceLabel(String service) {
  return switch (service) {
    'ets' => 'ETS',
    'intercity' => 'Intercity',
    'komuter' => 'KTM Komuter',
    'komuter_utara' => 'KTM Komuter Utara',
    'tebrau' => 'Shuttle Tebrau',
    _ => service,
  };
}

class _AnimatedSegmentedBar extends StatelessWidget {
  const _AnimatedSegmentedBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF), // Light blue background
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              -1.0 + (selectedIndex / (tabs.length > 1 ? tabs.length - 1 : 1)) * 2.0,
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1.0 / tabs.length,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B7CFF), // Primary blue active pill
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B7CFF).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(tabs.length, (index) {
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(index),
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF0B7CFF),
                      ),
                      child: Text(tabs[index]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
