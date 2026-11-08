import 'package:flightwall_app/flight_wall_controller.dart';
import 'package:flightwall_app/format.dart';
import 'package:flightwall_app/settings/settings.dart';
import 'package:flightwall_app/widgets/flight_list.dart';
import 'package:flightwall_core/flightwall_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryStore implements SettingsStore {
  MemoryStore([this.saved]);

  Settings? saved;

  @override
  Future<Settings?> load() async => saved;

  @override
  Future<void> save(Settings s) async => saved = s;
}

class FakePositions implements StateVectorSource {
  @override
  Future<List<StateVector>> fetchNearby(LatLon c, double r) async => [
        StateVector(
          icao24: 'a1',
          callsign: 'UAL245',
          originCountry: 'United States',
          position: c,
          baroAltitudeM: 3048,
          velocityMps: 128.6,
          verticalRateMps: -5.08,
          distanceKm: 2.4,
          bearingDeg: 90,
        ),
      ];
}

class FakeDetails implements FlightDetailsSource {
  @override
  Future<FlightDetails?> fetchDetails(String callsign) async =>
      const FlightDetails(
        identIata: 'UA245',
        airlineName: 'United Airlines',
        aircraftNameFull: 'Boeing 737-800',
        origin: Airport(codeIata: 'SFO', city: 'San Francisco'),
        destination: Airport(codeIata: 'ORD', city: 'Chicago'),
      );
}

FlightWallController controller(SettingsStore store) => FlightWallController(
      store: store,
      repositoryFactory: (s) => FlightRepository(
        positions: FakePositions(),
        details: FakeDetails(),
        center: s.center,
        radiusKm: s.radiusKm,
      ),
    );

void main() {
  group('format', () {
    test('aviation units', () {
      expect(formatAltitude(3048), '10,000 ft');
      expect(formatSpeed(128.6), '250 kt');
      expect(formatVerticalRate(-5.08), '▼ 1,000 ft/min');
      expect(formatVerticalRate(0.2), 'level');
      expect(formatBearing(90), 'E');
      expect(formatBearing(350), 'N');
      expect(formatAltitude(null), '—');
    });
  });

  group('controller', () {
    test('first launch has no settings and does not poll', () async {
      final c = controller(MemoryStore());
      await c.load();
      expect(c.loaded, isTrue);
      expect(c.settings, isNull);
      expect(c.isRunning, isFalse);
      c.dispose();
    });

    test('saved settings start polling and produce flights', () async {
      final c = controller(MemoryStore(Settings.defaults));
      await c.load();
      expect(c.isRunning, isTrue);
      await c.refresh();
      expect(c.flights.single.label, 'UA245');

      c.pause();
      expect(c.isRunning, isFalse);
      c.resume();
      expect(c.isRunning, isTrue);
      c.dispose();
    });

    test('saving settings persists them and resets selection', () async {
      final store = MemoryStore(Settings.defaults);
      final c = controller(store);
      await c.load();
      await c.refresh();
      c.select(c.flights.single);
      expect(c.selected, isNotNull);

      await c.save(Settings.defaults.copyWith(radiusKm: 25));
      expect(store.saved!.radiusKm, 25);
      expect(c.selected, isNull);
      c.dispose();
    });

    test('selecting the same flight twice deselects it', () async {
      final c = controller(MemoryStore(Settings.defaults));
      await c.load();
      await c.refresh();
      final f = c.flights.single;
      c.select(f);
      expect(c.selected?.label, 'UA245');
      c.select(f);
      expect(c.selected, isNull);
      c.dispose();
    });
  });

  testWidgets('flight card shows route, airline, aircraft and stats',
      (tester) async {
    final repo = FlightRepository(
      positions: FakePositions(),
      details: FakeDetails(),
      center: Settings.defaults.center,
      radiusKm: 10,
    );
    final snap = await tester.runAsync(repo.refresh);
    Flight? tapped;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: FlightList(
          flights: snap!.flights,
          selected: null,
          onSelect: (f) => tapped = f,
        ),
      ),
    ));

    expect(find.text('UA245'), findsOneWidget);
    expect(find.text('United Airlines'), findsOneWidget);
    expect(find.text('SFO'), findsOneWidget);
    expect(find.text('Chicago'), findsOneWidget);
    expect(find.text('Boeing 737-800'), findsOneWidget);
    expect(find.text('10,000 ft'), findsOneWidget);
    expect(find.text('2.4 km E'), findsOneWidget);

    await tester.tap(find.text('UA245'));
    expect(tapped?.label, 'UA245');
  });

  testWidgets('empty list and API-key hint', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FlightList(flights: const [], selected: null, onSelect: (_) {}),
      ),
    ));
    expect(find.text('No aircraft in range right now'), findsOneWidget);
  });
}
