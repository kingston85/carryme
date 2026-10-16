import 'package:carryme/config/app_config.dart';
import 'package:carryme/models/vehicle_type.dart';
import 'package:carryme/services/fare_service.dart';
import 'package:carryme/services/routing_service.dart';
import 'package:carryme/utils/phone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  final noon = DateTime(2026, 1, 15, 12);

  test('short trips pay at least the minimum fare', () {
    final q = FareService.quote(vehicle: VehicleType.keke, distanceKm: 0.3, durationMin: 1, when: noon);
    expect(q.total, greaterThanOrEqualTo(AppConfig.fares[VehicleType.keke]!.minimum));
  });

  test('fares are rounded to L\$5', () {
    final q = FareService.quote(vehicle: VehicleType.taxi, distanceKm: 7.3, durationMin: 23, when: noon);
    expect(q.total % 5, 0);
  });

  test('night and rain make the ride cost more', () {
    final day = FareService.quote(vehicle: VehicleType.taxi, distanceKm: 8, durationMin: 25, when: noon);
    final night = FareService.quote(vehicle: VehicleType.taxi, distanceKm: 8, durationMin: 25, when: DateTime(2026, 1, 15, 23));
    final rain = FareService.quote(vehicle: VehicleType.taxi, distanceKm: 8, durationMin: 25, when: noon, raining: true);
    expect(night.total, greaterThan(day.total));
    expect(rain.total, greaterThan(day.total));
  });

  test('shared taxi charges per seat', () {
    final one = FareService.quote(vehicle: VehicleType.sharedTaxi, distanceKm: 6, durationMin: 20, when: noon);
    final two = FareService.quote(vehicle: VehicleType.sharedTaxi, distanceKm: 6, durationMin: 20, when: noon, seats: 2);
    expect(two.total, greaterThan(one.total));
  });

  test('promo discount is capped', () {
    final full = FareService.quote(vehicle: VehicleType.comfort, distanceKm: 60, durationMin: 90, when: noon);
    final promo = FareService.quote(vehicle: VehicleType.comfort, distanceKm: 60, durationMin: 90, when: noon, promoRate: 0.5);
    expect(full.total - promo.total, lessThanOrEqualTo(AppConfig.maxPromoDiscountLrd + 5));
  });

  test('Liberian phone numbers are normalised', () {
    expect(LiberiaPhone.e164('0777 123 456'), '+231777123456');
    expect(LiberiaPhone.e164('+231 886 123 456'), '+231886123456');
    expect(LiberiaPhone.e164('12345'), isNull);
    expect(LiberiaPhone.network('0777123456'), 'Orange');
    expect(LiberiaPhone.network('0886123456'), 'Lonestar Cell MTN');
  });

  test('route resampling keeps the end points', () {
    final a = LatLng(6.30, -10.80);
    final b = LatLng(6.25, -10.70);
    final pts = RoutingService.resample([a, b], 10);
    expect(pts.length, 10);
    expect(pts.first.latitude, closeTo(a.latitude, 1e-9));
    expect(pts.last.longitude, closeTo(b.longitude, 1e-9));
  });

  test('pen-pen restricted zone covers central Monrovia', () {
    final zone = AppConfig.motorbikeRestrictedZones.first;
    expect(zone.contains(LatLng(6.3106, -10.8047)), isTrue); // Broad Street
    expect(zone.contains(LatLng(6.2440, -10.7040)), isFalse); // ELWA Junction
  });
}
