part of '../main.dart';

class TransitRouterScreen extends StatefulWidget {
  const TransitRouterScreen({
    required this.active,
    required this.mapController,
    required this.onMapViewChanged,
    required this.destination,
    required this.request,
    required this.requestedMode,
    required this.ongoingDestination,
    required this.onNavigationCancelled,
    required this.onTransitRouteSaved,
    this.currentLocation,
    this.currentAccuracyMeters,
    super.key,
  });

  final bool active;
  final AppMapController? mapController;
  final ValueChanged<SharedMapView> onMapViewChanged;
  final String destination;
  final int request;
  final BlindBoxTravelMode? requestedMode;
  final String? ongoingDestination;
  final VoidCallback onNavigationCancelled;
  final VoidCallback onTransitRouteSaved;
  final LatLng? currentLocation;
  final double? currentAccuracyMeters;

  @override
  State<TransitRouterScreen> createState() => _TransitRouterScreenState();
}

class _TransitRouterScreenState extends State<TransitRouterScreen> {
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  AppMapController? _mapController;
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
        'transit|${_pointKey(widget.currentLocation)}|${widget.currentAccuracyMeters?.round()}|${_candidate?.placeId}|${_selectedRoute?.label}|$_navigating|${_routes.length}',
    currentLocation: widget.currentLocation,
    currentAccuracyMeters: widget.currentAccuracyMeters,
    candidate: _candidate,
    selectedRoute: _selectedRoute,
    navigating: _navigating,
    initialTarget: widget.currentLocation ?? _lastMapCenter,
    initialZoom: widget.currentLocation == null ? 12 : 15,
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

