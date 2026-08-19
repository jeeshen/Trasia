part of '../main.dart';
class HubPoolScreen extends StatefulWidget {
  const HubPoolScreen({
    required this.active,
    required this.mapController,
    required this.onMapViewChanged,
    required this.currentLocation,
    required this.currentAccuracyMeters,
    required this.wallet,
    required this.onFareDeducted,
    required this.onRideCompleted,
    required this.demoArrivalRequest,
    required this.favoritePlaceNames,
    required this.onToggleFavorite,
    required this.requestedDestination,
    required this.request,
    super.key,
  });
  final bool active;
  final AppMapController? mapController;
  final ValueChanged<SharedMapView> onMapViewChanged;
  final LatLng? currentLocation;
  final double? currentAccuracyMeters;
  final double wallet;
  final ValueChanged<double> onFareDeducted;
  final void Function(DestinationCandidate?, double) onRideCompleted;
  final int demoArrivalRequest;
  final Set<String> favoritePlaceNames;
  final ValueChanged<DestinationCandidate> onToggleFavorite;
  final DestinationCandidate? requestedDestination;
  final int request;
  @override
  State<HubPoolScreen> createState() => _HubPoolScreenState();
}
class _HubPoolScreenState extends State<HubPoolScreen>
    with SingleTickerProviderStateMixin {
  final _destinationController = TextEditingController();
  AppMapController? _mapController;
  static const _maxApproachSeconds = 60;
  late final AnimationController _carController;
  Timer? _timer;
  Timer? _destinationRouteRefreshTimer;
  Timer? _destinationSearchDebounce;
  int _destinationSearchRequest = 0;
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
  int _mapRefreshRevision = 0;
  DateTime? _lastRideCameraUpdate;
  double? _rideChargeDistanceKm;
  LatLng? _hubCurrentLocation;
  double? _hubCurrentAccuracyMeters;
  LatLng? _bookedPickupLocation;
  double? _bookedPickupAccuracyMeters;
  LatLng? _snappedRideLocation;
  static const _origin = LatLng(3.1478, 101.6953);
  static const _originName = 'Current pickup point';
  LatLng get _pickupLocation =>
      _bookedPickupLocation ??
      _hubCurrentLocation ??
      widget.currentLocation ??
      _origin;
  LatLng get _rideCurrentLocation =>
      _hubCurrentLocation ?? widget.currentLocation ?? _pickupLocation;
  double? get _pickupAccuracyMeters =>
      _bookedPickupAccuracyMeters ??
      _hubCurrentAccuracyMeters ??
      widget.currentAccuracyMeters;
  @override
  void initState() {
    super.initState();
    _carController =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..addListener(() {
            if (mounted && _stage == RideStage.tracking) {
              setState(() {});
              _followRideCamera();
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
      _mapRefreshRevision++;
    }
    if (widget.active &&
        !oldWidget.active &&
        _stage == RideStage.idle &&
        _bookedPickupLocation == null) {
      unawaited(_loadPickupLocation(silent: true));
    }
    if (widget.active &&
        !oldWidget.active &&
        (_stage == RideStage.tracking || _stage == RideStage.onboard)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _followRideCamera(force: true);
      });
    }
    if (oldWidget.demoArrivalRequest != widget.demoArrivalRequest) {
      _completeDemoArrival();
    }
    if (oldWidget.request != widget.request &&
        widget.requestedDestination != null) {
      _useRequestedDestination(widget.requestedDestination!);
    }
  }
  void _useRequestedDestination(DestinationCandidate destination) {
    if (_stage == RideStage.matching ||
        _stage == RideStage.tracking ||
        _stage == RideStage.onboard) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Finish the current ride first.')),
      );
      return;
    }
    _timer?.cancel();
    _carController.reset();
    _stopRideLocationUpdates();
    setState(() {
      _destinationController.text = destination.name;
      _stage = RideStage.idle;
      _seconds = 0;
      _driver = null;
      _destination = destination;
      _destinationCandidates = [destination];
      _route = null;
      _approachAnimationPoints = const [];
      _snappedRideLocation = null;
      _rideChargeDistanceKm = null;
      _destinationStatusMessage = null;
      _fareDeducted = false;
      _bookedPickupLocation = null;
      _bookedPickupAccuracyMeters = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.active) {
        unawaited(_mapController?.flyToLatLngZoom(destination.location, 14.5));
      }
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    _destinationRouteRefreshTimer?.cancel();
    _destinationSearchDebounce?.cancel();
    _hubPositionSubscription?.cancel();
    _carController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
  Future<void> _loadPickupLocation({required bool silent}) async {
    if (_loadingPickupLocation || _bookedPickupLocation != null) {
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
          _bookedPickupLocation != null ||
          _stage != RideStage.idle ||
          !_isGreaterKlLocation(location) ||
          position.accuracy > 120) {
        return;
      }
      setState(() {
        _hubCurrentLocation = location;
        _hubCurrentAccuracyMeters = position.accuracy;
      });
    } catch (_) {
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
    _followRideCamera(force: true);
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
    if (!mounted) {
      return;
    }
    final destination = _destination;
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search and choose a destination first.')),
      );
      return;
    }
    final rideDistanceKm = _rideDistanceKm(destination.location);
    final pickupLocation = _pickupLocation;
    final pickupAccuracyMeters = _pickupAccuracyMeters;
    final fare = _fareForDistance(rideDistanceKm);
    if (widget.wallet < fare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient credit to book this ride.')),
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
      _bookedPickupLocation = pickupLocation;
      _bookedPickupAccuracyMeters = pickupAccuracyMeters;
      _rideChargeDistanceKm = rideDistanceKm;
      _route = null;
      _destinationStatusMessage = null;
      _fareDeducted = false;
      _snappedRideLocation = null;
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
    final index = DateTime.now().millisecond % TrasiaData.drivers.length;
    final driverProfile = TrasiaData.drivers[index];
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
            _bookedPickupLocation = null;
            _bookedPickupAccuracyMeters = null;
          });
          return;
        }
        final pickupRoadPoint = _route?.points.isNotEmpty ?? false
            ? _route!.points.last
            : _pickupLocation;
        final fare = _fareForDistance(_rideChargeDistanceKm ?? _rideDistanceKm(destination.location));
        if (!_fareDeducted && fare > 0) {
          widget.onFareDeducted(fare);
        }
        setState(() {
          _seconds = 0;
          _stage = RideStage.onboard;
          _snappedRideLocation = pickupRoadPoint;
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
      _driver = null;
      _approachAnimationPoints = const [];
      _snappedRideLocation = null;
      _rideChargeDistanceKm = null;
      _bookedPickupLocation = null;
      _bookedPickupAccuracyMeters = null;
    });
  }
  void _completeDemoArrival() {
    if (_stage != RideStage.matching &&
        _stage != RideStage.tracking &&
        _stage != RideStage.onboard) {
      return;
    }
    final destination = _destination;
    final distanceKm =
        _rideChargeDistanceKm ??
        (destination == null ? 0.0 : _rideDistanceKm(destination.location));
    final fare = _fareForDistance(distanceKm);
    _timer?.cancel();
    _destinationRouteRefreshTimer?.cancel();
    _carController.stop();
    _stopRideLocationUpdates();
    final shouldDeductFare = !_fareDeducted && fare > 0;
    setState(() {
      _stage = RideStage.idle;
      _seconds = 0;
      _destinationController.clear();
      _driver = null;
      _destination = null;
      _destinationCandidates = const [];
      _route = null;
      _approachAnimationPoints = const [];
      _snappedRideLocation = null;
      _fareDeducted = false;
      _rideChargeDistanceKm = null;
      _destinationStatusMessage = null;
      _bookedPickupLocation = null;
      _bookedPickupAccuracyMeters = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (shouldDeductFare) {
        widget.onFareDeducted(fare);
      }
      widget.onRideCompleted(destination, fare);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('${destination?.name ?? 'Destination'} reached.'),
        ),
      );
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
      final animationPoints = routePoints.isEmpty
          ? _approachAnimationPoints
          : routePoints;
      return animationPoints.isEmpty
          ? driver.startLocation
          : _pointAlongPath(animationPoints, _carController.value);
    }
    if (_stage == RideStage.onboard) {
      return _snappedRideLocation ?? _rideCurrentLocation;
    }
    return driver.startLocation;
  }
  double get _vehicleBearing {
    final points = _stage == RideStage.tracking
        ? (_route?.points.isNotEmpty ?? false)
              ? _route!.points
              : _approachAnimationPoints
        : _route?.points ?? const <LatLng>[];
    if (points.length < 2) {
      return 0;
    }
    final progress = _stage == RideStage.tracking ? _carController.value : 0.0;
    final segment = _pathSegmentAtProgress(points, progress);
    if (segment == null) {
      return 0;
    }
    final bearing = Geolocator.bearingBetween(
      segment.$1.latitude,
      segment.$1.longitude,
      segment.$2.latitude,
      segment.$2.longitude,
    );
    return bearing.isNaN ? 0 : bearing;
  }
  double get _selectedDistanceKm =>
      _destination == null ? 0 : _rideDistanceKm(_destination!.location);
  double get _selectedFare => _fareForDistance(_selectedDistanceKm);
  void _followRideCamera({bool force = false}) {
    if (!mounted ||
        !widget.active ||
        (_stage != RideStage.tracking && _stage != RideStage.onboard)) {
      return;
    }
    final controller = _mapController;
    final vehicleLocation = _vehicleLocation;
    if (controller == null || vehicleLocation == null) {
      return;
    }
    final now = DateTime.now();
    final lastUpdate = _lastRideCameraUpdate;
    if (!force &&
        lastUpdate != null &&
        now.difference(lastUpdate) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastRideCameraUpdate = now;
    unawaited(
      controller.easeToCameraPosition(
        CameraPosition(
          target: vehicleLocation,
          zoom: 17.5,
          tilt: 0,
          bearing: _vehicleBearing,
        ),
        durationMs: force ? 180 : 240,
      ),
    );
  }
  SharedMapView get _currentMapView {
    final resultsExpanded =
        _stage == RideStage.idle && _destinationCandidates.isNotEmpty;
    final routeProgress = _stage == RideStage.tracking
        ? _carController.value
        : null;
    return SharedMapView(
      signature:
          'hub|${_pointKey(_pickupLocation)}|${_destination?.placeId}|${_route?.label}|${_route?.time}|${_route?.distance}|${_route?.points.length}|$_stage|${_driver?.name}|${_pointKey(_vehicleLocation)}|progress:${routeProgress?.toStringAsFixed(3)}|results:${resultsExpanded ? 'expanded' : 'collapsed'}|${_destinationCandidates.length}',
      currentLocation: _pickupLocation,
      currentAccuracyMeters: _pickupAccuracyMeters,
      candidate: _stage == RideStage.tracking ? null : _destination,
      selectedRoute: _route,
      mapRefreshRevision: _mapRefreshRevision,
      navigating: _stage == RideStage.tracking || _stage == RideStage.onboard,
      vehicleLocation: _vehicleLocation,
      vehicleColor: _driver?.color,
      vehicleBearing: _vehicleBearing,
      routeProgress: routeProgress,
      showCurrentLocationMarker: _stage != RideStage.onboard,
      showRouteEndpoints:
          _stage != RideStage.tracking && _stage != RideStage.onboard,
      initialTarget: _destination?.location ?? _pickupLocation,
      initialZoom: _destination == null ? 13 : 14.5,
    );
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
    final durationSeconds = (distanceMeters / averageMetersPerSecond)
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
      fare: 'RM ${_fareForDistance(distanceKm).toStringAsFixed(2)}',
      transfers: 'Direct',
      crowd: .2,
      color: TrasiaColors.primary,
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
        fare: 'RM ${_fareForDistance(distanceKm).toStringAsFixed(2)}',
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
      setState(() {
        _route = drivingRoute;
        _rideChargeDistanceKm = max(_rideChargeDistanceKm ?? 0, distanceKm);
        if (route.points.isNotEmpty) {
          _snappedRideLocation = route.points.first;
        }
      });
      _publishMapView();
      await _fitRoute(drivingRoute.points);
    } catch (_) {
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
  (LatLng, LatLng)? _pathSegmentAtProgress(
    List<LatLng> points,
    double progress,
  ) {
    if (points.length < 2) {
      return null;
    }
    final segmentLengths = <double>[];
    var totalMeters = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = _distanceMeters(points[i], points[i + 1]);
      segmentLengths.add(length);
      totalMeters += length;
    }
    if (totalMeters == 0) {
      return null;
    }
    var remainingMeters = totalMeters * progress.clamp(0, 1).toDouble();
    for (var i = 0; i < segmentLengths.length; i++) {
      if (segmentLengths[i] <= .1) {
        continue;
      }
      if (remainingMeters > segmentLengths[i] &&
          i < segmentLengths.length - 1) {
        remainingMeters -= segmentLengths[i];
        continue;
      }
      return (points[i], points[i + 1]);
    }
    for (var i = segmentLengths.length - 1; i >= 0; i--) {
      if (segmentLengths[i] > .1) {
        return (points[i], points[i + 1]);
      }
    }
    return null;
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
    return max(.01, double.parse((km * .50).toStringAsFixed(2)));
  }
  Future<void> _fitRoute(List<LatLng> points) async {
    if (points.isEmpty || _mapController == null) {
      return;
    }
    final start = points.first;
    final nextPoint = points.length > 1 ? points[1] : start;
    double bearing = 0.0;
    if (start.latitude != nextPoint.latitude ||
        start.longitude != nextPoint.longitude) {
      bearing = Geolocator.bearingBetween(
        start.latitude,
        start.longitude,
        nextPoint.latitude,
        nextPoint.longitude,
      );
    }
    if (bearing.isNaN) {
      bearing = 0.0;
    }
    _mapController!.flyToCameraPosition(
      CameraPosition(target: start, zoom: 17.5, tilt: 0.0, bearing: bearing),
    );
  }
  void _handleDestinationTextChanged() {
    _destinationSearchDebounce?.cancel();
    final query = _destinationController.text.trim();
    _destinationSearchRequest++;
    setState(() {
      _destination = null;
      _destinationStatusMessage = null;
      _destinationCandidates = const [];
      _searchingDestination = false;
    });
    if (query.isEmpty) {
      return;
    }
    _destinationSearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_searchDestination()),
    );
  }
  Future<void> _searchDestination() async {
    _destinationSearchDebounce?.cancel();
    final query = _destinationController.text.trim();
    final request = ++_destinationSearchRequest;
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
      if (!mounted ||
          request != _destinationSearchRequest ||
          query != _destinationController.text.trim()) {
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
        await _mapController?.flyToLatLngZoom(destination.location, 14.5);
      }
    } catch (error) {
      if (!mounted || request != _destinationSearchRequest) {
        return;
      }
      setState(() {
        _destinationCandidates = const [];
        _destination = null;
        _destinationStatusMessage = 'Place search failed. Try again.';
      });
    } finally {
      if (mounted && request == _destinationSearchRequest) {
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
            favoritePlaceNames: widget.favoritePlaceNames,
            fareForDestination: (destination) =>
                _fareForDistance(_rideDistanceKm(destination.location)),
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
                _mapController?.flyToLatLngZoom(candidate.location, 14.5),
              );
            },
            onToggleFavorite: widget.onToggleFavorite,
            onBook: destination == null ? null : _bookRide,
            onCancel:
                _stage == RideStage.matching ||
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
    _destinationSearchDebounce?.cancel();
    _destinationSearchRequest++;
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
      _snappedRideLocation = null;
      _rideChargeDistanceKm = null;
      _destinationStatusMessage = null;
      _fareDeducted = false;
      _bookedPickupLocation = null;
      _bookedPickupAccuracyMeters = null;
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
    required this.favoritePlaceNames,
    required this.fareForDestination,
    required this.onTextChanged,
    required this.onClearInput,
    required this.onSearch,
    required this.onSelectDestination,
    required this.onToggleFavorite,
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
  final Set<String> favoritePlaceNames;
  final double Function(DestinationCandidate) fareForDestination;
  final VoidCallback onTextChanged;
  final VoidCallback onClearInput;
  final VoidCallback onSearch;
  final ValueChanged<DestinationCandidate> onSelectDestination;
  final ValueChanged<DestinationCandidate> onToggleFavorite;
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
      RideStage.idle =>
        selectedDestination == null
            ? 'Search any destination'
            : '${distanceKm.toStringAsFixed(1)} km / RM ${fare.toStringAsFixed(2)}',
      RideStage.matching => 'Confirmed. Matching in $seconds sec',
      RideStage.tracking => 'Arrives in $seconds sec',
      RideStage.onboard =>
        '${driver?.vehicle ?? 'Vehicle'} to ${selectedDestination?.name ?? 'destination'}',
      RideStage.completed => 'Fare deducted',
      RideStage.cancelled => 'You can book again',
    };
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: TrasiaColors.primary,
                  child: const Icon(
                    Icons.local_taxi_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
          ),
          const SizedBox(height: 8),
          if (stage == RideStage.idle || stage == RideStage.cancelled) ...[
            TextField(
              key: const Key('feature-b-destination'),
              controller: controller,
              onChanged: (_) => onTextChanged(),
              onSubmitted: (_) => onSearch(),
              style: const TextStyle(color: Color(0xFF172033)),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                hintText: 'Search destination',
                hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchingDestination
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: TrasiaLoadingCompass(
                          size: 18,
                          semanticLabel: 'Searching destinations',
                        ),
                      )
                    : controller.text.trim().isEmpty
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
            if (statusMessage != null || destinations.isNotEmpty)
              const SizedBox(height: 10),
            if (statusMessage != null) ...[
              _SheetNotice(message: statusMessage!),
              const SizedBox(height: 10),
            ],
            if (destinations.isNotEmpty) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: min(MediaQuery.sizeOf(context).height * 0.52, 420),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: destinations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final destination = destinations[index];
                    return _HubDestinationTile(
                      destination: destination,
                      selected:
                          destination.placeId == selectedDestination?.placeId,
                      favorite: favoritePlaceNames.contains(
                        destination.name.toLowerCase(),
                      ),
                      fare: fareForDestination(destination),
                      onTap: () => onSelectDestination(destination),
                      onToggleFavorite: () => onToggleFavorite(destination),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('book-ride'),
                  onPressed: onBook,
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.black,
                  ),
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
                color: TrasiaColors.primary,
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
                child: FilledButton.icon(
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
    required this.favorite,
    required this.fare,
    required this.onTap,
    required this.onToggleFavorite,
  });
  final DestinationCandidate destination;
  final bool selected;
  final bool favorite;
  final double fare;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
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
            color: selected ? TrasiaColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_rounded, color: TrasiaColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'RM ${fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(
                  width: 34,
                  height: 32,
                  child: IconButton(
                    tooltip: favorite
                        ? 'Remove from Favorites'
                        : 'Save to Favorites',
                    padding: EdgeInsets.zero,
                    onPressed: onToggleFavorite,
                    color: favorite
                        ? const Color(0xFFE04470)
                        : TrasiaColors.primary,
                    iconSize: 20,
                    icon: Icon(
                      favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
