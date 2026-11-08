# FlightWall for tablets

A landscape tablet dashboard showing the aircraft flying over your location:
a live map plus a closest-first list of flights with airline, route, aircraft
type, altitude and speed.

It's a companion to [TheFlightWall](https://github.com/AxisNimble/TheFlightWall_OSS),
an ESP32 LED wall. It uses the same data sources and logic as that project's
firmware, ported to Dart, with room for much more detail than an LED matrix
can show.

## Layout

```
packages/flightwall_core/   Pure Dart data layer (no Flutter): models, API clients, repository
app/                        Flutter tablet app (iOS + Android)
```

The two are linked with a [pub workspace](https://dart.dev/tools/pub/workspaces),
so one `flutter pub get` at the root resolves both.

### `flightwall_core`

| Firmware (C++)           | Dart                                  |
|--------------------------|---------------------------------------|
| `OpenSkyFetcher`         | `OpenSkySource` (anonymous or OAuth)  |
| `AeroAPIFetcher`         | `AeroApiSource`                       |
| `FlightWallFetcher`      | `FlightWallCdnNameSource`             |
| `FlightDataFetcher` + `loop()` | `FlightRepository` (a `Stream`) |
| `GeoUtils.h`             | `geo.dart`                            |

Differences from the firmware:

- **OpenSky works without keys.** Anonymous access has a lower daily limit,
  so the app polls every 90 s without credentials and every 30 s with them.
- **AeroAPI results are cached per callsign for 30 minutes**, including misses.
  The firmware looks up every plane on every poll, and AeroAPI bills per request.
- **The airborne leg is chosen.** `/flights/{ident}` returns several legs. The
  firmware takes the first, which can be yesterday's or tomorrow's flight.
- Lookups run in parallel, one failed lookup doesn't fail the whole poll,
  and TLS certificates are verified.
- Polling runs only while something listens to `FlightRepository.snapshots`.
  The app stops listening when it goes into the background.

Try it from the command line, no keys needed:

```bash
cd packages/flightwall_core
dart run example/main.dart 37.6213 -122.3790 25   # lat lon radiusKm
```

## The app

- Live map (OpenStreetMap tiles) with planes drawn at their position and
  heading, and the watched radius.
- Flight cards: flight number, airline, origin → destination with cities,
  aircraft, altitude, speed, vertical rate, distance and direction.
- Tap a plane or card to highlight it in both views.
- Locked to landscape, dark theme, screen kept awake.
- Settings: location, radius (2–50 km) and optional API keys. Keys are stored
  in the device keystore (Keychain on iOS, Keystore-backed on Android).

### API keys (all optional)

- **OpenSky API client**: faster refresh. Create one at
  opensky-network.org → Account → API client.
- **FlightAware AeroAPI key**: adds airline, route and aircraft type.
  Without it you get positions and callsigns only.

## Development

Requires Flutter 3.27+ (Dart 3.6+ for workspaces).

```bash
flutter pub get
(cd packages/flightwall_core && dart test)
(cd app && flutter test)
cd app && flutter run
```

## Caveats

- Airline and aircraft names come from `cdn.theflightwall.com`, TheFlightWall's
  own lookup server. It isn't a documented public API and could change.
- OpenStreetMap's tile servers are fine for personal use. A widely distributed
  app should switch to a tile provider that allows heavier traffic.
