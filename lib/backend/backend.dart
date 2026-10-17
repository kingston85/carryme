import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Switches the app between LIVE mode (Firebase) and DEMO mode (everything
/// simulated on the phone). Live mode turns on automatically when
/// lib/firebase_options.dart has real settings and Firebase starts correctly.
class Backend {
  static bool _enabled = false;
  static String? startupError;

  static bool get enabled => _enabled;

  static Future<void> init() async {
    final options = FirebaseConfig.android;
    if (!FirebaseConfig.configured || options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      // Keep working on weak connections: reads come from the phone's cache
      // and writes are sent when the network returns.
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
      _enabled = true;
    } catch (e) {
      startupError = '$e';
      debugPrint('CarryMe: Firebase failed to start, using demo mode: $e');
    }
  }

  static FirebaseAuth get auth => FirebaseAuth.instance;
  static FirebaseFirestore get db => FirebaseFirestore.instance;

  /// The signed-in user's id, or null (always null in demo mode).
  static String? get uid => _enabled ? FirebaseAuth.instance.currentUser?.uid : null;
}
