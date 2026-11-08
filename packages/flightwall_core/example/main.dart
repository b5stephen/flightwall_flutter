// Prints the aircraft currently near a location, using anonymous OpenSky.
//
//   dart run example/main.dart [lat] [lon] [radiusKm]
//
// Set AEROAPI_KEY in the environment to add routes and aircraft types.
import 'dart:io';

import 'package:flightwall_core/flightwall_core.dart';

Future<void> main(List<String> args) async {
  final lat = args.isNotEmpty ? double.parse(args[0]) : 37.6213; // SFO
  final lon = args.length > 1 ? double.parse(args[1]) : -122.3790;
  final radiusKm = args.length > 2 ? double.parse(args[2]) : 25.0;
  final aeroKey = Platform.environment['AEROAPI_KEY'] ?? '';

  final repo = FlightRepository(
    positions: OpenSkySource(),
    details: aeroKey.isEmpty ? null : AeroApiSource(apiKey: aeroKey),
    names: FlightWallCdnNameSource(),
    center: LatLon(lat, lon),
    radiusKm: radiusKm,
  );

  final snap = await repo.refresh();
  if (snap.error != null) {
    stderr.writeln('Error: ${snap.error}');
    exitCode = 1;
    return;
  }
  stdout.writeln('${snap.flights.length} aircraft within $radiusKm km:');
  for (final f in snap.flights) {
    final s = f.state;
    final d = f.details;
    final route = d == null
        ? ''
        : '  ${d.origin?.code ?? '?'} → ${d.destination?.code ?? '?'}'
            '  ${d.airlineName ?? ''} ${d.aircraftNameShort ?? d.aircraftType ?? ''}';
    final alt = s.altitudeM == null ? '—' : '${(s.altitudeM! * 3.28084).round()} ft';
    stdout.writeln('  ${f.label.padRight(8)} ${s.distanceKm!.toStringAsFixed(1).padLeft(5)} km'
        '  ${alt.padLeft(9)}$route');
  }
  await repo.dispose();
  exit(0);
}
