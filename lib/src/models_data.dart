part of '../main.dart';

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
      throw (body['error_message'] as String?) ??
          status ??
          'Unknown Directions API error';
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

const gtfsStaticRapidRailKlEndpoint =
    'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-rail-kl';
const gtfsStaticRapidBusKlEndpoint =
    'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-kl';
const gtfsStaticMrtFeederEndpoint =
    'https://api.data.gov.my/gtfs-static/prasarana?category=rapid-bus-mrtfeeder';
const gtfsStaticKtmbEndpoint = 'https://api.data.gov.my/gtfs-static/ktmb';

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
        'Trasia uses Malaysia open transport data as the foundation for public transport routing. The app references official GTFS endpoints for Rapid KL rail, Rapid KL bus, MRT feeder, and KTMB services.',
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

const officialTransitDataEndpoints = [
  gtfsStaticRapidRailKlEndpoint,
  gtfsStaticRapidBusKlEndpoint,
  gtfsStaticMrtFeederEndpoint,
  gtfsStaticKtmbEndpoint,
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

class _BlindBoxArea {
  const _BlindBoxArea(this.name, this.location);

  final String name;
  final LatLng location;
}

class _BlindBoxTheme {
  const _BlindBoxTheme({
    required this.name,
    required this.hours,
    required this.openMinute,
    required this.closeMinute,
    required this.baseCost,
    required this.stayMinutes,
    required this.priceTier,
    required this.color,
  });

  final String name;
  final String hours;
  final int openMinute;
  final int closeMinute;
  final int baseCost;
  final int stayMinutes;
  final PriceTier priceTier;
  final Color color;
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

  const areas = [
    _BlindBoxArea('Bukit Bintang', LatLng(3.1468, 101.7113)),
    _BlindBoxArea('Chinatown', LatLng(3.1421, 101.6964)),
    _BlindBoxArea('KLCC', LatLng(3.1579, 101.7123)),
    _BlindBoxArea('Brickfields', LatLng(3.1291, 101.6841)),
    _BlindBoxArea('Chow Kit', LatLng(3.1675, 101.6980)),
    _BlindBoxArea('Kampung Baru', LatLng(3.1641, 101.7068)),
    _BlindBoxArea('Bangsar', LatLng(3.1292, 101.6784)),
    _BlindBoxArea('Mont Kiara', LatLng(3.1700, 101.6529)),
    _BlindBoxArea('TTDI', LatLng(3.1413, 101.6297)),
    _BlindBoxArea('Cheras', LatLng(3.1068, 101.7259)),
    _BlindBoxArea('Ampang', LatLng(3.1502, 101.7600)),
    _BlindBoxArea('Setapak', LatLng(3.1881, 101.7106)),
    _BlindBoxArea('Sentul', LatLng(3.1838, 101.6923)),
    _BlindBoxArea('Titiwangsa', LatLng(3.1804, 101.7037)),
    _BlindBoxArea('Petaling Jaya', LatLng(3.1073, 101.6067)),
    _BlindBoxArea('Subang Jaya', LatLng(3.0567, 101.5851)),
    _BlindBoxArea('Shah Alam', LatLng(3.0738, 101.5183)),
    _BlindBoxArea('Puchong', LatLng(3.0327, 101.6188)),
    _BlindBoxArea('Sri Petaling', LatLng(3.0715, 101.6947)),
    _BlindBoxArea('Kepong', LatLng(3.2140, 101.6356)),
    _BlindBoxArea('Batu Caves', LatLng(3.2379, 101.6840)),
  ];
  const themes = [
    _BlindBoxTheme(
      name: 'Food Discovery',
      hours: '10:00 - 22:00',
      openMinute: 10 * 60,
      closeMinute: 22 * 60,
      baseCost: 35,
      stayMinutes: 60,
      priceTier: PriceTier.midRange,
      color: Color(0xFFFF7A59),
    ),
    _BlindBoxTheme(
      name: 'Cafe Corner',
      hours: '09:00 - 21:00',
      openMinute: 9 * 60,
      closeMinute: 21 * 60,
      baseCost: 28,
      stayMinutes: 55,
      priceTier: PriceTier.midRange,
      color: Color(0xFF40A9FF),
    ),
    _BlindBoxTheme(
      name: 'Night Market',
      hours: '17:00 - 00:00',
      openMinute: 17 * 60,
      closeMinute: 24 * 60,
      baseCost: 22,
      stayMinutes: 70,
      priceTier: PriceTier.budget,
      color: Color(0xFFFFCE3D),
    ),
    _BlindBoxTheme(
      name: 'Heritage Walk',
      hours: '09:00 - 19:00',
      openMinute: 9 * 60,
      closeMinute: 19 * 60,
      baseCost: 12,
      stayMinutes: 65,
      priceTier: PriceTier.budget,
      color: Color(0xFF7C5CFF),
    ),
    _BlindBoxTheme(
      name: 'Green Escape',
      hours: '06:00 - 20:00',
      openMinute: 6 * 60,
      closeMinute: 20 * 60,
      baseCost: 0,
      stayMinutes: 60,
      priceTier: PriceTier.budget,
      color: Color(0xFF3CCB7F),
    ),
    _BlindBoxTheme(
      name: 'Family Stop',
      hours: '10:00 - 20:00',
      openMinute: 10 * 60,
      closeMinute: 20 * 60,
      baseCost: 65,
      stayMinutes: 80,
      priceTier: PriceTier.luxury,
      color: Color(0xFF00A9CE),
    ),
  ];

  final demoPlaces = <Attraction>[
    for (var areaIndex = 0; areaIndex < areas.length; areaIndex++)
      for (var themeIndex = 0; themeIndex < themes.length; themeIndex++)
        () {
          final area = areas[areaIndex];
          final theme = themes[themeIndex];
          final image =
              verifiedPlaces[(areaIndex * themes.length + themeIndex) %
                  verifiedPlaces.length];
          final offset = (themeIndex - 2.5) * 0.0012;
          return Attraction(
            name: '${area.name} ${theme.name}',
            hours: theme.hours,
            openMinute: theme.openMinute,
            closeMinute: theme.closeMinute,
            baseCost: theme.baseCost,
            stayMinutes: theme.stayMinutes,
            suggestedDistanceKm: 3 + ((areaIndex * 5 + themeIndex * 3) % 38),
            priceTier: theme.priceTier,
            imageAsset: image.imageAsset,
            color: theme.color,
            location: LatLng(
              area.location.latitude + offset,
              area.location.longitude - offset,
            ),
          );
        }(),
  ];

  final places = [...verifiedPlaces, ...demoPlaces];
  assert(places.length == 150);
  assert(places.map((place) => place.name).toSet().length == places.length);
  return places;
}
