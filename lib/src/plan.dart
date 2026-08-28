part of '../main.dart';

class PelancongPlanScreen extends StatefulWidget {
  const PelancongPlanScreen({
    required this.active,
    required this.mapController,
    required this.onMapViewChanged,
    required this.currentLocation,
    required this.currentAccuracyMeters,
    required this.ongoingDestination,
    required this.favoritePlaceNames,
    required this.onToggleFavorite,
    required this.demoArrivalRequest,
    required this.onDemoArrivalCompleted,
    required this.onGoNow,
    required this.onCancelDestination,
    required this.rewardPoints,
    required this.onRedeemReward,
    required this.checkedInPlaces,
    required this.onCheckInPlace,
    super.key,
  });
  final bool active;
  final AppMapController? mapController;
  final ValueChanged<SharedMapView> onMapViewChanged;
  final LatLng? currentLocation;
  final double? currentAccuracyMeters;
  final String? ongoingDestination;
  final Set<String> favoritePlaceNames;
  final ValueChanged<Attraction> onToggleFavorite;
  final int demoArrivalRequest;
  final Future<void> Function(List<ItineraryStop>) onDemoArrivalCompleted;
  final void Function(String destination, BlindBoxTravelMode travelMode)
  onGoNow;
  final ValueChanged<String> onCancelDestination;
  final int rewardPoints;
  final Future<bool> Function(
    String voucherId,
    int pointCost,
    double hubPoolCredit,
  )
  onRedeemReward;
  final Map<String, CheckedInPlace> checkedInPlaces;
  final Future<bool> Function(String placeName) onCheckInPlace;
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
  AppMapController? _mapController;
  final Map<String, BitmapDescriptor> _featureCMarkerIcons = {};
  List<LatLng> _featureCRoutePoints = const [];
  int _markerIconRevision = 0;
  int _routeRevision = 0;
  FeatureCTripStatus _tripStatus = FeatureCTripStatus.notStarted;
  int _activeStopIndex = 0;
  int _tripTotalStops = 0;
  int _completedStopCount = 0;
  final Set<String> _completedStopNames = <String>{};
  bool _completionInProgress = false;
  late final List<Attraction> _blindBoxLocations = TrasiaData.attractions;
  PriceTier get _priceTier => PriceTier.values[_priceIndex.round()];
  void _openRewards() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RewardsPage(
          initialPoints: widget.rewardPoints,
          onRedeem: widget.onRedeemReward,
        ),
      ),
    );
  }

  void _openCheckInMemories() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => CheckInMemoriesPage(
          checkedInPlaces: widget.checkedInPlaces,
          allPlaces: _blindBoxLocations,
        ),
      ),
    );
  }

  Future<void> _openCheckInScanner(ItineraryStop stop) async {
    if (widget.checkedInPlaces.containsKey(
      _placeCheckInKey(stop.attraction.name),
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${stop.attraction.name} already checked in')),
      );
      return;
    }
    final targetPayload = _checkInPayloadForPlaceName(stop.attraction.name);
    final scannedPayload = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => _CheckInScannerPage(
          targetName: stop.attraction.name,
          targetPayload: targetPayload,
        ),
      ),
    );
    if (!mounted || scannedPayload == null) {
      return;
    }
    if (scannedPayload != targetPayload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is not the QR for this place.')),
      );
      return;
    }
    try {
      final earned = await widget.onCheckInPlace(stop.attraction.name);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            earned
                ? '${stop.attraction.name} checked in. +50 points'
                : '${stop.attraction.name} already checked in',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save check-in.')),
        );
      }
    }
  }

  @override
  void didUpdateWidget(covariant PelancongPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _mapController = widget.mapController ?? _mapController;
    if (widget.active &&
        (!oldWidget.active ||
            oldWidget.mapController != widget.mapController) &&
        _itinerary.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) {
          unawaited(_fitItineraryMap());
        }
      });
    }
    if (_itinerary.isNotEmpty &&
        _pointKey(oldWidget.currentLocation) !=
            _pointKey(widget.currentLocation)) {
      unawaited(_loadFeatureCDrivingRoute());
    }
    if (oldWidget.demoArrivalRequest != widget.demoArrivalRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _completeDemoArrival();
        }
      });
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
      _completedStopNames.clear();
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
      _completedStopNames.remove(stop.attraction.name);
      _itinerary = [
        for (final item in _itinerary)
          if (item != stop) item,
      ];
      _tripTotalStops = max(0, _tripTotalStops - 1);
      _completedStopCount = _completedStopNames.length;
      if (_itinerary.isEmpty) {
        _itineraryListVisible = false;
        _tripStatus = FeatureCTripStatus.notStarted;
        _activeStopIndex = 0;
        _tripTotalStops = 0;
        _completedStopCount = 0;
        _completedStopNames.clear();
      } else if (_completedStopCount == _itinerary.length) {
        _tripStatus = FeatureCTripStatus.completed;
        _activeStopIndex = 0;
        _featureCRoutePoints = const [];
        _routeRevision++;
      } else if (removedIndex >= 0 && removedIndex < _activeStopIndex) {
        _activeStopIndex--;
      } else if (_activeStopIndex >= _itinerary.length) {
        _activeStopIndex = _itinerary.length - 1;
      }
    });
    unawaited(_loadFeatureCDrivingRoute());
  }

  Future<void> _focusItineraryStop(ItineraryStop stop) async {
    await _mapController?.flyToLatLngZoom(stop.attraction.location, 16);
  }

  ItineraryStop? get _activeTripStop {
    final pendingStops = _itinerary
        .where((stop) => !_completedStopNames.contains(stop.attraction.name))
        .toList();
    if (pendingStops.isEmpty ||
        _activeStopIndex < 0 ||
        _activeStopIndex >= pendingStops.length) {
      return null;
    }
    return pendingStops[_activeStopIndex];
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
    var tripCompleted = false;
    setState(() {
      _completedStopNames.add(stop.attraction.name);
      _itinerary = [
        for (final item in _itinerary)
          if (!_completedStopNames.contains(item.attraction.name)) item,
        for (final item in _itinerary)
          if (_completedStopNames.contains(item.attraction.name)) item,
      ];
      _completedStopCount = _completedStopNames.length;
      final pendingCount = _itinerary.length - _completedStopCount;
      if (pendingCount == 0) {
        _tripStatus = FeatureCTripStatus.completed;
        _activeStopIndex = 0;
        _featureCRoutePoints = const [];
        _routeRevision++;
        tripCompleted = true;
        return;
      }
      _activeStopIndex = 0;
      _tripStatus = FeatureCTripStatus.traveling;
      _routeRevision++;
    });
    if (tripCompleted) {
      unawaited(_completeFeatureCTrip());
      return;
    }
    unawaited(_loadFeatureCDrivingRoute());
    unawaited(_focusActiveTripStop());
  }

  void _goToNextFeatureCStop() {
    final pendingCount = _itinerary
        .where((stop) => !_completedStopNames.contains(stop.attraction.name))
        .length;
    if (pendingCount == 0) {
      unawaited(_completeFeatureCTrip());
      return;
    }
    if (_activeStopIndex >= pendingCount - 1) {
      unawaited(_completeFeatureCTrip());
      return;
    }
    setState(() {
      _activeStopIndex++;
      _tripStatus = FeatureCTripStatus.traveling;
    });
    unawaited(_focusActiveTripStop());
  }

  void _finishFeatureCTrip() {
    unawaited(_completeFeatureCTrip());
  }

  void _completeDemoArrival() {
    if (_itinerary.isEmpty) {
      return;
    }
    setState(() {
      _completedStopNames
        ..clear()
        ..addAll(_itinerary.map((stop) => stop.attraction.name));
      _completedStopCount = _itinerary.length;
      _activeStopIndex = 0;
      _tripStatus = FeatureCTripStatus.completed;
      _featureCRoutePoints = const [];
      _routeRevision++;
    });
    unawaited(_completeFeatureCTrip());
  }

  Future<void> _completeFeatureCTrip() async {
    if (_itinerary.isEmpty || _completionInProgress) {
      return;
    }
    final completedItinerary = List<ItineraryStop>.of(_itinerary);
    _completionInProgress = true;
    if (_tripStatus != FeatureCTripStatus.completed) {
      setState(() => _tripStatus = FeatureCTripStatus.completed);
    }
    for (final stop in completedItinerary) {
      widget.onCancelDestination(stop.attraction.name);
    }
    if (mounted) {
      _resetFeatureCPlanner();
    }
    try {
      await widget.onDemoArrivalCompleted(completedItinerary);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Unable to save this trip. Please try again.'),
          ),
        );
      }
      return;
    }
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
      _completedStopNames.clear();
      _completionInProgress = false;
      _routeRevision++;
    });
  }

  Future<void> _focusActiveTripStop() async {
    final stop = _activeTripStop;
    if (stop == null) {
      return;
    }
    await _mapController?.flyToLatLngZoom(stop.attraction.location, 15.5);
  }

  Future<void> _showMapStopAction(ItineraryStop stop) async {
    final canGo = identical(stop, _activeTripStop);
    final checkedIn = widget.checkedInPlaces.containsKey(
      _placeCheckInKey(stop.attraction.name),
    );
    final action = await showModalBottomSheet<_MapStopAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) =>
          _MapStopActionSheet(stop: stop, canGo: canGo, checkedIn: checkedIn),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _MapStopAction.proceed:
        if (canGo) {
          setState(() {
            _tripStatus = FeatureCTripStatus.traveling;
            _itineraryListVisible = true;
          });
          unawaited(_focusActiveTripStop());
        }
        break;
      case _MapStopAction.checkIn:
        _openCheckInScanner(stop);
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
      await controller.flyToLatLngZoom(
        _itinerary.first.attraction.location,
        14.5,
      );
      return;
    }
    await controller.flyToBounds(
      LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      ),
      88.0,
    );
  }

  SharedMapView get _currentMapView {
    if (_itinerary.isEmpty) {
      return SharedMapView(
        signature: 'plan-empty|${_pointKey(widget.currentLocation)}',
        currentLocation: widget.currentLocation,
        currentAccuracyMeters: widget.currentAccuracyMeters,
        initialTarget: widget.currentLocation ?? const LatLng(3.1478, 101.6953),
        initialZoom: widget.currentLocation == null ? 12 : 15,
      );
    }
    return SharedMapView(
      signature:
          'plan|${_pointKey(widget.currentLocation)}|mode:${_travelMode.name}|trip:${_tripStatus.name}:$_activeStopIndex|results:${_itineraryListVisible ? 'expanded' : 'collapsed'}|icons:$_markerIconRevision|route:$_routeRevision|${_itinerary.map((stop) => '${stop.order}:${stop.attraction.name}').join('|')}',
      currentLocation: widget.currentLocation,
      currentAccuracyMeters: widget.currentAccuracyMeters,
      focusDestination:
          _tripStatus == FeatureCTripStatus.traveling ||
              _tripStatus == FeatureCTripStatus.arrived
          ? _activeTripStop?.attraction.location
          : null,
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
    final pendingStops = _itinerary
        .where((stop) => !_completedStopNames.contains(stop.attraction.name))
        .toList();
    if (pendingStops.isEmpty) {
      if (mounted) {
        setState(() {
          _featureCRoutePoints = const [];
          _routeRevision++;
        });
      }
      return;
    }
    if (!_GoogleMapsConfig.isReady) {
      return;
    }
    final routeTargets = [
      if (widget.currentLocation != null) widget.currentLocation!,
      for (final stop in pendingStops) stop.attraction.location,
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
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  Future<ui.Image> _loadFeatureCMarkerImage(String source) async {
    final bytes = await AppImageService.loadBytes(source);
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 108,
      targetHeight: 108,
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
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
          icon:
              _featureCMarkerIcons[_featureCMarkerKey(stop)] ??
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
          color: TrasiaColors.primary,
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
    if (color == const Color(0xFF00E2A7) || color == const Color(0xFF3CCB7F)) {
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
              : attraction.suggestedDistanceKm *
                    totalDistanceKm /
                    distanceTotal;
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
    final planTheme = TrasiaTheme.light;
    if (_itinerary.isNotEmpty || _tripStatus == FeatureCTripStatus.completed) {
      return Theme(
        data: planTheme,
        child: Stack(
          key: const Key('feature-c-results-map'),
          fit: StackFit.expand,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                child: Column(
                  children: [
                    const _PlanSectionTitle(
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
                            () =>
                                _itineraryListVisible = !_itineraryListVisible,
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
                favoritePlaceNames: widget.favoritePlaceNames,
                ongoingDestination: widget.ongoingDestination,
                tripStatus: _tripStatus,
                activeStopIndex: _activeStopIndex,
                tripTotalStops: _tripTotalStops,
                completedStopCount: _completedStopCount,
                completedStopNames: _completedStopNames,
                checkedInPlaceKeys: widget.checkedInPlaces.keys.toSet(),
                onClose: () => setState(() => _itineraryListVisible = false),
                onCancel: _confirmCancel,
                onFocusStop: _focusItineraryStop,
                onToggleFavorite: widget.onToggleFavorite,
                onChooseRoute: (destination) =>
                    widget.onGoNow(destination, _travelMode),
                onStartTrip: _startFeatureCTrip,
                onArrived: _markActiveStopArrived,
                onNextPlace: _goToNextFeatureCStop,
                onFinishTrip: _finishFeatureCTrip,
                onCheckIn: _openCheckInScanner,
              ),
          ],
        ),
      );
    }
    return Theme(
      data: planTheme,
      child: ColoredBox(
        color: const Color(0xFFF7FAFE),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            18,
            MediaQuery.paddingOf(context).top + 8,
            18,
            160,
          ),
          children: [
            const _PlanSectionTitle(
              icon: Icons.explore_rounded,
              title: 'KL Blind Box',
              trailing: '150 places',
            ),
            _PlanPanel(
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
            const SizedBox(height: 14),
            _PlanPanel(
              child: Row(
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    color: TrasiaColors.primary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose attraction count, distance, and pricing, then open a blind box from 150 KL locations.',
                      style: TextStyle(color: Color(0xFF607086), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _RewardsEntryCard(points: widget.rewardPoints, onTap: _openRewards),
            const SizedBox(height: 12),
            _CheckInMemoriesEntryCard(
              checkedInCount: widget.checkedInPlaces.length,
              onTap: _openCheckInMemories,
            ),
          ],
        ),
      ),
    );
  }
}
