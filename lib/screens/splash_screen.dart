import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 56, light: true),
            const SizedBox(height: 14),
            Text(AppConfig.tagline, style: TextStyle(color: Colors.white.withAlpha(210), fontSize: 14)),
            const SizedBox(height: 44),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
