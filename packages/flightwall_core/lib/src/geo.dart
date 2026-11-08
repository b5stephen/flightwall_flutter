import 'dart:math' as math;

const double _earthRadiusKm = 6371.0;

double _toRadians(double deg) => deg * math.pi / 180.0;
double _toDegrees(double rad) => rad * 180.0 / math.pi;

/// A latitude/longitude pair in decimal degrees.
class LatLon {
  const LatLon(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is LatLon && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'LatLon($lat, $lon)';
}

/// An axis-aligned lat/lon box, as used by the OpenSky `states/all` query.
class BoundingBox {
  const BoundingBox({
    required this.latMin,
    required this.latMax,
    required this.lonMin,
    required this.lonMax,
  });

  /// Box of roughly [radiusKm] around [center] (same approximation as the
  /// firmware: 111 km per degree of latitude).
  factory BoundingBox.around(LatLon center, double radiusKm) {
    final latDelta = radiusKm / 111.0;
    final lonDelta = radiusKm / (111.0 * math.cos(_toRadians(center.lat)));
    return BoundingBox(
      latMin: center.lat - latDelta,
      latMax: center.lat + latDelta,
      lonMin: center.lon - lonDelta,
      lonMax: center.lon + lonDelta,
    );
  }

  final double latMin;
  final double latMax;
  final double lonMin;
  final double lonMax;
}

/// Great-circle distance in kilometres.
double haversineKm(LatLon a, LatLon b) {
  final dLat = _toRadians(b.lat - a.lat);
  final dLon = _toRadians(b.lon - a.lon);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_toRadians(a.lat)) *
          math.cos(_toRadians(b.lat)) *
          math.pow(math.sin(dLon / 2), 2);
  return _earthRadiusKm * 2 * math.asin(math.sqrt(h));
}

/// Initial bearing from [from] to [to], in degrees clockwise from north (0–360).
double bearingDeg(LatLon from, LatLon to) {
  final dLon = _toRadians(to.lon - from.lon);
  final lat1 = _toRadians(from.lat);
  final lat2 = _toRadians(to.lat);
  final x = math.sin(dLon) * math.cos(lat2);
  final y = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (_toDegrees(math.atan2(x, y)) + 360.0) % 360.0;
}
