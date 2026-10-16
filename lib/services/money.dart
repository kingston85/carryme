import 'package:intl/intl.dart';

import '../config/app_config.dart';

/// How prices are shown: Liberian dollars, US dollars, or both.
enum CurrencyPref { lrd, usd, both }

class Money {
  static final NumberFormat _whole = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _cents = NumberFormat('#,##0.00', 'en_US');

  static String lrd(double v) => 'L\$${_whole.format(v)}';

  static String usdValue(double v) => 'US\$${_cents.format(v)}';

  static double toUsd(double lrdAmount) => lrdAmount / AppConfig.lrdPerUsd;

  static String usdFromLrd(double lrdAmount) => usdValue(toUsd(lrdAmount));

  /// Main price label according to the user's preference.
  static String primary(double lrdAmount, CurrencyPref pref) =>
      pref == CurrencyPref.usd ? usdFromLrd(lrdAmount) : lrd(lrdAmount);

  /// Smaller second line (only when showing both currencies).
  static String? secondary(double lrdAmount, CurrencyPref pref) =>
      pref == CurrencyPref.both ? '≈ ${usdFromLrd(lrdAmount)}' : null;

  static String full(double lrdAmount, CurrencyPref pref) {
    final s = secondary(lrdAmount, pref);
    return s == null ? primary(lrdAmount, pref) : '${primary(lrdAmount, pref)} ($s)';
  }
}
