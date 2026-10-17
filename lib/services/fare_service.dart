import 'dart:math';

import '../config/app_config.dart';
import '../models/vehicle_type.dart';

class FareLine {
  final String label;
  final double amount;
  const FareLine(this.label, this.amount);
}

class FareQuote {
  final VehicleType vehicle;
  final double distanceKm;
  final double durationMin;
  final double base;
  final double distanceCharge;
  final double timeCharge;
  final List<FareLine> extras;
  final double discount;
  final int seats;
  final double total;

  const FareQuote({
    required this.vehicle,
    required this.distanceKm,
    required this.durationMin,
    required this.base,
    required this.distanceCharge,
    required this.timeCharge,
    required this.extras,
    required this.discount,
    required this.seats,
    required this.total,
  });

  bool get hasSurcharge => extras.any((e) => e.amount > 0 && !e.label.startsWith('Minimum'));
}

class FareService {
  /// Round up to the nearest L$5 - easy to pay in cash.
  static double round5(double v) => (v / 5).ceil() * 5.0;

  static bool isNight(DateTime t) =>
      t.hour >= AppConfig.nightStartHour || t.hour < AppConfig.nightEndHour;

  static FareQuote quote({
    required VehicleType vehicle,
    required double distanceKm,
    required double durationMin,
    DateTime? when,
    bool raining = false,
    bool airport = false,
    double promoRate = 0,
    int seats = 1,
  }) {
    final rule = AppConfig.fares[vehicle]!;
    final base = rule.base;
    final dist = rule.perKm * distanceKm;
    final time = rule.perMin * durationMin;
    final extras = <FareLine>[];

    var sub = base + dist + time;
    if (sub < rule.minimum) {
      extras.add(FareLine('Minimum fare top-up', rule.minimum - sub));
      sub = rule.minimum;
    }

    final t = when ?? DateTime.now();
    if (isNight(t)) {
      extras.add(FareLine('Night fare (+${(AppConfig.nightSurcharge * 100).round()}%)',
          sub * AppConfig.nightSurcharge));
    }
    if (raining) {
      extras.add(FareLine('Rain surcharge (+${(AppConfig.rainSurcharge * 100).round()}%)',
          sub * AppConfig.rainSurcharge));
    }
    if (airport) {
      extras.add(const FareLine('Airport access', AppConfig.airportFeeLrd));
    }

    final int seatCount =
        vehicle == VehicleType.sharedTaxi ? (seats < 1 ? 1 : (seats > 3 ? 3 : seats)) : 1;
    var total = (sub + extras.fold<double>(0.0, (a, e) => e.label.startsWith('Minimum') ? a : a + e.amount)) *
        seatCount;

    final discount = promoRate > 0 ? min(total * promoRate, AppConfig.maxPromoDiscountLrd) : 0.0;
    total = round5(max(0.0, total - discount));

    return FareQuote(
      vehicle: vehicle,
      distanceKm: distanceKm,
      durationMin: durationMin,
      base: base,
      distanceCharge: dist,
      timeCharge: time,
      extras: extras,
      discount: discount,
      seats: seatCount,
      total: total,
    );
  }
}
