import 'dart:convert';

import 'package:flightwall_core/flightwall_core.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

Map<String, Object?> leg({
  String? actualOff,
  String? actualOn,
  String origin = 'KSFO',
}) =>
    {
      'ident': 'UAL245',
      'ident_icao': 'UAL245',
      'ident_iata': 'UA245',
      'operator': 'UAL',
      'operator_icao': 'UAL',
      'operator_iata': 'UA',
      'aircraft_type': 'B738',
      'registration': 'N12345',
      'actual_off': actualOff,
      'actual_on': actualOn,
      'origin': {
        'code_icao': origin,
        'code_iata': 'SFO',
        'name': 'San Francisco Intl',
        'city': 'San Francisco',
      },
      'destination': {'code_icao': 'KORD', 'code_iata': 'ORD', 'city': 'Chicago'},
    };

void main() {
  test('sends the API key and parses the flight', () async {
    late http.Request seen;
    final source = AeroApiSource(
      apiKey: 'key123',
      client: MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode({'flights': [leg()]}), 200);
      }),
    );

    final d = (await source.fetchDetails('UAL245'))!;

    expect(seen.headers['x-apikey'], 'key123');
    expect(seen.url.path, '/aeroapi/flights/UAL245');
    expect(d.identIata, 'UA245');
    expect(d.operatorIcao, 'UAL');
    expect(d.aircraftType, 'B738');
    expect(d.origin?.code, 'SFO');
    expect(d.origin?.city, 'San Francisco');
    expect(d.destination?.codeIcao, 'KORD');
  });

  test('prefers the airborne leg over earlier/later legs', () async {
    final source = AeroApiSource(
      apiKey: 'k',
      client: MockClient((_) async => http.Response(
          jsonEncode({
            'flights': [
              leg(origin: 'SCHEDULED'),
              leg(origin: 'AIRBORNE', actualOff: '2026-01-01T12:00:00Z'),
              leg(
                  origin: 'LANDED',
                  actualOff: '2026-01-01T08:00:00Z',
                  actualOn: '2026-01-01T10:00:00Z'),
            ]
          }),
          200)),
    );
    expect((await source.fetchDetails('UAL245'))!.origin?.codeIcao, 'AIRBORNE');
  });

  test('falls back to the first leg when none is airborne', () async {
    final source = AeroApiSource(
      apiKey: 'k',
      client: MockClient((_) async => http.Response(
          jsonEncode({'flights': [leg(origin: 'FIRST'), leg(origin: 'SECOND')]}),
          200)),
    );
    expect((await source.fetchDetails('X'))!.origin?.codeIcao, 'FIRST');
  });

  test('returns null for unknown flights', () async {
    final empty = AeroApiSource(
        apiKey: 'k',
        client: MockClient(
            (_) async => http.Response(jsonEncode({'flights': []}), 200)));
    final notFound = AeroApiSource(
        apiKey: 'k', client: MockClient((_) async => http.Response('', 404)));
    expect(await empty.fetchDetails('X'), isNull);
    expect(await notFound.fetchDetails('X'), isNull);
  });

  test('throws on auth errors', () async {
    final source = AeroApiSource(
        apiKey: 'bad', client: MockClient((_) async => http.Response('', 401)));
    expect(source.fetchDetails('X'), throwsA(isA<ApiException>()));
  });
}
