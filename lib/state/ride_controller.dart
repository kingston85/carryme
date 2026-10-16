import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../data/mock_drivers.dart';
import '../models/driver.dart';
import '../models/payment.dart';
import '../models/place.dart';
import '../models/ride.dart';
import '../models/vehicle_type.dart';
import '../services/fare_service.dart';
import '../services/routing_service.dart';
import '../utils/geo.dart';

/// Rider booking flow: plan -> request -> driver assigned -> trip -> done.
///
/// DEMO MODE: the driver is simulated on the phone. To go live, replace
/// [requestRide] and the timers with calls to your backend (e.g. a Firestore
/// "rides" document that drivers listen to and update).
class RideController extends ChangeNotifier {
  final Random _rand = Random();

  // Planning
  Place? pickup;
  Place? destination;
  RouteResult? route;
  bool routing = false;
  VehicleType selected = VehicleType.keke;
  PaymentMethod payment = PaymentMethod.cashLrd;
  String? promoCode;
  double promoRate = 0;
  int seats = 1;
  DateTime? scheduledAt;
  String note = '';
  bool raining = false;

  // Live trip
  RideStatus? status;
  Driver? driver;
  LatLng? driverPos;
  int etaMin = 0;
  String pin = '0000';
  String rideId = '';
  RideRecord? completedRide;
  FareQuote? finalQuote;
  String? cancelReason;

  List<LatLng> _path = [];
  int _step = 0;
  Timer? _timer;

  bool get hasActiveRide =>
      status != null && status != RideStatus.completed && status != RideStatus.cancelled;

  bool get isAirportTrip {
    final pts = [pickup?.point, destination?.point].whereType<LatLng>();
    return pts.any((p) => kmBetween(p, AppConfig.riaAirport) < 2.5);
  }

  // ---------------------------------------------------------------- planning

  void startPlanning({
    required Place pickup,
    required Place destination,
    required PaymentMethod defaultPayment,
    required bool raining,
    VehicleType? preferred,
  }) {
    this.pickup = pickup;
    this.destination = destination;
    payment = defaultPayment;
    this.raining = raining;
    if (preferred != null) selected = preferred;
    seats = 1;
    scheduledAt = null;
    note = '';
    promoCode = null;
    promoRate = 0;
    route = null;
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final a = pickup;
    final b = destination;
    if (a == null || b == null) return;
    routing = true;
    notifyListeners();
    final r = await RoutingService.route(a.point, b.point);
    // Ignore if the user changed the trip while we were waiting.
    if (pickup != a || destination != b) return;
    route = r;
    routing = false;
    if (!isAllowed(selected)) {
      selected = VehicleType.values.firstWhere(isAllowed, orElse: () => VehicleType.taxi);
    }
    notifyListeners();
  }

  /// Why a vehicle can't be booked for this trip, or null if it can.
  String? restriction(VehicleType v) {
    final a = pickup;
    final b = destination;
    if (a == null || b == null) return null;
    final km = route?.distanceKm ?? kmBetween(a.point, b.point);
    if (v == VehicleType.penPen) {
      for (final z in AppConfig.motorbikeRestrictedZones) {
        if (z.contains(a.point) || z.contains(b.point)) {
          return 'Motorbikes not allowed in ${z.name}';
        }
      }
      if (km > AppConfig.penPenMaxKm) return 'Too far for a pen-pen';
    }
    if (v == VehicleType.keke && km > AppConfig.kekeMaxKm) {
      return 'Keke not available for long-distance trips';
    }
    return null;
  }

  bool isAllowed(VehicleType v) => restriction(v) == null;

  FareQuote? quoteFor(VehicleType v) {
    final r = route;
    if (r == null) return null;
    return FareService.quote(
      vehicle: v,
      distanceKm: r.distanceKm,
      durationMin: r.durationMin,
      when: scheduledAt,
      raining: raining,
      airport: isAirportTrip,
      promoRate: promoRate,
      seats: v == VehicleType.sharedTaxi ? seats : 1,
    );
  }

  /// Simulated "minutes away" for the nearest driver of each type.
  int pickupEtaFor(VehicleType v) => switch (v) {
        VehicleType.penPen => 2,
        VehicleType.keke => 3,
        VehicleType.sharedTaxi => 5,
        VehicleType.taxi => 4,
        VehicleType.comfort => 8,
      };

  void selectVehicle(VehicleType v) {
    selected = v;
    notifyListeners();
  }

  void setPayment(PaymentMethod m) {
    payment = m;
    notifyListeners();
  }

  void setSeats(int n) {
    seats = n < 1 ? 1 : (n > 3 ? 3 : n);
    notifyListeners();
  }

  void setSchedule(DateTime? t) {
    scheduledAt = t;
    notifyListeners();
  }

