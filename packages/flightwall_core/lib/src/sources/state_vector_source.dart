import '../geo.dart';
import '../models/state_vector.dart';

/// Supplies live aircraft positions around a point.
abstract interface class StateVectorSource {
  /// Aircraft within [radiusKm] of [center], each with distance and bearing
  /// from [center] set. Throws on network or API errors.
  Future<List<StateVector>> fetchNearby(LatLon center, double radiusKm);
}
