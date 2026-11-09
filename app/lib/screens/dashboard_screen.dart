import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../flight_wall_controller.dart';
import '../widgets/flight_list.dart';
import '../widgets/flight_map.dart';
import 'settings_screen.dart';

/// The main landscape tablet view: live map on the left, flight list on the
/// right.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final FlightWallController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final AppLifecycleListener _lifecycle;
  bool _promptedForSettings = false;

  FlightWallController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    // Keep the screen on like a wall display, and stop polling (and API
    // spend) whenever the app isn't in the foreground.
    WakelockPlus.enable();
    _lifecycle = AppLifecycleListener(
      onHide: _c.pause,
      onShow: _c.resume,
    );
    _c.addListener(_maybePromptForSettings);
    // Settings may have finished loading before this screen existed.
    _maybePromptForSettings();
  }

  @override
  void dispose() {
    _c.removeListener(_maybePromptForSettings);
    _lifecycle.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _maybePromptForSettings() {
    if (_promptedForSettings || !_c.loaded || _c.settings != null) return;
    _promptedForSettings = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _openSettings());
  }

  Future<void> _openSettings() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(controller: _c),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) {
            final settings = _c.settings;
            if (!_c.loaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (settings == null) {
              return Center(
                child: FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Set your location to get started'),
                ),
              );
            }
            return Column(
              children: [
                _StatusBar(controller: _c, onSettings: _openSettings),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: FlightMap(
                          center: settings.center,
                          radiusKm: settings.radiusKm,
                          flights: _c.flights,
                          selected: _c.selected,
                          onSelect: _c.select,
                        ),
                      ),
                      SizedBox(
                        width: 420,
                        child: FlightList(
                          flights: _c.flights,
                          selected: _c.selected,
                          onSelect: _c.select,
                          showDetailsHint: !settings.hasAeroApiKey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.onSettings});

  final FlightWallController controller;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = controller.snapshot;
    final count = controller.flights.length;
    final String status;
    if (snap == null) {
      status = 'Looking for aircraft…';
    } else if (snap.error != null) {
      status = 'Update failed — showing last data';
    } else {
      final t = TimeOfDay.fromDateTime(snap.fetchedAt).format(context);
      status = '$count aircraft overhead · updated $t';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.flight, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text('Flight Wall Flutter', style: theme.textTheme.titleLarge),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              status,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: snap?.error != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Refresh now',
            onPressed: controller.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}
