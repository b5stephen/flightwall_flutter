import 'dart:async';

import 'package:flightwall_core/flightwall_core.dart';
import 'package:test/test.dart';

const center = LatLon(37.7749, -122.4194);

StateVector sv(String callsign, double km, {bool onGround = false}) =>
    StateVector(
      icao24: callsign.toLowerCase(),
      callsign: callsign,
      originCountry: 'US',
      position: center,
      onGround: onGround,
      distanceKm: km,
      bearingDeg: 0,
    );

class FakePositions implements StateVectorSource {
  List<StateVector> next = [];
  Object? error;
  int calls = 0;

  @override
  Future<List<StateVector>> fetchNearby(LatLon c, double r) async {
    calls++;
    if (error != null) throw error!;
    return next;
  }
}

class FakeDetails implements FlightDetailsSource {
  final calls = <String>[];
  final failFor = <String>{};

  @override
  Future<FlightDetails?> fetchDetails(String callsign) async {
    calls.add(callsign);
    if (failFor.contains(callsign)) throw Exception('boom');
    if (callsign == 'UNKNOWN') return null;
    return FlightDetails(
      identIata: '${callsign}_IATA',
      operatorIcao: 'UAL',
      aircraftType: 'B738',
    );
  }
}

class FakeNames implements DisplayNameSource {
  @override
  Future<String?> airlineName(String icao) async => 'United Airlines';

  @override
  Future<AircraftName?> aircraftName(String icao) async =>
      const AircraftName(short: '737-800', full: 'Boeing 737-800');
}

void main() {
  late FakePositions positions;
  late FakeDetails details;
  late DateTime now;

  FlightRepository repo({Duration ttl = const Duration(minutes: 30)}) =>
      FlightRepository(
        positions: positions,
        details: details,
        names: FakeNames(),
        center: center,
        radiusKm: 10,
        detailsTtl: ttl,
        clock: () => now,
      );

  setUp(() {
    positions = FakePositions();
    details = FakeDetails();
    now = DateTime(2026, 1, 1, 12);
  });

  test('sorts by distance, hides grounded aircraft, enriches names', () async {
    positions.next = [sv('FAR', 8), sv('NEAR', 2), sv('TAXI', 1, onGround: true)];
    final snap = await repo().refresh();

    expect(snap.error, isNull);
    expect(snap.flights.map((f) => f.callsign), ['NEAR', 'FAR']);
    final d = snap.flights.first.details!;
    expect(d.airlineName, 'United Airlines');
    expect(d.aircraftNameShort, '737-800');
    expect(snap.flights.first.label, 'NEAR_IATA');
  });

  test('caches details per callsign until the TTL expires', () async {
    final r = repo(ttl: const Duration(minutes: 10));
    positions.next = [sv('UAL1', 3), sv('UNKNOWN', 4)];

    await r.refresh();
    now = now.add(const Duration(minutes: 5));
    await r.refresh();
    expect(details.calls, ['UAL1', 'UNKNOWN']); // misses are cached too

    now = now.add(const Duration(minutes: 6));
    await r.refresh();
    expect(details.calls, ['UAL1', 'UNKNOWN', 'UAL1', 'UNKNOWN']);
  });

  test('a failed details lookup does not fail the poll and is retried',
      () async {
    final r = repo();
    details.failFor.add('BAD');
    positions.next = [sv('BAD', 3), sv('GOOD', 4)];

    final snap = await r.refresh();
    expect(snap.error, isNull);
    expect(snap.flights.map((f) => f.details != null), [false, true]);

    details.failFor.clear();
    final snap2 = await r.refresh();
    expect(snap2.flights.first.details, isNotNull);
    expect(details.calls.where((c) => c == 'BAD'), hasLength(2));
  });

  test('skips details lookup for empty callsigns', () async {
    positions.next = [sv('', 3)];
    final snap = await repo().refresh();
    expect(details.calls, isEmpty);
    expect(snap.flights.single.label, '');
  });

  test('works with no details source (positions only)', () async {
    positions.next = [sv('UAL1', 3)];
    final r = FlightRepository(
        positions: positions, center: center, radiusKm: 10);
    final snap = await r.refresh();
    expect(snap.flights.single.details, isNull);
    expect(snap.flights.single.label, 'UAL1');
  });

  test('position errors keep the last good list and report the error',
      () async {
    final r = repo();
    positions.next = [sv('UAL1', 3)];
    await r.refresh();

    positions.error = Exception('offline');
    final snap = await r.refresh();
    expect(snap.error, isA<Exception>());
    expect(snap.flights.map((f) => f.callsign), ['UAL1']);
  });

  test('concurrent refreshes share one in-flight poll', () async {
    positions.next = [sv('UAL1', 3)];
    final r = repo();
    final results = await Future.wait([r.refresh(), r.refresh()]);
    expect(positions.calls, 1);
    expect(results.map((s) => s.flights.length), [1, 1]);

    await r.refresh();
    expect(positions.calls, 2); // a new poll once the first finished
  });

  test('polls only while the stream has a listener', () async {
    final r = FlightRepository(
      positions: positions,
      center: center,
      radiusKm: 10,
      pollInterval: const Duration(milliseconds: 20),
    );
    expect(positions.calls, 0);

    final sub = r.snapshots.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await sub.cancel();
    final callsWhileListening = positions.calls;
    expect(callsWhileListening, greaterThanOrEqualTo(3));

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(positions.calls, callsWhileListening);
    await r.dispose();
  });
}
