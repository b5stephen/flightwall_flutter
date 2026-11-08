import 'package:flightwall_core/flightwall_core.dart';
import 'package:flutter/material.dart';

import '../format.dart';

/// Closest-first list of flight cards.
class FlightList extends StatelessWidget {
  const FlightList({
    super.key,
    required this.flights,
    required this.selected,
    required this.onSelect,
    this.showDetailsHint = false,
  });

  final List<Flight> flights;
  final Flight? selected;
  final ValueChanged<Flight?> onSelect;

  /// Show a hint that adding an AeroAPI key unlocks routes.
  final bool showDetailsHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (flights.isEmpty) {
      return Center(
        child: Text(
          'No aircraft in range right now',
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 16),
      children: [
        if (showDetailsHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Add a FlightAware AeroAPI key in Settings to see airlines, '
              'routes and aircraft types.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        for (final f in flights)
          FlightCard(
            flight: f,
            selected: selected?.state.icao24 == f.state.icao24,
            onTap: () => onSelect(f),
          ),
      ],
    );
  }
}

class FlightCard extends StatelessWidget {
  const FlightCard({
    super.key,
    required this.flight,
    required this.selected,
    required this.onTap,
  });

  final Flight flight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = flight.details;
    final s = flight.state;
    final muted = theme.textTheme.bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant);

    final airline = d?.airlineName;
    final aircraft = d?.aircraftNameFull ?? d?.aircraftNameShort ?? d?.aircraftType;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    flight.label,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      airline ?? s.originCountry,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${formatDistance(s.distanceKm)} ${formatBearing(s.bearingDeg)}',
                    style: muted,
                  ),
                ],
              ),
              if (d?.origin != null || d?.destination != null) ...[
                const SizedBox(height: 10),
                _Route(origin: d!.origin, destination: d.destination),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  if (aircraft != null) _Stat(Icons.airplanemode_active, aircraft),
                  _Stat(Icons.height, formatAltitude(s.altitudeM)),
                  _Stat(Icons.speed, formatSpeed(s.velocityMps)),
                  _Stat(Icons.swap_vert, formatVerticalRate(s.verticalRateMps)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Route extends StatelessWidget {
  const _Route({required this.origin, required this.destination});

  final Airport? origin;
  final Airport? destination;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _AirportLabel(origin)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        Expanded(child: _AirportLabel(destination, alignEnd: true)),
      ],
    );
  }
}

class _AirportLabel extends StatelessWidget {
  const _AirportLabel(this.airport, {this.alignEnd = false});

  final Airport? airport;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          airport?.code ?? '—',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
        Text(
          airport?.city ?? airport?.name ?? '',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}
