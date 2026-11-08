import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'flight_wall_controller.dart';
import 'screens/dashboard_screen.dart';
import 'settings/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  final controller = FlightWallController(store: DeviceSettingsStore());
  runApp(FlightWallApp(controller: controller));
  await controller.load();
}

class FlightWallApp extends StatelessWidget {
  const FlightWallApp({super.key, required this.controller});

  final FlightWallController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlightWall',
      debugShowCheckedModeBanner: false,
      // A wall display runs all day: dark is easier on the room and on OLED.
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB300),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0E13),
        useMaterial3: true,
      ),
      home: DashboardScreen(controller: controller),
    );
  }
}
