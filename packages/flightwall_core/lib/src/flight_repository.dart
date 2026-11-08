import 'dart:async';

import 'geo.dart';
import 'models/flight.dart';
import 'models/flight_details.dart';
import 'sources/display_name_source.dart';
import 'sources/flight_details_source.dart';
import 'sources/state_vector_source.dart';

/// Result of one poll.
class FlightSnapshot {
  const FlightSnapshot({
    required this.flights,
    required this.fetchedAt,
    this.error,
  });

  /// Nearby flights, closest first. On error, the last good list.
  final List<Flight> flights;
  final DateTime fetchedAt;

  /// Set when the latest poll failed.
  final Object? error;
}

/// Polls for nearby aircraft and enriches them with details — the Dart
/// equivalent of the firmware's `FlightDataFetcher` plus its main loop.
///
/// Polling runs only while [snapshots] has a listener, so pausing the UI
/// (or cancelling the subscription at night) stops all API traffic.
class FlightRepository {
  FlightRepository({
    required StateVectorSource positions,
    required LatLon center,
    required double radiusKm,
    FlightDetailsSource? details,
    DisplayNameSource? names,
    this.pollInterval = const Duration(seconds: 30),
    this.detailsTtl = const Duration(minutes: 30),
    this.includeOnGround = false,
    DateTime Function()? clock,
  })  : _positions = positions,
        _details = details,
        _names = names,
        _center = center,
        _radiusKm = radiusKm,
        _now = clock ?? DateTime.now {
    _controller = StreamController<FlightSnapshot>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  final StateVectorSource _positions;
  final FlightDetailsSource? _details;
  final DisplayNameSource? _names;
  final DateTime Function() _now;

  /// How often to poll positions. OpenSky's free tiers make ~30 s sensible.
  final Duration pollInterval;

  /// How long a callsign's details are reused before AeroAPI is asked again.
  /// A plane crossing the area keeps its route, so this saves most calls.
  final Duration detailsTtl;

  /// Whether to include aircraft reporting `on_ground`.
  final bool includeOnGround;

  LatLon _center;
  double _radiusKm;
  late final StreamController<FlightSnapshot> _controller;
  Timer? _timer;
  Future<FlightSnapshot>? _inFlight;
  List<Flight> _last = const [];
  final _detailsCache = <String, _CacheEntry>{};

  /// Snapshots, one per poll. Listening starts polling immediately.
  Stream<FlightSnapshot> get snapshots => _controller.stream;

  LatLon get center => _center;
  double get radiusKm => _radiusKm;

  /// Changes the watched area and polls straight away if active.
  void updateArea({LatLon? center, double? radiusKm}) {
    _center = center ?? _center;
    _radiusKm = radiusKm ?? _radiusKm;
    if (_timer != null) unawaited(refresh());
  }

  /// Polls once now. Also used internally by the timer.
  ///
  /// If a poll is already in flight, returns that poll's result instead of
  /// starting another.
  Future<FlightSnapshot> refresh() => _inFlight ??= _poll().whenComplete(() {
        _inFlight = null;
      });

  Future<FlightSnapshot> _poll() async {
    try {
      final states = await _positions.fetchNearby(_center, _radiusKm);
      final visible = states
          .where((s) => includeOnGround || !s.onGround)
          .toList()
        ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));

      final flights = await Future.wait(visible.map((s) async =>
          Flight(state: s, details: await _detailsFor(s.callsign))));

      _last = flights;
      _pruneCache();
      final snap = FlightSnapshot(flights: flights, fetchedAt: _now());
      if (!_controller.isClosed) _controller.add(snap);
      return snap;
    } catch (e) {
      final snap = FlightSnapshot(flights: _last, fetchedAt: _now(), error: e);
      if (!_controller.isClosed) _controller.add(snap);
      return snap;
    }
  }

  Future<void> dispose() async {
    _stop();
    await _controller.close();
  }

  void _start() {
    unawaited(refresh());
    _timer = Timer.periodic(pollInterval, (_) => refresh());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<FlightDetails?> _detailsFor(String callsign) async {
    final source = _details;
    if (source == null || callsign.isEmpty) return null;

    final cached = _detailsCache[callsign];
    if (cached != null && _now().isBefore(cached.expires)) {
      return cached.details;
    }

    FlightDetails? details;
    try {
      details = await source.fetchDetails(callsign);
    } catch (_) {
      // One failed lookup shouldn't fail the whole poll. Not cached, so the
      // next poll retries.
      return cached?.details;
    }
    if (details != null) details = await _withNames(details);
    // Cache misses too: an unknown callsign won't become known in 30 s.
    _detailsCache[callsign] =
        _CacheEntry(details, _now().add(detailsTtl));
    return details;
  }

  Future<FlightDetails> _withNames(FlightDetails d) async {
    final names = _names;
    if (names == null) return d;
    final (airline, aircraft) = await (
      d.operatorIcao == null
          ? Future<String?>.value()
          : names.airlineName(d.operatorIcao!),
      d.aircraftType == null
          ? Future<AircraftName?>.value()
          : names.aircraftName(d.aircraftType!),
    ).wait;
    return d.copyWith(
      airlineName: airline,
      aircraftNameShort: aircraft?.short,
      aircraftNameFull: aircraft?.full,
    );
  }

  void _pruneCache() {
    final now = _now();
    _detailsCache.removeWhere((_, e) => now.isAfter(e.expires));
  }
}

class _CacheEntry {
  _CacheEntry(this.details, this.expires);

  final FlightDetails? details;
  final DateTime expires;
}
