/// An airport as returned by AeroAPI.
class Airport {
  const Airport({
    this.codeIcao,
    this.codeIata,
    this.name,
    this.city,
  });

  factory Airport.fromAeroApiJson(Map<String, dynamic> json) => Airport(
        codeIcao: _nonEmpty(json['code_icao']),
        codeIata: _nonEmpty(json['code_iata']),
        name: _nonEmpty(json['name']),
        city: _nonEmpty(json['city']),
      );

  final String? codeIcao;
  final String? codeIata;
  final String? name;
  final String? city;

  /// Short code for display, preferring IATA (`SFO`) over ICAO (`KSFO`).
  String? get code => codeIata ?? codeIcao;
}

String? _nonEmpty(Object? v) => v is String && v.isNotEmpty ? v : null;
