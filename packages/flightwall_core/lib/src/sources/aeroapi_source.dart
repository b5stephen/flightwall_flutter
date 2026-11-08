import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/flight_details.dart';
import 'flight_details_source.dart';
import 'opensky_source.dart' show ApiException;

/// Flight details from FlightAware AeroAPI (`GET /flights/{ident}`).
///
/// AeroAPI bills per request, so use this behind [FlightRepository]'s cache
/// rather than calling it directly on every poll.
class AeroApiSource implements FlightDetailsSource {
  AeroApiSource({
    required this.apiKey,
    http.Client? client,
    this.baseUrl = 'https://aeroapi.flightaware.com/aeroapi',
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final http.Client _client;

  @override
  Future<FlightDetails?> fetchDetails(String callsign) async {
    final res = await _client.get(
      Uri.parse('$baseUrl/flights/${Uri.encodeComponent(callsign)}'),
      headers: {'x-apikey': apiKey, 'Accept': 'application/json'},
    );
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw ApiException('AeroAPI', res.statusCode, res.body);
    }
    final json = jsonDecode(res.body);
    final flights = json is Map<String, dynamic> ? json['flights'] : null;
    if (flights is! List || flights.isEmpty) return null;

    final chosen = _pickAirborne(flights.whereType<Map<String, dynamic>>());
    return chosen == null ? null : FlightDetails.fromAeroApiJson(chosen);
  }

  /// `/flights/{ident}` returns recent and scheduled legs for the ident.
  /// The firmware takes the first; we prefer the leg that has taken off and
  /// not yet landed, since that is the one overhead.
  static Map<String, dynamic>? _pickAirborne(
      Iterable<Map<String, dynamic>> flights) {
    if (flights.isEmpty) return null;
    for (final f in flights) {
      if (f['actual_off'] != null && f['actual_on'] == null) return f;
    }
    return flights.first;
  }
}
