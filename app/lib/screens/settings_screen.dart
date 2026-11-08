import 'package:flightwall_core/flightwall_core.dart';
import 'package:flutter/material.dart';

import '../flight_wall_controller.dart';
import '../settings/settings.dart';

/// Location, radius and the user's own API keys.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final FlightWallController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  late final TextEditingController _osId;
  late final TextEditingController _osSecret;
  late final TextEditingController _aero;
  late double _radiusKm;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings ?? Settings.defaults;
    _lat = TextEditingController(text: s.center.lat.toString());
    _lon = TextEditingController(text: s.center.lon.toString());
    _osId = TextEditingController(text: s.openSkyClientId);
    _osSecret = TextEditingController(text: s.openSkyClientSecret);
    _aero = TextEditingController(text: s.aeroApiKey);
    _radiusKm = s.radiusKm;
  }

  @override
  void dispose() {
    for (final c in [_lat, _lon, _osId, _osSecret, _aero]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.controller.save(Settings(
      center: LatLon(double.parse(_lat.text.trim()), double.parse(_lon.text.trim())),
      radiusKm: _radiusKm,
      openSkyClientId: _osId.text.trim(),
      openSkyClientSecret: _osSecret.text.trim(),
      aeroApiKey: _aero.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  String? _validateCoord(String? v, double limit) {
    final n = double.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter a number';
    if (n.abs() > limit) return 'Must be between -$limit and $limit';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Location', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _lat,
                            decoration: const InputDecoration(labelText: 'Latitude'),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            validator: (v) => _validateCoord(v, 90),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lon,
                            decoration: const InputDecoration(labelText: 'Longitude'),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                            validator: (v) => _validateCoord(v, 180),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Radius: ${_radiusKm.round()} km'),
                    Slider(
                      value: _radiusKm,
                      min: 2,
                      max: 50,
                      divisions: 48,
                      label: '${_radiusKm.round()} km',
                      onChanged: (v) => setState(() => _radiusKm = v),
                    ),
                    Text(
                      'A larger radius shows more aircraft but uses more AeroAPI '
                      'lookups.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 32),
                    Text('OpenSky (optional)', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Without credentials OpenSky is used anonymously and the '
                      'display refreshes every 90 seconds. With an API client '
                      'from opensky-network.org it refreshes every 30 seconds.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _osId,
                      decoration: const InputDecoration(labelText: 'Client ID'),
                      autocorrect: false,
                    ),
                    TextFormField(
                      controller: _osSecret,
                      decoration: const InputDecoration(labelText: 'Client secret'),
                      obscureText: true,
                      autocorrect: false,
                      validator: (v) =>
                          (_osId.text.trim().isEmpty) != (v?.trim().isEmpty ?? true)
                              ? 'Enter both the client ID and secret, or neither'
                              : null,
                    ),
                    const SizedBox(height: 32),
                    Text('FlightAware AeroAPI (optional)',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Adds airline, route and aircraft type. AeroAPI charges per '
                      'request; each aircraft is looked up once and cached for '
                      '30 minutes.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _aero,
                      decoration: const InputDecoration(labelText: 'API key'),
                      obscureText: true,
                      autocorrect: false,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keys are stored in this device\'s secure keystore and are '
                      'only sent to OpenSky and FlightAware.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
