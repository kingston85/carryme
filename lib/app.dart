import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/rider/rider_home_screen.dart';
import 'screens/splash_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

class CarryMeApp extends StatelessWidget {
  const CarryMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const RootGate(),
    );
  }
}

/// Picks the first screen from the saved state. Logging in or out, or switching
/// between rider and driver mode, rebuilds this automatically.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.loaded) return const SplashScreen();
    if (app.user == null) {
      return app.onboarded ? const LoginScreen() : const OnboardingScreen();
    }
    return app.mode == AppMode.driver ? const DriverHomeScreen() : const RiderHomeScreen();
  }
}
