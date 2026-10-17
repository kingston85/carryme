import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';

class Launch {
  static Future<void> open(BuildContext context, Uri uri, {String? failMessage}) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      showSnack(context, failMessage ?? 'Could not open that on this phone.');
    }
  }

  static Future<void> call(BuildContext context, String phone) =>
      open(context, Uri(scheme: 'tel', path: phone), failMessage: 'Could not start a call.');

  static Future<void> sms(BuildContext context, String phone, String body) => open(
        context,
        Uri.parse('sms:$phone?body=${Uri.encodeComponent(body)}'),
        failMessage: 'Could not open messages.',
      );

  /// WhatsApp share. [number] is optional, digits only with country code.
  static Future<void> whatsApp(BuildContext context, String text, {String number = ''}) => open(
        context,
        Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(text)}'),
        failMessage: 'WhatsApp is not installed.',
      );

  /// Turn-by-turn navigation in Google Maps (for drivers).
  static Future<void> navigate(BuildContext context, LatLng to) => open(
        context,
        Uri.parse('https://www.google.com/maps/dir/?api=1'
            '&destination=${to.latitude},${to.longitude}&travelmode=driving'),
        failMessage: 'Could not open navigation.',
      );
}
