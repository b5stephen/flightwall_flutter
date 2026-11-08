import 'flight_details.dart';
import 'state_vector.dart';

/// A nearby aircraft: its live position, plus route/aircraft details when
/// they could be looked up.
class Flight {
  const Flight({required this.state, this.details});

  final StateVector state;

  /// Null when no AeroAPI key is configured or the lookup failed.
  final FlightDetails? details;

  String get callsign => state.callsign;

  /// Best label for the flight: IATA flight number if known, else callsign,
  /// else the ICAO24 transponder address.
  String get label {
    final iata = details?.identIata;
    if (iata != null) return iata;
    if (callsign.isNotEmpty) return callsign;
    return state.icao24.toUpperCase();
  }
}
