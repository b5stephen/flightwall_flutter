import 'dart:async';

import 'package:flightwall_core/flightwall_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'settings/settings.dart';

/// Builds the data layer from [Settings] and exposes the latest snapshot.
class FlightWallController extends ChangeNotifier {
  FlightWallController({
    required SettingsStore store,
    http.Client? client,
    @visibleForTesting
    FlightRepository Function(Settings settings)? repositoryFactory,
  })  : _store = store,
        _client = client ?? http.Client() {
    _repositoryFactory = repositoryFactory ?? _defaultRepository;
  }

  final SettingsStore _store;
  final http.Client _client;
  late final FlightRepository Function(Settings) _repositoryFactory;
  late final _names = FlightWallCdnNameSource(client: _client);

  FlightRepository? _repository;
  StreamSubscription<FlightSnapshot>? _subscription;

  bool _loaded = false;
  Settings? _settings;
  FlightSnapshot? _snapshot;
  String? _selectedIcao24;

  /// False until [load] completes.
  bool get loaded => _loaded;

  /// Null until the user has saved settings once.
  Settings? get settings => _settings;
  FlightSnapshot? get snapshot => _snapshot;
  List<Flight> get flights => _snapshot?.flights ?? const [];
  bool get isRunning => _subscription != null;

  Flight? get selected {
    final id = _selectedIcao24;
    if (id == null) return null;
    for (final f in flights) {
      if (f.state.icao24 == id) return f;
    }
    return null;
  }

  Future<void> load() async {
    _settings = await _store.load();
    _loaded = true;
    if (_settings != null) _rebuild();
    notifyListeners();
  }

  Future<void> save(Settings settings) async {
    await _store.save(settings);
    _settings = settings;
    _snapshot = null;
    _selectedIcao24 = null;
    _rebuild();
    notifyListeners();
  }

  void select(Flight? flight) {
    final id = flight?.state.icao24;
    _selectedIcao24 = id == _selectedIcao24 ? null : id;
    notifyListeners();
  }

  /// Stops polling (and API usage), e.g. when the app is backgrounded.
  void pause() {
    _subscription?.cancel();
    _subscription = null;
    notifyListeners();
  }

  void resume() {
    final repo = _repository;
    if (repo == null || _subscription != null) return;
    _subscription = repo.snapshots.listen(_apply);
    notifyListeners();
  }

  Future<void> refresh() async {
    final repo = _repository;
    if (repo == null) return;
    final snap = await repo.refresh();
    if (identical(repo, _repository)) _apply(snap);
  }

  void _apply(FlightSnapshot snap) {
    _snapshot = snap;
    notifyListeners();
  }

  void _rebuild() {
    _subscription?.cancel();
    _subscription = null;
    unawaited(_repository?.dispose());
    _repository = _repositoryFactory(_settings!);
    resume();
  }

  FlightRepository _defaultRepository(Settings s) => FlightRepository(
        center: s.center,
        radiusKm: s.radiusKm,
        positions: OpenSkySource(
          client: _client,
          credentials: s.hasOpenSkyCredentials
              ? OpenSkyCredentials(
                  clientId: s.openSkyClientId,
                  clientSecret: s.openSkyClientSecret,
                )
              : null,
        ),
        details: s.hasAeroApiKey
            ? AeroApiSource(apiKey: s.aeroApiKey, client: _client)
            : null,
        names: _names,
        // Anonymous OpenSky allows far fewer requests per day.
        pollInterval: Duration(seconds: s.hasOpenSkyCredentials ? 30 : 90),
      );

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_repository?.dispose());
    _client.close();
    super.dispose();
  }
}
