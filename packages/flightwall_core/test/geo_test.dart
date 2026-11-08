import 'package:flightwall_core/flightwall_core.dart';
import 'package:test/test.dart';

void main() {
  const sf = LatLon(37.7749, -122.4194);
  const sfo = LatLon(37.6213, -122.3790);

  test('haversine SF city to SFO is ~17 km', () {
    expect(haversineKm(sf, sfo), closeTo(17.4, 0.3));
  });

  test('haversine of a point to itself is 0', () {
    expect(haversineKm(sf, sf), 0);
  });

  test('bearing to due north / east / south / west', () {
    const o = LatLon(0, 0);
    expect(bearingDeg(o, const LatLon(1, 0)), closeTo(0, 1e-9));
    expect(bearingDeg(o, const LatLon(0, 1)), closeTo(90, 1e-9));
    expect(bearingDeg(o, const LatLon(-1, 0)), closeTo(180, 1e-9));
    expect(bearingDeg(o, const LatLon(0, -1)), closeTo(270, 1e-9));
  });

  test('bounding box matches the firmware approximation', () {
    final box = BoundingBox.around(sf, 10);
    expect(box.latMax - sf.lat, closeTo(10 / 111.0, 1e-12));
    expect(box.lonMax - sf.lon, greaterThan(box.latMax - sf.lat));
    expect(box.latMin, lessThan(sf.lat));
    expect(box.lonMin, lessThan(sf.lon));
  });
}
