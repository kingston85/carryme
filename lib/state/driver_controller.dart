import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/liberia_places.dart';
import '../data/mock_drivers.dart';
import '../models/payment.dart';
import '../models/place.dart';
import '../models/vehicle_type.dart';
import '../services/fare_service.dart';
import '../utils/geo.dart';

enum DriverStage { idle, incoming, toPickup, atPickup, onTrip }

class DriverJob {
  final String riderName;
  final double riderRating;
  final Place pickup;
  final Place destination;
  final VehicleType vehicle;
  final double fareLrd;
  final double distanceKm;
  final double pickupKm;
  final PaymentMethod payment;
  final String pin;

  const DriverJob({
    required this.riderName,
    required this.riderRating,
    required this.pickup,
    required this.destination,
    required this.vehicle,
    required this.fareLrd,
    required this.distanceKm,
    required this.pickupKm,
    required this.payment,
    required this.pin,
  });
}

class DriverTrip {
  final DriverJob job;
  final DateTime date;
  final double fareLrd;
  final double commissionLrd;

  const DriverTrip({
    required this.job,
    required this.date,
    required this.fareLrd,
    required this.commissionLrd,
  });

  double get earningLrd => fareLrd - commissionLrd;
}

/// Driver side. DEMO MODE: ride offers are generated on the phone.
/// In production, offers arrive from your backend's dispatch service.
class DriverController extends ChangeNotifier {
  final Random _rand = Random();

  bool online = false;
  DriverStage stage = DriverStage.idle;
  DriverJob? job;
  int countdown = 0;
  static const int offerSeconds = 15;

  VehicleType vehicle = VehicleType.taxi;
  String vehicleModel = 'Toyota Corolla';
  String plate = 'TX-0000';
  double paidOutLrd = 0;

  final List<DriverTrip> trips = [];

  Timer? _offerTimer;
  Timer? _countdownTimer;

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  List<DriverTrip> get todayTrips => trips.where((t) => _isToday(t.date)).toList();

  double get todayEarnings => todayTrips.fold<double>(0.0, (a, t) => a + t.earningLrd);

  double get weekEarnings {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return trips.where((t) => t.date.isAfter(cutoff)).fold<double>(0.0, (a, t) => a + t.earningLrd);
  }

  double get totalEarnings => trips.fold<double>(0.0, (a, t) => a + t.earningLrd);

  double get availableBalance => max(0.0, totalEarnings - paidOutLrd);

  void setVehicle({required VehicleType type, required String model, required String plateNo}) {
    vehicle = type;
    vehicleModel = model;
    plate = plateNo;
    notifyListeners();
  }

  void toggleOnline() {
    online = !online;
    if (online) {
      _scheduleOffer();
    } else {
      _offerTimer?.cancel();
      if (stage == DriverStage.incoming) {
        _countdownTimer?.cancel();
        stage = DriverStage.idle;
        job = null;
      }
    }
    notifyListeners();
  }

  void _scheduleOffer() {
    _offerTimer?.cancel();
    _offerTimer = Timer(Duration(seconds: 5 + _rand.nextInt(7)), _offer);
  }

  void _offer() {
    if (!online || stage != DriverStage.idle) return;
    final places = LiberiaPlaces.monrovia;
    if (places.length < 2) return;
    final a = places[_rand.nextInt(places.length)];
    var b = places[_rand.nextInt(places.length)];
    while (b.name == a.name) {
      b = places[_rand.nextInt(places.length)];
    }
    final km = kmBetween(a.point, b.point) * AppConfig.roadDetourFactor;
    final minutes = km / AppConfig.avgCitySpeedKmh * 60;
    final quote = FareService.quote(vehicle: vehicle, distanceKm: km, durationMin: minutes);
    final payments = PaymentMethod.values;
    job = DriverJob(
      riderName: MockDrivers.riderNames[_rand.nextInt(MockDrivers.riderNames.length)],
      riderRating: 4.5 + _rand.nextInt(6) / 10,
      pickup: a,
      destination: b,
      vehicle: vehicle,
      fareLrd: quote.total,
      distanceKm: km,
      pickupKm: 0.4 + _rand.nextInt(20) / 10,
      payment: payments[_rand.nextInt(payments.length)],
      pin: (1000 + _rand.nextInt(9000)).toString(),
    );
    stage = DriverStage.incoming;
    countdown = offerSeconds;
    notifyListeners();
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      countdown--;
      if (countdown <= 0) {
        t.cancel();
        decline();
      } else {
        notifyListeners();
      }
    });
  }

  void accept() {
    _countdownTimer?.cancel();
    stage = DriverStage.toPickup;
    notifyListeners();
  }

  void decline() {
    _countdownTimer?.cancel();
    job = null;
    stage = DriverStage.idle;
    notifyListeners();
    if (online) _scheduleOffer();
  }

  void arrived() {
    stage = DriverStage.atPickup;
    notifyListeners();
  }

  /// Rider tells the driver their 4-digit PIN; returns false if wrong.
  bool startTrip(String enteredPin) {
    if (job == null || enteredPin.trim() != job!.pin) return false;
    stage = DriverStage.onTrip;
    notifyListeners();
    return true;
  }

  DriverTrip completeTrip() {
    final j = job!;
    final trip = DriverTrip(
      job: j,
      date: DateTime.now(),
      fareLrd: j.fareLrd,
      commissionLrd: FareService.round5(j.fareLrd * AppConfig.commissionRate),
    );
    trips.insert(0, trip);
    job = null;
    stage = DriverStage.idle;
    notifyListeners();
    if (online) _scheduleOffer();
    return trip;
  }

  void cancelJob() {
    job = null;
    stage = DriverStage.idle;
    notifyListeners();
    if (online) _scheduleOffer();
  }

  void cashOut(double amount) {
    paidOutLrd += amount;
    notifyListeners();
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
