import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'backend/backend.dart';
import 'state/app_state.dart';
import 'state/driver_controller.dart';
import 'state/ride_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Live mode if Firebase is configured, otherwise demo mode.
  await Backend.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..load()),
        ChangeNotifierProvider(create: (_) => RideController()),
        ChangeNotifierProvider(create: (_) => DriverController()),
      ],
      child: const CarryMeApp(),
    ),
  );
}
