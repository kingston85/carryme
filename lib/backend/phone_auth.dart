import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import 'backend.dart';

/// Firebase phone (SMS code) sign-in.
class PhoneAuth {
  String? _verificationId;
  int? _resendToken;

  bool get codeSent => _verificationId != null;

  /// Sends the SMS. [onAutoVerified] fires when Android reads the SMS by
  /// itself and signs the user in without typing the code.
  Future<void> sendCode(
    String phoneE164, {
    required void Function() onCodeSent,
    required void Function() onAutoVerified,
    required void Function(String message) onError,
  }) async {
    try {
      // Test numbers skip the Play Integrity / reCAPTCHA check.
      await Backend.auth.setSettings(
        appVerificationDisabledForTesting: AppConfig.testPhoneNumbers.contains(phoneE164),
      );
      await Backend.auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          try {
            await Backend.auth.signInWithCredential(credential);
            onAutoVerified();
          } on FirebaseAuthException catch (e) {
            onError(message(e));
          }
        },
        verificationFailed: (e) => onError(message(e)),
        codeSent: (id, token) {
          _verificationId = id;
          _resendToken = token;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } on FirebaseAuthException catch (e) {
      onError(message(e));
    } catch (e) {
      onError('Could not send the code: $e');
    }
  }

  /// Returns null on success, otherwise a message to show.
  Future<String?> verify(String code) async {
    final id = _verificationId;
    if (id == null) return 'The code has not been sent yet. Please wait a moment.';
    try {
      final credential = PhoneAuthProvider.credential(verificationId: id, smsCode: code.trim());
      await Backend.auth.signInWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      return message(e);
    } catch (e) {
      return 'Sign-in failed: $e';
    }
  }

  static String message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'That code is not correct. Try again.';
      case 'session-expired':
      case 'code-expired':
        return 'The code has expired. Tap "Resend code".';
      case 'invalid-phone-number':
        return 'That phone number is not valid.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while and try again.';
      case 'quota-exceeded':
        return 'SMS limit reached for today. Please try again later.';
      case 'billing-not-enabled':
        return 'SMS sign-in needs the Firebase Blaze plan (or use a test number set up in the Firebase console).';
      case 'operation-not-allowed':
        return 'Phone sign-in is not switched on in the Firebase console.';
      case 'app-not-authorized':
      case 'missing-client-identifier':
      case 'invalid-app-credential':
        return 'This app build is not registered with Firebase. Add its SHA-1 and SHA-256 fingerprints in the Firebase console.';
      case 'network-request-failed':
        return 'No internet connection. Check your data or Wi-Fi.';
      default:
        return e.message ?? 'Sign-in failed (${e.code}).';
    }
  }
}
