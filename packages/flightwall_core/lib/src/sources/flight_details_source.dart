import '../models/flight_details.dart';

/// Looks up route, operator and aircraft details for a callsign.
abstract interface class FlightDetailsSource {
  /// Details for [callsign], or null if the flight is unknown.
  /// Throws on network or API errors.
  Future<FlightDetails?> fetchDetails(String callsign);
}
