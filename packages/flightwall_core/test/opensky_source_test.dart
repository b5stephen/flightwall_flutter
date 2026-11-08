import 'dart:convert';

import 'package:flightwall_core/flightwall_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const center = LatLon(37.7749, -122.4194);

List<Object?> state({
  String icao = 'abc123',
  String? callsign = 'UAL245  ',
  double? lat = 37.78,
  double? lon = -122.42,
  bool onGround = false,
}) =>
    [
      icao, callsign, 'United States', 1700000000, 1700000001, //
      lon, lat, 3000.0, onGround, 200.0, 90.0, -2.5, null, 3050.0,
      '1200', false, 0,
    ];

http.Response statesResponse(List<Object?> states) => http.Response(
    jsonEncode({'time': 1700000001, 'states': states}), 200);

void main() {
  group('anonymous', () {
    test('parses, trims callsign, computes distance and bearing', () async {
      late http.Request seen;
      final source = OpenSkySource(
        client: MockClient((req) async {
          seen = req;
          return statesResponse([state()]);
        }),
      );

      final result = await source.fetchNearby(center, 10);

      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(seen.url.path, '/api/states/all');
      expect(seen.url.queryParameters.keys,
          containsAll(['lamin', 'lamax', 'lomin', 'lomax']));
      expect(result, hasLength(1));
      final s = result.single;
      expect(s.callsign, 'UAL245');
      expect(s.altitudeM, 3000.0);
      expect(s.verticalRateMps, -2.5);
      expect(s.distanceKm, closeTo(0.6, 0.2));
      expect(s.bearingDeg, isNotNull);
    });

    test('drops aircraft outside the radius (box corners)', () async {
      final source = OpenSkySource(
        client: MockClient(
            (_) async => statesResponse([state(lat: 37.86, lon: -122.53)])),
      );
      expect(await source.fetchNearby(center, 10), isEmpty);
    });

    test('skips entries with no position or too few fields', () async {
      final source = OpenSkySource(
        client: MockClient((_) async => statesResponse([
              state(lat: null),
              ['short', 'array'],
              state(icao: 'good'),
            ])),
      );
      final result = await source.fetchNearby(center, 10);
      expect(result.map((s) => s.icao24), ['good']);
    });

    test('null states means no aircraft', () async {
      final source = OpenSkySource(
        client: MockClient((_) async =>
            http.Response(jsonEncode({'time': 1, 'states': null}), 200)),
      );
      expect(await source.fetchNearby(center, 10), isEmpty);
    });

    test('throws ApiException on HTTP error', () async {
      final source = OpenSkySource(
        client: MockClient((_) async => http.Response('rate limited', 429)),
      );
      expect(source.fetchNearby(center, 10),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 429)));
    });
  });

  group('oauth', () {
    const creds = OpenSkyCredentials(clientId: 'id', clientSecret: 's&cret');

    test('fetches a token once and reuses it until near expiry', () async {
      var now = DateTime(2026, 1, 1, 12);
      var tokenCalls = 0;
      final source = OpenSkySource(
        credentials: creds,
        clock: () => now,
        client: MockClient((req) async {
          if (req.url.host == 'auth.opensky-network.org') {
            tokenCalls++;
            expect(req.bodyFields, {
              'grant_type': 'client_credentials',
              'client_id': 'id',
              'client_secret': 's&cret',
            });
            return http.Response(
                jsonEncode({'access_token': 'tok$tokenCalls', 'expires_in': 1800}),
                200);
          }
          expect(req.headers['Authorization'], 'Bearer tok$tokenCalls');
          return statesResponse([]);
        }),
      );

      await source.fetchNearby(center, 10);
      now = now.add(const Duration(minutes: 20));
      await source.fetchNearby(center, 10);
      expect(tokenCalls, 1);

      // Within 60 s of expiry → refresh.
      now = now.add(const Duration(minutes: 9, seconds: 30));
      await source.fetchNearby(center, 10);
      expect(tokenCalls, 2);
    });

    test('refreshes the token and retries once on 401', () async {
      var tokenCalls = 0;
      var stateCalls = 0;
      final source = OpenSkySource(
        credentials: creds,
        client: MockClient((req) async {
          if (req.url.host == 'auth.opensky-network.org') {
            tokenCalls++;
            return http.Response(
                jsonEncode({'access_token': 'tok$tokenCalls'}), 200);
          }
          stateCalls++;
          return stateCalls == 1
              ? http.Response('expired', 401)
              : statesResponse([state()]);
        }),
      );

      expect(await source.fetchNearby(center, 10), hasLength(1));
      expect(tokenCalls, 2);
      expect(stateCalls, 2);
    });

    test('throws when the token request fails', () async {
      final source = OpenSkySource(
        credentials: creds,
        client: MockClient((_) async => http.Response('bad client', 401)),
      );
      expect(source.fetchNearby(center, 10), throwsA(isA<ApiException>()));
    });
  });
}
