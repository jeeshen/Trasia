part of '../main.dart';

class TrasiaData {
  static List<Driver> drivers = [];
  static List<Attraction> attractions = [];
  static List<DestinationCandidate> localSuggestions = [];
  static Future<void> load() async {
    final client = Supabase.instance.client;
    final driversData = await client.from('drivers').select();
    drivers = driversData
        .map(
          (d) => Driver(
            d['name'] as String,
            d['vehicle'] as String,
            d['rating'] as String,
            Color(int.parse(d['color'] as String)),
            LatLng(d['lat'] as double, d['lng'] as double),
          ),
        )
        .toList();
    final localSuggestionsData = await client
        .from('local_suggestions')
        .select();
    localSuggestions = localSuggestionsData
        .map(
          (d) => DestinationCandidate(
            name: d['name'] as String,
            address: d['address'] as String,
            placeId: d['place_id'] as String,
            location: LatLng(d['lat'] as double, d['lng'] as double),
          ),
        )
        .toList();
    final attractionsData = await client.from('attractions').select();
    attractions = attractionsData
        .map(
          (d) => Attraction(
            name: d['name'] as String,
            hours: d['hours'] as String,
            openMinute: d['open_minute'] as int,
            closeMinute: d['close_minute'] as int,
            baseCost: d['base_cost'] as int,
            stayMinutes: d['stay_minutes'] as int,
            suggestedDistanceKm: (d['suggested_distance_km'] as num).toDouble(),
            priceTier: PriceTier.values.firstWhere(
              (e) => e.name == d['price_tier'],
            ),
            imageAsset: d['image_asset'] as String,
            color: Color(int.parse(d['color'] as String)),
            location: LatLng(d['lat'] as double, d['lng'] as double),
          ),
        )
        .toList();
  }
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

String _userFacingTransitText(String value) {
  return value
      .replaceAll(
        RegExp(r'\s*(?:via\s+)?data\.gov\.my\b', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

class _GoogleMapsApi {
  static const _maxAccessWalkMeters = 1600.0;
  static const _maxTotalWalkMeters = 3000.0;
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
      for (final result in results)
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
    final suggestions = TrasiaData.localSuggestions;
    return [
      for (final suggestion in suggestions)
        if (suggestion.name.toLowerCase().contains(normalized) ||
            suggestion.address.toLowerCase().contains(normalized) ||
            normalized.contains('klcc'))
          suggestion,
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
      throw roadServiceError;
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
      return await _fetchDirectionsRoute(
        origin: origin,
        destination: destination,
        apiKey: apiKey,
        mode: 'driving',
      );
    } catch (directionsError) {
      throw 'Road service: $roadServiceError / '
          'Google Routes API: $routesError / '
          'Google Directions API: $directionsError';
    }
  }

  static Future<List<_TransitApiRoute>> fetchTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    required String originName,
    required String destinationName,
    required String apiKey,
  }) async {
    Object? routesApiError;
    try {
      final routes = await _fetchRoutesApiTransitRoutes(
        origin: origin,
        destination: destination,
        originName: originName,
        destinationName: destinationName,
        apiKey: apiKey,
      );
      if (routes.isNotEmpty) {
        return routes;
      }
    } catch (error) {
      routesApiError = error;
    }
    try {
      return await _fetchDirectionsTransitRoutes(
        origin: origin,
        destination: destination,
        originName: originName,
        destinationName: destinationName,
        apiKey: apiKey,
      );
    } catch (directionsError) {
      throw 'Google Routes Transit: $routesApiError / '
          'Google Directions Transit: $directionsError';
    }
  }

  static Future<List<_TransitApiRoute>> _fetchRoutesApiTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    required String originName,
    required String destinationName,
    required String apiKey,
  }) async {
    final uri = Uri.https(
      'routes.googleapis.com',
      '/directions/v2:computeRoutes',
    );
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': apiKey,
            'X-Goog-FieldMask':
                'routes.duration,routes.distanceMeters,routes.localizedValues,'
                'routes.travelAdvisory.transitFare,routes.legs.steps.duration,'
                'routes.legs.steps.staticDuration,routes.legs.steps.distanceMeters,'
                'routes.legs.steps.polyline.encodedPolyline,'
                'routes.legs.steps.startLocation,routes.legs.steps.endLocation,'
                'routes.legs.steps.travelMode,routes.legs.steps.transitDetails',
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
            'travelMode': 'TRANSIT',
            'computeAlternativeRoutes': true,
            'transitPreferences': {
              'routingPreference': 'LESS_WALKING',
              'allowedTravelModes': [
                'BUS',
                'SUBWAY',
                'TRAIN',
                'LIGHT_RAIL',
                'RAIL',
              ],
            },
            'languageCode': 'en',
            'regionCode': 'MY',
            'units': 'METRIC',
          }),
        )
        .timeout(const Duration(seconds: 12));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final error = body['error'] as Map<String, dynamic>?;
      throw error?['message'] ?? 'Unknown transit Routes API error';
    }
    final routes = body['routes'] as List<dynamic>? ?? const [];
    final parsedRoutes = <_TransitApiRoute>[];
    for (final route in routes) {
      final parsed = _parseTransitRoute(
        route as Map<String, dynamic>,
        originName: originName,
        destinationName: destinationName,
      );
      if (parsed != null) {
        parsedRoutes.add(parsed);
      }
    }
    return parsedRoutes;
  }

  static Future<List<_TransitApiRoute>> _fetchDirectionsTransitRoutes({
    required LatLng origin,
    required LatLng destination,
    required String originName,
    required String destinationName,
    required String apiKey,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': 'transit',
      'alternatives': 'true',
      'transit_mode': 'bus|subway|train|tram|rail',
      'transit_routing_preference': 'less_walking',
      'region': 'my',
      'language': 'en',
      'departure_time': 'now',
      'key': apiKey,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (response.statusCode != 200 || status != 'OK') {
      throw (body['error_message'] as String?) ??
          status ??
          'Unknown Directions Transit API error';
    }
    final routes = body['routes'] as List<dynamic>? ?? const [];
    final parsedRoutes = <_TransitApiRoute>[];
    for (final route in routes) {
      final parsed = _parseDirectionsTransitRoute(
        route as Map<String, dynamic>,
        originName: originName,
        destinationName: destinationName,
      );
      if (parsed != null) {
        parsedRoutes.add(parsed);
      }
    }
    return parsedRoutes;
  }

  static _TransitApiRoute? _parseDirectionsTransitRoute(
    Map<String, dynamic> route, {
    required String originName,
    required String destinationName,
  }) {
    final routeLegs = route['legs'] as List<dynamic>? ?? const [];
    if (routeLegs.isEmpty) {
      return null;
    }
    final leg = routeLegs.first as Map<String, dynamic>;
    final steps = (leg['steps'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (steps.isEmpty) {
      return null;
    }
    final walking = [
      for (final step in steps) step['travel_mode'] == 'WALKING',
    ];
    final meters = [
      for (final step in steps)
        (((step['distance'] as Map<String, dynamic>?)?['value'] as num?)
                ?.toDouble() ??
            0),
    ];
    final walkingMeters = [
      for (var index = 0; index < steps.length; index++)
        if (walking[index]) meters[index],
    ].fold<double>(0, (total, value) => total + value);
    var accessMeters = 0.0;
    for (var index = 0; index < steps.length && walking[index]; index++) {
      accessMeters += meters[index];
    }
    var egressMeters = 0.0;
    for (var index = steps.length - 1; index >= 0 && walking[index]; index--) {
      egressMeters += meters[index];
    }
    final transitCount = walking.where((value) => !value).length;
    if (transitCount == 0) {
      return null;
    }
    final longAccessWalk =
        accessMeters > _maxAccessWalkMeters ||
        egressMeters > _maxAccessWalkMeters ||
        walkingMeters > _maxTotalWalkMeters;
    final parsedLegs = <RouteLeg>[];
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      final isWalk = walking[index];
      final details =
          step['transit_details'] as Map<String, dynamic>? ?? const {};
      final departure =
          details['departure_stop'] as Map<String, dynamic>? ?? const {};
      final arrival =
          details['arrival_stop'] as Map<String, dynamic>? ?? const {};
      final previousDetails = index == 0
          ? const <String, dynamic>{}
          : steps[index - 1]['transit_details'] as Map<String, dynamic>? ??
                const {};
      final nextDetails = index == steps.length - 1
          ? const <String, dynamic>{}
          : steps[index + 1]['transit_details'] as Map<String, dynamic>? ??
                const {};
      final previousArrival =
          previousDetails['arrival_stop'] as Map<String, dynamic>? ?? const {};
      final nextDeparture =
          nextDetails['departure_stop'] as Map<String, dynamic>? ?? const {};
      final fromName = isWalk
          ? index == 0
                ? originName
                : (previousArrival['name'] as String?) ?? 'Transfer point'
          : (departure['name'] as String?) ?? 'Transit stop';
      final toName = isWalk
          ? index == steps.length - 1
                ? destinationName
                : (nextDeparture['name'] as String?) ?? 'Nearby transit stop'
          : (arrival['name'] as String?) ?? 'Transit stop';
      final duration = step['duration'] as Map<String, dynamic>? ?? const {};
      final distance = step['distance'] as Map<String, dynamic>? ?? const {};
      var points = _decodePolyline(
        ((step['polyline'] as Map<String, dynamic>?)?['points'] as String?) ??
            '',
      );
      if (points.isEmpty) {
        points = [
          ?_legacyLatLng(step['start_location']),
          ?_legacyLatLng(step['end_location']),
        ];
      }
      parsedLegs.add(
        RouteLeg(
          fromName: fromName,
          toName: toName,
          mode: isWalk ? 'Walk' : _legacyTransitModeLabel(details),
          time:
              (duration['text'] as String?) ??
              _formatSeconds((duration['value'] as num?) ?? 0),
          distance:
              (distance['text'] as String?) ??
              _formatMeters(meters[index].round()),
          icon: isWalk
              ? Icons.directions_walk_rounded
              : _legacyTransitModeIcon(details),
          points: points,
        ),
      );
    }
    final duration = leg['duration'] as Map<String, dynamic>? ?? const {};
    final distance = leg['distance'] as Map<String, dynamic>? ?? const {};
    final fare = route['fare'] as Map<String, dynamic>? ?? const {};
    final transfers = max(0, transitCount - 1);
    final durationSeconds = (duration['value'] as num?)?.toDouble() ?? 0;
    return _TransitApiRoute(
      option: TransitOption(
        label: 'Transit',
        chain: parsedLegs.map((item) => item.mode).toSet().join(' -> '),
        time: (duration['text'] as String?) ?? _formatSeconds(durationSeconds),
        distance:
            (distance['text'] as String?) ??
            _formatMeters((distance['value'] as num?)?.round()),
        fare: (fare['text'] as String?) ?? 'Fare unavailable',
        transfers: transfers == 0 ? 'No transfer' : '$transfers transfer',
        crowd: .48,
        color: TrasiaColors.primary,
        legs: parsedLegs,
        firstLegPointCount: parsedLegs.first.points.length,
        firstStopLabel: parsedLegs.first.toName,
        nextInstruction:
            'Use ${parsedLegs.where((item) => item.mode != 'Walk').map((item) => item.mode).take(3).join(' + ')}',
      ),
      durationSeconds: durationSeconds,
      walkingMeters: walkingMeters,
      transfers: transfers,
      longAccessWalk: longAccessWalk,
    );
  }

  static String _legacyTransitModeLabel(Map<String, dynamic> details) {
    final line = details['line'] as Map<String, dynamic>? ?? const {};
    final agencies = line['agencies'] as List<dynamic>? ?? const [];
    final agency = agencies.isEmpty
        ? ''
        : _userFacingTransitText(
            ((agencies.first as Map<String, dynamic>)['name'] as String?) ?? '',
          );
    final routeName = _userFacingTransitText(
      (line['short_name'] as String?) ?? (line['name'] as String?) ?? '',
    );
    final vehicle = line['vehicle'] as Map<String, dynamic>? ?? const {};
    final vehicleName =
        (vehicle['name'] as String?) ??
        _vehicleTypeName(vehicle['type'] as String?);
    return [
      if (agency.isNotEmpty) agency,
      if (routeName.isNotEmpty) routeName,
      if (agency.isEmpty && routeName.isEmpty) vehicleName,
    ].join(' ');
  }

  static IconData _legacyTransitModeIcon(Map<String, dynamic> details) {
    final line = details['line'] as Map<String, dynamic>? ?? const {};
    final vehicle = line['vehicle'] as Map<String, dynamic>? ?? const {};
    return switch (vehicle['type'] as String?) {
      'BUS' => Icons.directions_bus_rounded,
      'SUBWAY' || 'TRAM' => Icons.subway_rounded,
      _ => Icons.train_rounded,
    };
  }

  static LatLng? _legacyLatLng(Object? location) {
    final value = location as Map<String, dynamic>?;
    final latitude = (value?['lat'] as num?)?.toDouble();
    final longitude = (value?['lng'] as num?)?.toDouble();
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
  }

  static _TransitApiRoute? _parseTransitRoute(
    Map<String, dynamic> route, {
    required String originName,
    required String destinationName,
  }) {
    final routeLegs = route['legs'] as List<dynamic>? ?? const [];
    final steps = [
      for (final leg in routeLegs)
        ...((leg as Map<String, dynamic>)['steps'] as List<dynamic>? ??
            const []),
    ].cast<Map<String, dynamic>>();
    if (steps.isEmpty) {
      return null;
    }
    final isWalking = [for (final step in steps) step['travelMode'] == 'WALK'];
    final stepMeters = [
      for (final step in steps)
        (step['distanceMeters'] as num?)?.toDouble() ?? 0,
    ];
    final totalWalkingMeters = [
      for (var i = 0; i < steps.length; i++)
        if (isWalking[i]) stepMeters[i],
    ].fold<double>(0, (total, meters) => total + meters);
    var accessWalkingMeters = 0.0;
    for (var i = 0; i < steps.length && isWalking[i]; i++) {
      accessWalkingMeters += stepMeters[i];
    }
    var egressWalkingMeters = 0.0;
    for (var i = steps.length - 1; i >= 0 && isWalking[i]; i--) {
      egressWalkingMeters += stepMeters[i];
    }
    final hasExcessiveWalk =
        accessWalkingMeters > _maxAccessWalkMeters ||
        egressWalkingMeters > _maxAccessWalkMeters ||
        totalWalkingMeters > _maxTotalWalkMeters ||
        stepMeters.indexed.any(
          (entry) => isWalking[entry.$1] && entry.$2 > _maxAccessWalkMeters,
        );
    final transitStepCount = isWalking.where((walking) => !walking).length;
    if (transitStepCount == 0) {
      return null;
    }
    final legs = <RouteLeg>[];
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      final walking = isWalking[index];
      final transitDetails =
          step['transitDetails'] as Map<String, dynamic>? ?? const {};
      final stopDetails =
          transitDetails['stopDetails'] as Map<String, dynamic>? ?? const {};
      final departureStop =
          stopDetails['departureStop'] as Map<String, dynamic>? ?? const {};
      final arrivalStop =
          stopDetails['arrivalStop'] as Map<String, dynamic>? ?? const {};
      final fromName = walking
          ? _walkingStepFromName(
              index,
              steps,
              originName: originName,
              destinationName: destinationName,
            )
          : (departureStop['name'] as String?) ?? 'Transit stop';
      final toName = walking
          ? _walkingStepToName(
              index,
              steps,
              originName: originName,
              destinationName: destinationName,
            )
          : (arrivalStop['name'] as String?) ?? 'Transit stop';
      final mode = walking ? 'Walk' : _transitModeLabel(transitDetails);
      final encodedPolyline =
          ((step['polyline'] as Map<String, dynamic>?)?['encodedPolyline']
              as String?) ??
          '';
      var points = _decodePolyline(encodedPolyline);
      if (points.isEmpty) {
        final start = _routeLatLng(step['startLocation']);
        final end = _routeLatLng(step['endLocation']);
        points = [?start, ?end];
      }
      final seconds = _parseGoogleDurationSeconds(
        (step['duration'] ?? step['staticDuration']) as String?,
      );
      legs.add(
        RouteLeg(
          fromName: fromName,
          toName: toName,
          mode: mode,
          time: _formatSeconds(seconds),
          distance: _formatMeters(stepMeters[index].round()),
          icon: walking
              ? Icons.directions_walk_rounded
              : _transitModeIcon(transitDetails),
          points: points,
        ),
      );
    }
    final localized =
        route['localizedValues'] as Map<String, dynamic>? ?? const {};
    final durationText =
        ((localized['duration'] as Map<String, dynamic>?)?['text'] as String?);
    final distanceText =
        ((localized['distance'] as Map<String, dynamic>?)?['text'] as String?);
    final fareText =
        ((localized['transitFare'] as Map<String, dynamic>?)?['text']
            as String?);
    final routeFare =
        route['travelAdvisory'] as Map<String, dynamic>? ?? const {};
    final transitFare =
        routeFare['transitFare'] as Map<String, dynamic>? ?? const {};
    final fare =
        fareText ??
        (transitFare['units'] == null
            ? 'Fare unavailable'
            : '${transitFare['currencyCode'] ?? 'MYR'} '
                  '${transitFare['units']}');
    final transfers = max(0, transitStepCount - 1);
    final totalSeconds = _parseGoogleDurationSeconds(
      route['duration'] as String?,
    );
    final option = TransitOption(
      label: 'Transit',
      chain: legs.map((leg) => leg.mode).toSet().join(' -> '),
      time: durationText ?? _formatSeconds(totalSeconds),
      distance:
          distanceText ??
          _formatMeters((route['distanceMeters'] as num?)?.round()),
      fare: fare,
      transfers: transfers == 0 ? 'No transfer' : '$transfers transfer',
      crowd: .48,
      color: TrasiaColors.primary,
      legs: legs,
      firstLegPointCount: legs.first.points.length,
      firstStopLabel: legs.first.toName,
      nextInstruction:
          'Use ${legs.where((leg) => leg.mode != 'Walk').map((leg) => leg.mode).take(3).join(' + ')}',
    );
    return _TransitApiRoute(
      option: option,
      durationSeconds: totalSeconds,
      walkingMeters: totalWalkingMeters,
      transfers: transfers,
      longAccessWalk: hasExcessiveWalk,
    );
  }

  static String _walkingStepFromName(
    int index,
    List<Map<String, dynamic>> steps, {
    required String originName,
    required String destinationName,
  }) {
    if (index == 0) {
      return originName;
    }
    final previous =
        steps[index - 1]['transitDetails'] as Map<String, dynamic>?;
    final stopDetails =
        previous?['stopDetails'] as Map<String, dynamic>? ?? const {};
    final arrival =
        stopDetails['arrivalStop'] as Map<String, dynamic>? ?? const {};
    return (arrival['name'] as String?) ?? 'Transfer point';
  }

  static String _walkingStepToName(
    int index,
    List<Map<String, dynamic>> steps, {
    required String originName,
    required String destinationName,
  }) {
    if (index == steps.length - 1) {
      return destinationName;
    }
    final next = steps[index + 1]['transitDetails'] as Map<String, dynamic>?;
    final stopDetails =
        next?['stopDetails'] as Map<String, dynamic>? ?? const {};
    final departure =
        stopDetails['departureStop'] as Map<String, dynamic>? ?? const {};
    return (departure['name'] as String?) ?? 'Nearby transit stop';
  }

  static String _transitModeLabel(Map<String, dynamic> transitDetails) {
    final line =
        transitDetails['transitLine'] as Map<String, dynamic>? ?? const {};
    final agencies = line['agencies'] as List<dynamic>? ?? const [];
    final agency = agencies.isEmpty
        ? ''
        : _userFacingTransitText(
            ((agencies.first as Map<String, dynamic>)['name'] as String?) ?? '',
          );
    final routeName = _userFacingTransitText(
      (line['nameShort'] as String?) ?? (line['name'] as String?) ?? '',
    );
    final vehicle = line['vehicle'] as Map<String, dynamic>? ?? const {};
    final vehicleName =
        ((vehicle['name'] as Map<String, dynamic>?)?['text'] as String?) ??
        _vehicleTypeName(vehicle['type'] as String?);
    return [
      if (agency.isNotEmpty) agency,
      if (routeName.isNotEmpty) routeName,
      if (agency.isEmpty && routeName.isEmpty) vehicleName,
    ].join(' ');
  }

  static String _vehicleTypeName(String? type) {
    return switch (type) {
      'BUS' => 'Bus',
      'SUBWAY' => 'MRT',
      'LIGHT_RAIL' => 'LRT',
      'HEAVY_RAIL' || 'COMMUTER_TRAIN' || 'RAIL' => 'Train',
      _ => 'Public transit',
    };
  }

  static IconData _transitModeIcon(Map<String, dynamic> transitDetails) {
    final line =
        transitDetails['transitLine'] as Map<String, dynamic>? ?? const {};
    final vehicle = line['vehicle'] as Map<String, dynamic>? ?? const {};
    return switch (vehicle['type'] as String?) {
      'BUS' => Icons.directions_bus_rounded,
      'SUBWAY' || 'LIGHT_RAIL' => Icons.subway_rounded,
      _ => Icons.train_rounded,
    };
  }

  static LatLng? _routeLatLng(Object? location) {
    final locationMap = location as Map<String, dynamic>?;
    final latLng = locationMap?['latLng'] as Map<String, dynamic>? ?? const {};
    final latitude = (latLng['latitude'] as num?)?.toDouble();
    final longitude = (latLng['longitude'] as num?)?.toDouble();
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
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
    final durationSeconds = _parseGoogleDurationSeconds(
      route['duration'] as String?,
    );
    return _DrivingRoute(
      points: points,
      time: _formatDuration(route['duration'] as String?),
      distance: _formatMeters(distanceMeters.round()),
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  static Future<_DrivingRoute> _fetchDirectionsRoute({
    required LatLng origin,
    required LatLng destination,
    required String apiKey,
    required String mode,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'mode': mode,
      'region': 'my',
      'alternatives': 'false',
      'key': apiKey,
    });
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (response.statusCode != 200 || status != 'OK') {
      throw (body['error_message'] as String?) ??
          status ??
          'Unknown Directions API error';
    }
    final routes = body['routes'] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      throw 'No $mode route found';
    }
    final route = routes.first as Map<String, dynamic>;
    final overviewPolyline =
        route['overview_polyline'] as Map<String, dynamic>?;
    final points = _decodePolyline(
      (overviewPolyline?['points'] as String?) ?? '',
    );
    if (points.isEmpty) {
      throw '$mode route did not include a polyline';
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
      distance:
          (distance['text'] as String?) ??
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
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
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

class _TransitApiRoute {
  const _TransitApiRoute({
    required this.option,
    required this.durationSeconds,
    required this.walkingMeters,
    required this.transfers,
    required this.longAccessWalk,
  });
  final TransitOption option;
  final double durationSeconds;
  final double walkingMeters;
  final int transfers;
  final bool longAccessWalk;
  String get signature => option.legs
      .map((leg) => '${leg.fromName}|${leg.toName}|${leg.mode}')
      .join('>');
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
  String get operatorKey =>
      mode == _TransitMode.walk ? 'walk' : '$operatorName|$routeName';
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
  _TransitEdge copyWith({String? fromId, String? toId, bool? transferPenalty}) {
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

class GovernmentDataSource {
  const GovernmentDataSource({
    required this.name,
    required this.portal,
    required this.url,
    required this.focus,
    required this.projectUse,
    required this.icon,
    required this.color,
  });
  final String name;
  final String portal;
  final String url;
  final String focus;
  final String projectUse;
  final IconData icon;
  final Color color;
}

const governmentDataSources = [
  GovernmentDataSource(
    name: 'data.gov.my',
    portal: 'Malaysia central open data portal',
    url: 'https://data.gov.my/',
    focus:
        'High-frequency open datasets, dashboards, catalogue search, and developer API access from Malaysian public agencies.',
    projectUse:
        'Used as a research reference for Malaysian transport context. Live route choices and geometry are requested from Google Maps.',
    icon: Icons.dataset_rounded,
    color: Color(0xFF0B7CFF),
  ),
  GovernmentDataSource(
    name: 'OpenDOSM NextGen',
    portal: 'Department of Statistics Malaysia',
    url: 'https://open.dosm.gov.my/',
    focus:
        'Official economic, demographic, labour, price, and social statistics through dashboards, catalogues, publications, and APIs.',
    projectUse:
        'Used as the trusted context layer for assignment discussion, especially population, tourism demand, cost of living, and urban mobility justification.',
    icon: Icons.query_stats_rounded,
    color: Color(0xFF00A9CE),
  ),
  GovernmentDataSource(
    name: 'MYSA Open Government Data',
    portal: 'Malaysian Space Agency',
    url: 'https://www.mysa.gov.my/open-government-data/',
    focus:
        'Open government data principles and geospatial or remote sensing data access from Malaysia Space Agency resources.',
    projectUse:
        'Supports the open-data rationale for location-aware planning, map-based tourism discovery, and reuse of public geospatial information.',
    icon: Icons.public_rounded,
    color: Color(0xFF3CCB7F),
  ),
  GovernmentDataSource(
    name: 'World Bank Malaysia Data',
    portal: 'International development indicators',
    url: 'https://data.worldbank.org/country/malaysia',
    focus:
        'Internationally comparable Malaysia indicators across economy, population, transport, environment, and development.',
    projectUse:
        'Provides external benchmark data for explaining Malaysia trends and comparing Trasia benefits such as lower travel cost and carbon-conscious mobility.',
    icon: Icons.language_rounded,
    color: Color(0xFFFFA800),
  ),
];
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
  _TransitStopNode(
    'taman_suntex',
    'Taman Suntex MRT',
    LatLng(3.0716, 101.7636),
  ),
  _TransitStopNode(
    'batu_11_cheras',
    'Batu 11 Cheras MRT',
    LatLng(3.0410, 101.7731),
  ),
  _TransitStopNode('titiwangsa', 'Titiwangsa', LatLng(3.1736, 101.6959)),
  _TransitStopNode('bts', 'Bandar Tasik Selatan', LatLng(3.0766, 101.7115)),
  _TransitStopNode('kajang', 'Kajang', LatLng(2.9833, 101.7909)),
  _TransitStopNode('ampang', 'Ampang', LatLng(3.1490, 101.7601)),
  _TransitStopNode('sri_petaling', 'Sri Petaling', LatLng(3.0615, 101.6876)),
  _TransitStopNode('wangsa_maju', 'Wangsa Maju LRT', LatLng(3.2056, 101.7314)),
  _TransitStopNode('sri_rampai', 'Sri Rampai LRT', LatLng(3.1985, 101.7377)),
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
    fromId: 'maluri',
    toId: 'taman_suntex',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 18,
    fare: 2.20,
  ),
  _TransitEdge(
    fromId: 'taman_suntex',
    toId: 'batu_11_cheras',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 5,
    fare: .80,
  ),
  _TransitEdge(
    fromId: 'batu_11_cheras',
    toId: 'kajang',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'MRT Kajang',
    minutes: 16,
    fare: 2.20,
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
  _TransitEdge(
    fromId: 'wangsa_maju',
    toId: 'sri_rampai',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Kelana Jaya',
    minutes: 3,
    fare: .60,
  ),
  _TransitEdge(
    fromId: 'sri_rampai',
    toId: 'klcc',
    mode: _TransitMode.rail,
    operatorName: 'Rapid KL',
    routeName: 'LRT Kelana Jaya',
    minutes: 15,
    fare: 2.20,
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
  const _DriverArrival({required this.driver, required this.route});
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

class FavoritePlace {
  const FavoritePlace({
    required this.name,
    required this.address,
    required this.hours,
    required this.baseCost,
    required this.suggestedDistanceKm,
    required this.priceTier,
    required this.imageAsset,
    required this.color,
    required this.location,
  });
  final String name;
  final String address;
  final String hours;
  final int baseCost;
  final double suggestedDistanceKm;
  final PriceTier priceTier;
  final String imageAsset;
  final Color color;
  final LatLng location;
  String get key => name.toLowerCase();
  factory FavoritePlace.fromAttraction(Attraction attraction) {
    return FavoritePlace(
      name: attraction.name,
      address: '',
      hours: attraction.hours,
      baseCost: attraction.baseCost,
      suggestedDistanceKm: attraction.suggestedDistanceKm,
      priceTier: attraction.priceTier,
      imageAsset: attraction.imageAsset,
      color: attraction.color,
      location: attraction.location,
    );
  }
  factory FavoritePlace.fromDestinationCandidate(
    DestinationCandidate destination,
  ) {
    return FavoritePlace(
      name: destination.name,
      address: destination.address,
      hours: 'Place details saved from search',
      baseCost: 0,
      suggestedDistanceKm: 0,
      priceTier: PriceTier.midRange,
      imageAsset: '',
      color: TrasiaColors.primary,
      location: destination.location,
    );
  }
  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      name: (json['name'] as String?) ?? 'Unknown place',
      address: (json['address'] as String?) ?? '',
      hours: (json['hours'] as String?) ?? 'Hours unavailable',
      baseCost: ((json['baseCost'] as num?) ?? 0).toInt(),
      suggestedDistanceKm: ((json['suggestedDistanceKm'] as num?) ?? 0)
          .toDouble(),
      priceTier: PriceTier.values.firstWhere(
        (tier) => tier.name == json['priceTier'],
        orElse: () => PriceTier.midRange,
      ),
      imageAsset: (json['imageAsset'] as String?) ?? '',
      color: Color(((json['color'] as num?) ?? 0xFF0B7CFF).toInt()),
      location: LatLng(
        ((json['latitude'] as num?) ?? 3.1478).toDouble(),
        ((json['longitude'] as num?) ?? 101.6953).toDouble(),
      ),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'hours': hours,
      'baseCost': baseCost,
      'suggestedDistanceKm': suggestedDistanceKm,
      'priceTier': priceTier.name,
      'imageAsset': imageAsset,
      'color': color.toARGB32(),
      'latitude': location.latitude,
      'longitude': location.longitude,
    };
  }
}

class TripHistoryEntry {
  const TripHistoryEntry({
    required this.placeName,
    required this.category,
    required this.completedAt,
    this.detail = '',
    this.amountPaid,
  });
  final String placeName;
  final String category;
  final DateTime completedAt;
  final String detail;
  final double? amountPaid;
  factory TripHistoryEntry.fromJson(Map<String, dynamic> json) {
    return TripHistoryEntry(
      placeName: (json['placeName'] as String?) ?? 'Unknown place',
      category: (json['category'] as String?) ?? 'Trip',
      completedAt:
          DateTime.tryParse((json['completedAt'] as String?) ?? '') ??
          DateTime.now(),
      detail: (json['detail'] as String?) ?? '',
      amountPaid: (json['amountPaid'] as num?)?.toDouble(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'placeName': placeName,
      'category': category,
      'completedAt': completedAt.toIso8601String(),
      'detail': detail,
      'amountPaid': amountPaid,
    };
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
