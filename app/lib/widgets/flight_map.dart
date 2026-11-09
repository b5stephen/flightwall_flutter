import 'dart:math' as math;

import 'package:flightwall_core/flightwall_core.dart' hide LatLon;
import 'package:flightwall_core/flightwall_core.dart' as core show LatLon;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map of the watched area with each aircraft drawn at its position and
/// heading.
class FlightMap extends StatefulWidget {
  const FlightMap({
    super.key,
    required this.center,
    required this.radiusKm,
    required this.flights,
    required this.selected,
    required this.onSelect,
  });

  final core.LatLon center;
  final double radiusKm;
  final List<Flight> flights;
  final Flight? selected;
  final ValueChanged<Flight?> onSelect;

  @override
  State<FlightMap> createState() => _FlightMapState();
}

class _FlightMapState extends State<FlightMap> {
  final _map = MapController();
  bool _ready = false;

  LatLng get _center => LatLng(widget.center.lat, widget.center.lon);

  @override
  void didUpdateWidget(FlightMap old) {
    super.didUpdateWidget(old);
    if (_ready &&
        (old.center != widget.center || old.radiusKm != widget.radiusKm)) {
      _fit();
    }
  }

  CameraFit get _cameraFit {
    final box = BoundingBox.around(widget.center, widget.radiusKm);
    return CameraFit.bounds(
      bounds: LatLngBounds(
        LatLng(box.latMin, box.lonMin),
        LatLng(box.latMax, box.lonMax),
      ),
      padding: const EdgeInsets.all(24),
    );
  }

  void _fit() => _map.fitCamera(_cameraFit);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          // Must be the initial fit: calling fitCamera from onMapReady moves
          // the camera before TileLayer subscribes, so tiles are placed for
          // the old camera and end up off-screen.
          initialCameraFit: _cameraFit,
          backgroundColor: const Color(0xFF0B0E13),
          onMapReady: () => _ready = true,
          onTap: (_, __) => widget.onSelect(null),
        ),
        children: [
          // Standard OSM tiles, inverted and hue-rotated for a dark theme.
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.flightwall.app',
            tileBuilder: darkModeTileBuilder,
          ),
          CircleLayer(circles: [
            CircleMarker(
              point: _center,
              radius: widget.radiusKm * 1000,
              useRadiusInMeter: true,
              color: scheme.primary.withValues(alpha: 0.05),
              borderColor: scheme.primary.withValues(alpha: 0.5),
              borderStrokeWidth: 1.5,
            ),
          ]),
          MarkerLayer(markers: [
            Marker(
              point: _center,
              width: 16,
              height: 16,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            for (final f in widget.flights)
              Marker(
                point: LatLng(f.state.position.lat, f.state.position.lon),
                width: 120,
                height: 64,
                child: _PlaneMarker(
                  flight: f,
                  selected: widget.selected?.state.icao24 == f.state.icao24,
                  onTap: () => widget.onSelect(f),
                ),
              ),
          ]),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}

class _PlaneMarker extends StatelessWidget {
  const _PlaneMarker({
    required this.flight,
    required this.selected,
    required this.onTap,
  });

  final Flight flight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : Colors.white;
    final heading = flight.state.headingDeg ?? 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icons.flight points north, so heading maps directly to rotation.
          Transform.rotate(
            angle: heading * math.pi / 180,
            child: Icon(Icons.flight, size: selected ? 34 : 28, color: color),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              flight.label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
