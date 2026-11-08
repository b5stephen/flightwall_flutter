/// Display formatting in aviation units (ft, kt, ft/min).
library;

String formatAltitude(double? metres) {
  if (metres == null) return '—';
  final ft = (metres * 3.28084).round();
  return '${_thousands(ft)} ft';
}

String formatSpeed(double? mps) {
  if (mps == null) return '—';
  return '${(mps * 1.94384).round()} kt';
}

String formatVerticalRate(double? mps) {
  if (mps == null) return '—';
  final fpm = (mps * 196.850).round();
  if (fpm.abs() < 100) return 'level';
  return '${fpm > 0 ? '▲' : '▼'} ${_thousands(fpm.abs())} ft/min';
}

String formatDistance(double? km) {
  if (km == null) return '—';
  return '${km.toStringAsFixed(1)} km';
}

String formatBearing(double? deg) {
  if (deg == null) return '';
  const points = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return points[((deg % 360) / 45).round() % 8];
}

String _thousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