  void setNote(String n) {
    note = n.trim();
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  String? applyPromo(String code, {required bool firstRideDone}) {
    final c = code.trim().toUpperCase();
    final rate = AppConfig.promoCodes[c];
    if (rate == null) return 'That promo code is not valid.';
    if (c == 'WELCOME' && firstRideDone) return 'WELCOME is for your first ride only.';
    promoCode = c;
    promoRate = rate;
    notifyListeners();
    return null;
  }

  void removePromo() {
    promoCode = null;
    promoRate = 0;
    notifyListeners();
  }

  RideRecord scheduledRecord() {
    final q = quoteFor(selected);
    return RideRecord(
      id: 'SCH${DateTime.now().millisecondsSinceEpoch}',
      pickup: pickup!,
      destination: destination!,
      vehicle: selected,
      fareLrd: q?.total ?? 0,
      payment: payment,
      date: scheduledAt ?? DateTime.now(),
      status: 'scheduled',
      distanceKm: route?.distanceKm ?? 0,
      durationMin: route?.durationMin ?? 0,
      seats: seats,
    );
  }

  // ---------------------------------------------------------------- live ride

  void requestRide() {
    _timer?.cancel();
    final ms = DateTime.now().millisecondsSinceEpoch.toString();
    rideId = 'CM${ms.substring(ms.length - 7)}';
    pin = (1000 + _rand.nextInt(9000)).toString();
    status = RideStatus.searching;
    driver = null;
    driverPos = null;
    completedRide = null;
    finalQuote = quoteFor(selected);
    cancelReason = null;
    notifyListeners();
    _timer = Timer(Duration(seconds: 3 + _rand.nextInt(3)), _assignDriver);
  }

  void _assignDriver() {
    if (status != RideStatus.searching || pickup == null) return;
    driver = MockDrivers.pick(selected, _rand);
    final p = pickup!.point;
    final start = LatLng(
      p.latitude + (_rand.nextDouble() - 0.5) * 0.02,
      p.longitude + (_rand.nextDouble() - 0.5) * 0.02,
    );
    _path = RoutingService.resample([start, p], 24);
    _step = 0;
    driverPos = start;
    status = RideStatus.driverEnRoute;
    etaMin = pickupEtaFor(selected) + 1;
    notifyListeners();

    // Upgrade to a real road path if the routing server answers quickly.
    RoutingService.route(start, p).then((r) {
      if (status == RideStatus.driverEnRoute && _step < 3 && !r.isEstimate) {
        _path = RoutingService.resample(r.points, 24);
      }
    });

    _timer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _tick());
  }

  void _tick() {
    if (status == RideStatus.driverEnRoute) {
      _step++;
      if (_step >= _path.length) {
        _timer?.cancel();
        driverPos = pickup!.point;
        status = RideStatus.driverArrived;
        etaMin = 0;
        notifyListeners();
        // Simulates the driver entering the rider's PIN.
        _timer = Timer(const Duration(seconds: 8), _startTrip);
        return;
      }
      driverPos = _path[_step];
      etaMin = max(1, ((_path.length - _step) / 5).ceil());
      notifyListeners();
    } else if (status == RideStatus.inProgress) {
      _step++;
      if (_step >= _path.length) {
        _complete();
        return;
      }
      driverPos = _path[_step];
      final total = route?.durationMin ?? 10;
      etaMin = max(1, (total * (1 - _step / _path.length)).ceil());
      notifyListeners();
    }
  }

  void _startTrip() {
    if (status != RideStatus.driverArrived) return;
    final pts = route?.points ?? [pickup!.point, destination!.point];
    _path = RoutingService.resample(pts, 40);
    _step = 0;
    driverPos = _path.first;
    status = RideStatus.inProgress;
    etaMin = (route?.durationMin ?? 10).ceil();
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _complete() {
    _timer?.cancel();
    status = RideStatus.completed;
    driverPos = destination!.point;
    final q = finalQuote ?? quoteFor(selected);
    completedRide = RideRecord(
      id: rideId,
      pickup: pickup!,
      destination: destination!,
      vehicle: selected,
      fareLrd: q?.total ?? 0,
      payment: payment,
      date: DateTime.now(),
      status: 'completed',
      driverName: driver?.name ?? '',
      plate: driver?.plate ?? '',
      distanceKm: route?.distanceKm ?? 0,
      durationMin: route?.durationMin ?? 0,
      seats: seats,
    );
    notifyListeners();
  }

  void cancel(String reason) {
    _timer?.cancel();
    status = RideStatus.cancelled;
    cancelReason = reason;
    notifyListeners();
  }

  RideRecord cancelledRecord() => RideRecord(
        id: rideId,
        pickup: pickup!,
        destination: destination!,
        vehicle: selected,
        fareLrd: 0,
        payment: payment,
        date: DateTime.now(),
        status: 'cancelled',
        driverName: driver?.name ?? '',
        plate: driver?.plate ?? '',
      );

  String shareText() {
    final d = driver;
    final b = StringBuffer()
      ..write('I\'m on a CarryMe ${selected.label} ride from ${pickup?.name} to ${destination?.name}.');
    if (d != null) {
      b.write(' Driver: ${d.name}, ${d.colorName} ${d.vehicleDesc}, plate ${d.plate}.');
    }
    if (etaMin > 0) b.write(' ETA about $etaMin min.');
    b.write(' Trip ID $rideId.');
    return b.toString();
  }

  void clear() {
    _timer?.cancel();
    status = null;
    driver = null;
    driverPos = null;
    completedRide = null;
    finalQuote = null;
    cancelReason = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
