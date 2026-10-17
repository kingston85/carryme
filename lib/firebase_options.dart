// Firebase settings for CarryMe.
//
// This file is REPLACED automatically during the GitHub build when the
// GOOGLE_SERVICES_JSON secret is set (see FIREBASE_SETUP.md), or locally by
// running:  python3 tool/gen_firebase_options.py path/to/google-services.json
//
// While [FirebaseConfig.configured] is false the app runs in demo mode:
// drivers are simulated and the login code is 123456.

import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static const bool configured = false;
  static const FirebaseOptions? android = null;
}
