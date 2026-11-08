import 'package:flightwall_core/flightwall_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings: where to watch, and the user's own API keys.
class Settings {
  const Settings({
    required this.center,
    required this.radiusKm,
    this.openSkyClientId = '',
    this.openSkyClientSecret = '',
    this.aeroApiKey = '',
  });

  /// San Francisco, the firmware's example location.
  static const defaults = Settings(center: LatLon(37.7749, -122.4194), radiusKm: 10);

  final LatLon center;
  final double radiusKm;

  /// Optional. Without them OpenSky is used anonymously (lower daily limit).
  final String openSkyClientId;
  final String openSkyClientSecret;

  /// Optional. Without it flights show positions only, no route/aircraft.
  final String aeroApiKey;

  bool get hasOpenSkyCredentials =>
      openSkyClientId.isNotEmpty && openSkyClientSecret.isNotEmpty;
  bool get hasAeroApiKey => aeroApiKey.isNotEmpty;

  Settings copyWith({
    LatLon? center,
    double? radiusKm,
    String? openSkyClientId,
    String? openSkyClientSecret,
    String? aeroApiKey,
  }) =>
      Settings(
        center: center ?? this.center,
        radiusKm: radiusKm ?? this.radiusKm,
        openSkyClientId: openSkyClientId ?? this.openSkyClientId,
        openSkyClientSecret: openSkyClientSecret ?? this.openSkyClientSecret,
        aeroApiKey: aeroApiKey ?? this.aeroApiKey,
      );
}

/// Persists [Settings]: location in shared preferences, API keys in the
/// platform keystore (Keychain on iOS, Keystore-backed on Android).
abstract interface class SettingsStore {
  /// Saved settings, or null on first launch.
  Future<Settings?> load();
  Future<void> save(Settings settings);
}

class DeviceSettingsStore implements SettingsStore {
  DeviceSettingsStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _lat = 'center_lat';
  static const _lon = 'center_lon';
  static const _radius = 'radius_km';
  static const _osId = 'opensky_client_id';
  static const _osSecret = 'opensky_client_secret';
  static const _aero = 'aeroapi_key';

  @override
  Future<Settings?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_lat);
    final lon = prefs.getDouble(_lon);
    if (lat == null || lon == null) return null;
    return Settings(
      center: LatLon(lat, lon),
      radiusKm: prefs.getDouble(_radius) ?? Settings.defaults.radiusKm,
      openSkyClientId: await _secure.read(key: _osId) ?? '',
      openSkyClientSecret: await _secure.read(key: _osSecret) ?? '',
      aeroApiKey: await _secure.read(key: _aero) ?? '',
    );
  }

  @override
  Future<void> save(Settings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lat, s.center.lat);
    await prefs.setDouble(_lon, s.center.lon);
    await prefs.setDouble(_radius, s.radiusKm);
    await _secure.write(key: _osId, value: s.openSkyClientId);
    await _secure.write(key: _osSecret, value: s.openSkyClientSecret);
    await _secure.write(key: _aero, value: s.aeroApiKey);
  }
}
