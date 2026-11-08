/// Flight data layer for FlightWall displays.
///
/// Fetches nearby aircraft from OpenSky, enriches them with route and
/// aircraft details from FlightAware AeroAPI, and exposes the result as a
/// stream via [FlightRepository].
library;

export 'src/geo.dart';
export 'src/models/airport.dart';
export 'src/models/flight.dart';
export 'src/models/flight_details.dart';
export 'src/models/state_vector.dart';
export 'src/sources/aeroapi_source.dart';
export 'src/sources/display_name_source.dart';
export 'src/sources/flight_details_source.dart';
export 'src/sources/opensky_source.dart';
export 'src/sources/state_vector_source.dart';
export 'src/flight_repository.dart';