        if (_loading)
          const Align(alignment: Alignment.center, child: _MapLoadingPill()),
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
    widget.onNavigationCancelled();
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
      if (widget.currentLocation == null) {
        setState(() {
          _statusMessage =
              'Location not available. Tap the location button on the map first.';
          _loading = false;
        });
        return;
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
        await _mapController?.flyToLatLngZoom(candidates.first.location, 14.5);
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
    setState(() {
      _candidate = destination;
      _routes = const [];
      _selectedRoute = null;
      _navigating = false;
    });
    await _mapController?.flyToLatLngZoom(_routingOrigin, 15);

    setState(() {
      _loading = true;
      _statusMessage = null;
    });
    final transitRoutes = _multimodalTransitRoutes(destination);
    final roadAlignedTransitRoutesFuture = transitRoutes.isEmpty
        ? Future<List<TransitOption>>.value(transitRoutes)
        : _roadAlignAccessTransitRoutes(transitRoutes);
    final drivingOptionFuture = _buildDrivingOption(destination);
    final roadAlignedTransitRoutes = await roadAlignedTransitRoutesFuture;
    final drivingOption = await drivingOptionFuture;
    final liveRoutes = _filterRoutesForRequestedMode([
      ...roadAlignedTransitRoutes,
      drivingOption,
    ]);
    if (!_hasGoogleMapsKey) {
      final routes = liveRoutes.isEmpty
          ? _filterRoutesForRequestedMode(_previewRoutes(destination))
          : liveRoutes;
      setState(() {
        _routes = routes;
        _selectedRoute = null;
        _statusMessage = _usingFallbackDeparture
            ? 'Device GPS looks unreliable, so planning starts from the Kuala Lumpur map area until a precise current location is available.'
            : 'Preview routes shown. Connect Google Maps API for real travel time and path interpolation.';
        _loading = false;
      });
      return;
    }
    try {
      final routes = liveRoutes;
      setState(() {
        _routes = routes;
        _selectedRoute = null;
      });
      if (routes.isNotEmpty) {
        await _mapController?.flyToLatLngZoom(_routingOrigin, 15);
      } else {
        setState(() => _statusMessage = 'No travel options found.');
      }
    } catch (error) {
      if (_isGoogleRoutesUnavailable(error)) {
        final routes = liveRoutes.isEmpty
            ? _filterRoutesForRequestedMode(_previewRoutes(destination))
            : liveRoutes;
        setState(() {
          _routes = routes;
          _selectedRoute = null;
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

  List<TransitOption> _filterRoutesForRequestedMode(
    List<TransitOption> routes,
  ) {
    return switch (widget.requestedMode) {
      BlindBoxTravelMode.drive =>
        routes.where((route) => route.label == 'Drive').toList(),
      BlindBoxTravelMode.transit =>
        routes
            .where((route) => route.label != 'Drive' && route.label != 'Walk')
            .toList(),
      null => routes,
    };
  }

  Future<TransitOption> _buildDrivingOption(
    DestinationCandidate destination,
  ) async {
    try {
      final route = await _GoogleMapsApi.fetchDrivingRoute(
        origin: _routingOrigin,
        destination: destination.location,
        apiKey: _GoogleMapsConfig.apiKey,
      );
      return TransitOption(
        label: 'Drive',
        chain: 'Drive directly to ${destination.name}',
        time: route.time,
        distance: route.distance,
        fare: 'Fuel varies',
        transfers: 'Direct',
        crowd: .18,
        color: TrasiaColors.primary,
        legs: [
          _leg(
            _routingOriginName,
            destination.name,
            'Drive',
            route.time,
            route.distance,
            Icons.directions_car_rounded,
            route.points,
          ),
        ],
        firstLegPointCount: route.points.length,
        firstStopLabel: destination.name,
        nextInstruction: 'Drive toward ${destination.name}',
      );
    } catch (_) {
      final distanceMeters = _metersBetween(
        _routingOrigin,
        destination.location,
      );
      final estimatedMinutes = max(4, (distanceMeters / 400).round());
      return TransitOption(
        label: 'Drive',
        chain: 'Drive directly to ${destination.name}',
        time: _formatLegMinutes(estimatedMinutes),
        distance: _formatLegDistance(distanceMeters),
        fare: 'Fuel varies',
        transfers: 'Direct',
        crowd: .18,
        color: TrasiaColors.primary,
        legs: [
          _leg(
            _routingOriginName,
            destination.name,
            'Drive',
            _formatLegMinutes(estimatedMinutes),
            _formatLegDistance(distanceMeters),
            Icons.directions_car_rounded,
            const [],
          ),
        ],
        firstStopLabel: destination.name,
        nextInstruction: 'Road directions will update when service returns',
      );
    }
  }

  void _startPlannedRoute(TransitOption route) {
    widget.onTransitRouteSaved();
    final departure =
        route.legs.isNotEmpty && route.legs.first.points.isNotEmpty
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
    final firstLeg = route.legs.isEmpty
        ? route.points
        : route.legs.first.points;
    if (firstLeg.isEmpty || _mapController == null) {
      return;
    }
    final start = firstLeg.first;
    final nextPoint = firstLeg.length > 1
        ? firstLeg[1]
        : (route.points.length > 1 ? route.points[1] : start);

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
    if (widget.currentLocation != null && _mapController != null) {
      _mapController!.flyToCameraPosition(
        CameraPosition(
          target: widget.currentLocation!,
          zoom: 15.0,
          tilt: 0.0,
          bearing: 0.0,
        ),
      );
    }
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
        final score =
            best +
            variant.costFor(
              edge.copyWith(transferPenalty: transferPenalty > 0),
            );
        if (score < (distances[edge.toId] ?? double.infinity)) {
          distances[edge.toId] = score;
          previous[edge.toId] = edge.copyWith(
            transferPenalty: transferPenalty > 0,
          );
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
    final lastWalkMeters = _metersBetween(
      endStop.location,
      destination.location,
    );
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
          firstLegPointCount: alignedLegs.isEmpty
              ? 2
              : max(2, alignedLegs.first.points.length),
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
    final target =
        destinationLocation != null && _isGreaterKlLocation(destinationLocation)
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
    ];
  }

  LatLng get _routingOrigin {
    final location = widget.currentLocation;
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
    final location = widget.currentLocation;
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
    final location = widget.currentLocation;
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
