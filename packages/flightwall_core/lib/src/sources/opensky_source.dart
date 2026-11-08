import 'dart:convert';

import 'package:http/http.dart' as http;

import '../geo.dart';
import '../models/state_vector.dart';
import 'state_vector_source.dart';

/// OpenSky API client credentials (from opensky-network.org → Account → API client).
class OpenSkyCredentials {
  const OpenSkyCredentials({required this.clientId, required this.clientSecret});

  final String clientId;
  final String clientSecret;
}

/// Thrown when an upstream API returns an unexpected response.
class ApiException implements Exception {
  ApiException(this.service, this.statusCode, [this.body]);

  final String service;
  final int statusCode;
  final String? body;

  @override
  String toString() => '$service request failed (HTTP $statusCode)';
}

/// Live positions from the OpenSky Network `states/all` endpoint.
///
/// With [credentials] it uses OAuth2 client credentials, refreshing the token
/// a minute before expiry and once more on a 401 (as the firmware does).
/// Without credentials it calls the API anonymously, which works but has
/// much lower daily limits.
class OpenSkySource implements StateVectorSource {
  OpenSkySource({
    this.credentials,
    http.Client? client,
    DateTime Function()? clock,
    this.baseUrl = 'https://opensky-network.org',
    this.tokenUrl =
        'https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token',
  })  : _client = client ?? http.Client(),
        _now = clock ?? DateTime.now;

  final OpenSkyCredentials? credentials;
  final String baseUrl;
  final String tokenUrl;
  final http.Client _client;
  final DateTime Function() _now;

  static const _refreshSkew = Duration(seconds: 60);

  String? _token;
  DateTime? _tokenExpiry;

  @override
  Future<List<StateVector>> fetchNearby(LatLon center, double radiusKm) async {
    final box = BoundingBox.around(center, radiusKm);
    final uri = Uri.parse('$baseUrl/api/states/all').replace(queryParameters: {
      'lamin': box.latMin.toStringAsFixed(6),
      'lamax': box.latMax.toStringAsFixed(6),
      'lomin': box.lonMin.toStringAsFixed(6),
      'lomax': box.lonMax.toStringAsFixed(6),
    });

    var res = await _get(uri);
    if (res.statusCode == 401 && credentials != null) {
      await _ensureToken(forceRefresh: true);
      res = await _get(uri);
    }
    if (res.statusCode != 200) {
      throw ApiException('OpenSky', res.statusCode, res.body);
    }

    final json = jsonDecode(res.body);
    final states = json is Map<String, dynamic> ? json['states'] : null;
    if (states is! List) return const []; // no aircraft is not an error

    final result = <StateVector>[];
    for (final entry in states) {
      if (entry is! List) continue;
      final s = StateVector.fromOpenSkyArray(entry)?.withObserver(center);
      if (s == null || s.distanceKm! > radiusKm) continue;
      result.add(s);
    }
    return result;
  }

  Future<http.Response> _get(Uri uri) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (credentials != null) {
      await _ensureToken();
      headers['Authorization'] = 'Bearer $_token';
    }
    return _client.get(uri, headers: headers);
  }

  Future<void> _ensureToken({bool forceRefresh = false}) async {
    final expiry = _tokenExpiry;
    if (!forceRefresh &&
        _token != null &&
        expiry != null &&
        _now().add(_refreshSkew).isBefore(expiry)) {
      return;
    }
    final creds = credentials!;
    final res = await _client.post(
      Uri.parse(tokenUrl),
      headers: const {'Accept': 'application/json'},
      body: {
        'grant_type': 'client_credentials',
        'client_id': creds.clientId,
        'client_secret': creds.clientSecret,
      },
    );
    if (res.statusCode != 200) {
      throw ApiException('OpenSky auth', res.statusCode, res.body);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final token = json['access_token'];
    if (token is! String || token.isEmpty) {
      throw ApiException('OpenSky auth', res.statusCode, 'access_token missing');
    }
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 1800;
    _token = token;
    _tokenExpiry = _now().add(Duration(seconds: expiresIn));
  }
}
