import 'dart:convert';

import 'package:http/http.dart' as http;

/// Human-friendly names for an aircraft type.
class AircraftName {
  const AircraftName({this.short, this.full});

  final String? short;
  final String? full;
}

/// Turns ICAO codes into human-friendly airline and aircraft names.
abstract interface class DisplayNameSource {
  /// e.g. `UAL` → `United Airlines`. Null if unknown.
  Future<String?> airlineName(String airlineIcao);

  /// e.g. `B738` → `737-800` / `Boeing 737-800`. Null if unknown.
  Future<AircraftName?> aircraftName(String aircraftIcao);
}

/// Name lookup using the FlightWall CDN, as the firmware does.
///
/// This is TheFlightWall's own server rather than a documented public API,
/// so it may change. Results (including misses) are cached for the lifetime
/// of this object, and failures are treated as "unknown" rather than thrown.
class FlightWallCdnNameSource implements DisplayNameSource {
  FlightWallCdnNameSource({
    http.Client? client,
    this.baseUrl = 'https://cdn.theflightwall.com',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final _airlines = <String, Future<String?>>{};
  final _aircraft = <String, Future<AircraftName?>>{};

  @override
  Future<String?> airlineName(String airlineIcao) {
    if (airlineIcao.isEmpty) return Future.value(null);
    return _airlines.putIfAbsent(airlineIcao, () async {
      final json = await _getJson('/oss/lookup/airline/$airlineIcao.json');
      return _str(json?['display_name_full']);
    });
  }

  @override
  Future<AircraftName?> aircraftName(String aircraftIcao) {
    if (aircraftIcao.isEmpty) return Future.value(null);
    return _aircraft.putIfAbsent(aircraftIcao, () async {
      final json = await _getJson('/oss/lookup/aircraft/$aircraftIcao.json');
      if (json == null) return null;
      final short = _str(json['display_name_short']);
      final full = _str(json['display_name_full']);
      if (short == null && full == null) return null;
      return AircraftName(short: short, full: full);
    });
  }

  Future<Map<String, dynamic>?> _getJson(String path) async {
    try {
      final res = await _client.get(
        Uri.parse('$baseUrl$path'),
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      return body is Map<String, dynamic> ? body : null;
    } on Exception {
      return null;
    }
  }
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
