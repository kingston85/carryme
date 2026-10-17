import 'package:latlong2/latlong.dart';

import '../models/vehicle_type.dart';
import '../utils/geo.dart';

/// Pricing rule for one vehicle type. All amounts in Liberian dollars (L$).
class FareRule {
  final double base;
  final double perKm;
  final double perMin;
  final double minimum;

  const FareRule({
    required this.base,
    required this.perKm,
    required this.perMin,
    required this.minimum,
  });
}

/// An area where a vehicle type is not allowed to pick up or drop off.
class RestrictedZone {
  final String name;
  final LatLng center;
  final double radiusKm;

  RestrictedZone({required this.name, required this.center, required this.radiusKm});

  bool contains(LatLng p) => kmBetween(center, p) <= radiusKm;
}

/// ---------------------------------------------------------------------------
/// ALL BUSINESS SETTINGS LIVE HERE.
/// Before launch, replace these with values loaded from your backend so you can
/// change prices, the exchange rate and zones without publishing a new app.
/// ---------------------------------------------------------------------------
class AppConfig {
  static const String appName = 'CarryMe';
  static const String tagline = 'Moving Liberia, one ride at a time';
  static const String packageId = 'lr.carryme.carryme';

  /// Exchange rate used to show US$ equivalents. PLACEHOLDER - set daily.
  static const double lrdPerUsd = 190.0;

  static final LatLng monroviaCenter = LatLng(6.3005, -10.7969);
  static final LatLng riaAirport = LatLng(6.2338, -10.3623);

  /// OSRM durations assume free-flowing roads; Monrovia traffic is slower.
  static const double trafficFactor = 1.6;

  /// Used when no road route is available (offline / API down).
  static const double avgCitySpeedKmh = 22.0;
  static const double roadDetourFactor = 1.35;

  /// Platform commission taken from each driver fare.
  static const double commissionRate = 0.15;

  /// Surcharges (fractions of the fare).
  static const double rainSurcharge = 0.20; // rainy-season downpours
  static const double nightSurcharge = 0.15;
  static const int nightStartHour = 22;
  static const int nightEndHour = 5;

  /// Flat fee added when a trip starts or ends at Roberts International Airport.
  static const double airportFeeLrd = 500.0;

  static const double maxPromoDiscountLrd = 500.0;

  /// Verify the national emergency line before launch.
  static const String emergencyNumber = '911';
  static const String supportPhone = '+231770000000'; // TODO: your support line
  static const String supportWhatsApp = '231770000000'; // TODO: your WhatsApp

  /// Demo-only OTP. Replace with real SMS verification (e.g. Firebase Auth).
  static const String demoOtp = '123456';

  /// Map + routing providers. The public OSM / OSRM / Nominatim servers are
  /// fine for testing; use a paid or self-hosted provider in production.
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osrmBase = 'https://router.project-osrm.org';
  static const String nominatimBase = 'https://nominatim.openstreetmap.org';

  /// Fares in L$. PLACEHOLDERS - set these from your market research.
  static const Map<VehicleType, FareRule> fares = {
    VehicleType.penPen: FareRule(base: 50, perKm: 35, perMin: 3, minimum: 100),
    VehicleType.keke: FareRule(base: 75, perKm: 45, perMin: 4, minimum: 150),
    VehicleType.sharedTaxi: FareRule(base: 60, perKm: 30, perMin: 2, minimum: 100),
    VehicleType.taxi: FareRule(base: 200, perKm: 90, perMin: 8, minimum: 400),
    VehicleType.comfort: FareRule(base: 500, perKm: 180, perMin: 15, minimum: 1200),
  };

  /// Motorbike (pen-pen) restrictions. Adjust to current government rules.
  static final List<RestrictedZone> motorbikeRestrictedZones = [
    RestrictedZone(
      name: 'Central Monrovia',
      center: LatLng(6.3100, -10.8040),
      radiusKm: 1.8,
    ),
  ];

  /// Longest trip each small vehicle can take.
  static const double penPenMaxKm = 40;
  static const double kekeMaxKm = 40;

  static const Map<String, double> promoCodes = {
    'WELCOME': 0.20,
    'KEKE10': 0.10,
    'RAINYDAY': 0.15,
  };

  static const Map<String, String> promoDescriptions = {
    'WELCOME': '20% off your first ride (up to L\$500)',
    'KEKE10': '10% off any ride this month',
    'RAINYDAY': '15% off when the rain is falling',
  };
}
