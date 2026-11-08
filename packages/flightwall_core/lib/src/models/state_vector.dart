import '../geo.dart' show LatLon;
import '../geo.dart' as geo show bearingDeg, haversineKm;

/// A single aircraft position report from OpenSky (`states/all`).
///
/// Units follow OpenSky: metres, metres per second, degrees.
/// See https://openskynetwork.github.io/opensky-api/rest.html#all-state-vectors
class StateVector {
  const StateVector({
    required this.icao24,
    required this.callsign,
    required this.originCountry,
    required this.position,
    this.timePosition,
    this.lastContact,
    this.baroAltitudeM,
    this.onGround = false,
    this.velocityMps,
    this.headingDeg,
    this.verticalRateMps,
    this.geoAltitudeM,
    this.squawk,
    this.distanceKm,
    this.bearingDeg,
  });

  /// Parses one entry of the OpenSky `states` array.
  ///
  /// Returns null when the entry is malformed or has no position.
  static StateVector? fromOpenSkyArray(List<dynamic> a) {
    if (a.length < 17) return null;
    final lon = _toDouble(a[5]);
    final lat = _toDouble(a[6]);
    if (lat == null || lon == null) return null;
    return StateVector(
      icao24: (a[0] as String?) ?? '',
      callsign: ((a[1] as String?) ?? '').trim(),
      originCountry: (a[2] as String?) ?? '',
      timePosition: _toInt(a[3]),
      lastContact: _toInt(a[4]),
      position: LatLon(lat, lon),
      baroAltitudeM: _toDouble(a[7]),
      onGround: (a[8] as bool?) ?? false,
      velocityMps: _toDouble(a[9]),
      headingDeg: _toDouble(a[10]),
      verticalRateMps: _toDouble(a[11]),
      geoAltitudeM: _toDouble(a[13]),
      squawk: a[14] as String?,
    );
  }

  final String icao24;

  /// Trimmed callsign, e.g. `UAL245`. May be empty.
  final String callsign;
  final String originCountry;
  final LatLon position;

  /// Unix seconds of the last position update.
  final int? timePosition;

  /// Unix seconds of the last message of any kind.
  final int? lastContact;
  final double? baroAltitudeM;
  final bool onGround;
  final double? velocityMps;

  /// True track, degrees clockwise from north.
  final double? headingDeg;
  final double? verticalRateMps;
  final double? geoAltitudeM;
  final String? squawk;

  /// Distance from the observer; set by [withObserver].
  final double? distanceKm;

  /// Bearing from the observer; set by [withObserver].
  final double? bearingDeg;

  /// Best available altitude in metres (barometric, falling back to GPS).
  double? get altitudeM => baroAltitudeM ?? geoAltitudeM;

  /// Copy with distance and bearing computed relative to [observer].
  StateVector withObserver(LatLon observer) => StateVector(
        icao24: icao24,
        callsign: callsign,
        originCountry: originCountry,
        position: position,
        timePosition: timePosition,
        lastContact: lastContact,
        baroAltitudeM: baroAltitudeM,
        onGround: onGround,
        velocityMps: velocityMps,
        headingDeg: headingDeg,
        verticalRateMps: verticalRateMps,
        geoAltitudeM: geoAltitudeM,
        squawk: squawk,
        distanceKm: geo.haversineKm(observer, position),
        bearingDeg: geo.bearingDeg(observer, position),
      );
}

double? _toDouble(Object? v) => v is num ? v.toDouble() : null;
int? _toInt(Object? v) => v is num ? v.toInt() : null;
