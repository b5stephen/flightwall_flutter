import 'airport.dart';

/// Route, operator and aircraft details for a flight (from AeroAPI), plus
/// human-friendly names (from the FlightWall name lookup).
class FlightDetails {
  const FlightDetails({
    this.ident,
    this.identIcao,
    this.identIata,
    this.operatorCode,
    this.operatorIcao,
    this.operatorIata,
    this.aircraftType,
    this.registration,
    this.origin,
    this.destination,
    this.airlineName,
    this.aircraftNameShort,
    this.aircraftNameFull,
  });

  /// Parses one element of AeroAPI's `GET /flights/{ident}` `flights` array.
  factory FlightDetails.fromAeroApiJson(Map<String, dynamic> json) {
    Airport? airport(Object? v) =>
        v is Map<String, dynamic> ? Airport.fromAeroApiJson(v) : null;
    return FlightDetails(
      ident: _str(json['ident']),
      identIcao: _str(json['ident_icao']),
      identIata: _str(json['ident_iata']),
      operatorCode: _str(json['operator']),
      operatorIcao: _str(json['operator_icao']),
      operatorIata: _str(json['operator_iata']),
      aircraftType: _str(json['aircraft_type']),
      registration: _str(json['registration']),
      origin: airport(json['origin']),
      destination: airport(json['destination']),
    );
  }

  final String? ident;
  final String? identIcao;
  final String? identIata;
  final String? operatorCode;
  final String? operatorIcao;
  final String? operatorIata;

  /// ICAO aircraft type designator, e.g. `B738`.
  final String? aircraftType;
  final String? registration;
  final Airport? origin;
  final Airport? destination;

  /// e.g. `United Airlines`.
  final String? airlineName;

  /// e.g. `737-800`.
  final String? aircraftNameShort;

  /// e.g. `Boeing 737-800`.
  final String? aircraftNameFull;

  FlightDetails copyWith({
    String? airlineName,
    String? aircraftNameShort,
    String? aircraftNameFull,
  }) =>
      FlightDetails(
        ident: ident,
        identIcao: identIcao,
        identIata: identIata,
        operatorCode: operatorCode,
        operatorIcao: operatorIcao,
        operatorIata: operatorIata,
        aircraftType: aircraftType,
        registration: registration,
        origin: origin,
        destination: destination,
        airlineName: airlineName ?? this.airlineName,
        aircraftNameShort: aircraftNameShort ?? this.aircraftNameShort,
        aircraftNameFull: aircraftNameFull ?? this.aircraftNameFull,
      );
}

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
