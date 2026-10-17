import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../backend/backend.dart';
import '../backend/firestore_api.dart';
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
  final String id; // Firestore ride id ('' in demo mode)
  final String riderName;
  final String riderPhone;
  final double riderRating;
  final Place pickup;
  final Place destination;
  final VehicleType vehicle;
  final double fareLrd;
  final double distanceKm;
  final double pickupKm;
  final PaymentMethod payment;
  final String pin; // known only in demo mode
  final String note;
  final int seats;

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
    this.id = '',
    this.riderPhone = '',
    this.note = '',
    this.seats = 1,
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

/// Driver side.
/// LIVE MODE: watches Firestore for open requests that match the driver's
/// vehicle, claims them with a transaction and updates the ride as it goes.
/// DEMO MODE: ride offers are generated on the phone.
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
  String colorName = 'Yellow';
  double paidOutLrd = 0;

  final List<DriverTrip> trips = [];

  /// Live mode: the driver's Firestore record (null until loaded).
  DriverProfile? profile;
  bool profileLoading = false;

  /// One-off message for the screen to show (e.g. "Rider cancelled").
  String? notice;

  Timer? _offerTimer;
  Timer? _countdownTimer;

  // Live mode internals
  String? _attachedUid;
  StreamSubscription<dynamic>? _profileSub;
  StreamSubscription<dynamic>? _requestsSub;
  StreamSubscription<dynamic>? _rideSub;
  StreamSubscription<Position>? _gpsSub;
  LatLng? myPos;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _declined = {};
  List<Map<String, dynamic>> _openRequests = [];

  bool get live => Backend.enabled;

  /// Demo drivers are always approved; live drivers wait for you to set
  /// `approved: true` on their record in the Firebase console.
  bool get approved => !live || (profile?.approved ?? false);

  double get rating => live ? (profile?.rating ?? 5.0) : 4.9;

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

  void clearNotice() => notice = null;

  // ------------------------------------------------------------ profile

  /// Called when the driver screen opens. Creates/loads the Firestore record.
  Future<void> attach({required String name, required String phone}) async {
    if (!live) return;
    final uid = Backend.uid;
    if (uid == null || _attachedUid == uid) return;
    _attachedUid = uid;
    profileLoading = true;
    notifyListeners();
    try {
      await FirestoreApi.ensureDriver(name: name, phone: phone);
    } catch (e) {
      debugPrint('CarryMe: could not create driver record: $e');
    }
    _profileSub?.cancel();
    _profileSub = FirestoreApi.driverStream(uid).listen((p) {
      profile = p;
      profileLoading = false;
      if (p != null) {
        vehicle = p.vehicleType;
        vehicleModel = p.vehicleModel;
        plate = p.plate.isEmpty ? 'No plate set' : p.plate;
        colorName = p.colorName;
        if (!p.approved && online) goOffline();
      }
      notifyListeners();
    }, onError: (Object e) {
      profileLoading = false;
      notifyListeners();
    });
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final docs = await FirestoreApi.driverHistory();
      trips
        ..clear()
        ..addAll(docs.map((doc) {
          final d = doc.data();
          final j = _jobFromDoc(doc.id, d);
          final tip = (d['tipLrd'] as num?)?.toDouble() ?? 0;
          return DriverTrip(
            job: j,
            date: dateFrom(d['completedAt']) ?? dateFrom(d['createdAt']) ?? DateTime.now(),
            fareLrd: j.fareLrd + tip,
            commissionLrd: FareService.round5(j.fareLrd * AppConfig.commissionRate),
          );
        }));
      notifyListeners();
    } catch (e) {
      debugPrint('CarryMe: could not load trip history: $e');
    }
  }

  Future<String?> setVehicle({
    required VehicleType type,
    required String model,
    required String plateNo,
    String color = '',
  }) async {
    if (live) {
      if (profile?.approved == true && (type != profile!.vehicleType || plateNo != profile!.plate)) {
        return 'Your vehicle is approved. Contact support to change vehicle type or plate.';
      }
      try {
        await FirestoreApi.updateVehicle(type: type, model: model, plate: plateNo, colorName: color)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        return 'Could not save - check your connection and try again.';
      }
    }
    vehicle = type;
    vehicleModel = model;
    plate = plateNo;
    colorName = color;
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------------ online/offline

  void toggleOnline() => online ? goOffline() : goOnline();

  void goOnline() {
    if (!approved) return;
    online = true;
    notifyListeners();
    if (live) {
      _startGps();
      FirestoreApi.setOnline(true, at: myPos).catchError((Object e) => debugPrint('$e'));
      _requestsSub?.cancel();
      _requestsSub = FirestoreApi.openRequests(vehicle).listen((snap) {
        _openRequests = snap.docs.map((d) => {...d.data(), '_id': d.id}).toList();
        _evaluateRequests();
      }, onError: (Object e) {
        notice = 'Could not load ride requests. Is your account approved?';
        notifyListeners();
      });
    } else {
      _scheduleOffer();
    }
  }

  void goOffline() {
    online = false;
    _offerTimer?.cancel();
    _requestsSub?.cancel();
    _requestsSub = null;
    if (stage == DriverStage.incoming) {
      _countdownTimer?.cancel();
      stage = DriverStage.idle;
      job = null;
    }
    if (live) {
      if (stage == DriverStage.idle) _stopGps();
      FirestoreApi.setOnline(false).catchError((Object e) => debugPrint('$e'));
    }
    notifyListeners();
  }

  void _startGps() {
    if (_gpsSub != null) return;
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen((p) {
      myPos = LatLng(p.latitude, p.longitude);
      _pushLocation();
    }, onError: (Object e) => debugPrint('CarryMe: GPS error: $e'));
  }

  void _stopGps() {
    _gpsSub?.cancel();
    _gpsSub = null;
  }

  /// Sends the driver's position at most every 8 seconds to save data.
  void _pushLocation() {
    final p = myPos;
    if (!live || p == null) return;
    final now = DateTime.now();
    if (now.difference(_lastPush) < const Duration(seconds: 8)) return;
    _lastPush = now;
    final j = job;
    if (j != null && j.id.isNotEmpty && stage != DriverStage.incoming) {
      FirestoreApi.rideLocation(j.id, p).catchError((Object e) => debugPrint('$e'));
    }
    if (online) FirestoreApi.updateDriverLocation(p).catchError((Object e) => debugPrint('$e'));
  }

  // ------------------------------------------------------------ live offers

  DriverJob _jobFromDoc(String id, Map<String, dynamic> d) {
    final pickup = placeFromMap(d['pickup']);
    final here = myPos;
    return DriverJob(
      id: id,
      riderName: d['riderName'] as String? ?? 'Rider',
      riderPhone: d['riderPhone'] as String? ?? '',
      riderRating: 5.0,
      pickup: pickup,
      destination: placeFromMap(d['destination']),
      vehicle: vehicleFromName(d['vehicle'] as String?),
      fareLrd: (d['fareLrd'] as num?)?.toDouble() ?? 0,
      distanceKm: (d['distanceKm'] as num?)?.toDouble() ?? 0,
      pickupKm: here == null ? 0 : kmBetween(here, pickup.point),
      payment: PaymentMethod.values.firstWhere((m) => m.name == d['payment'], orElse: () => PaymentMethod.cashLrd),
      pin: '',
      note: d['note'] as String? ?? '',
      seats: (d['seats'] as num?)?.toInt() ?? 1,
    );
  }

  /// Picks the nearest suitable open request to offer.
  void _evaluateRequests() {
    final ids = _openRequests.map((d) => d['_id'] as String).toSet();

    // The offer on screen was taken by someone else or cancelled.
    if (stage == DriverStage.incoming && job != null && !ids.contains(job!.id)) {
      _countdownTimer?.cancel();
      job = null;
      stage = DriverStage.idle;
      notice = 'That request is no longer available.';
    }
    if (stage != DriverStage.idle || !online) {
      notifyListeners();
      return;
    }

    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    final candidates = <DriverJob>[];
    for (final d in _openRequests) {
      final id = d['_id'] as String;
      if (_declined.contains(id)) continue;
      if (d['riderId'] == Backend.uid) continue; // your own test request
      final created = dateFrom(d['createdAt']);
      if (created != null && created.isBefore(cutoff)) continue; // abandoned
      final j = _jobFromDoc(id, d);
      if (myPos != null && j.pickupKm > 15) continue;
      candidates.add(j);
    }
    if (candidates.isEmpty) {
      notifyListeners();
      return;
    }
    candidates.sort((a, b) => a.pickupKm.compareTo(b.pickupKm));
    _showOffer(candidates.first);
  }

  void _showOffer(DriverJob j) {
    job = j;
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

  void _watchRide(String id) {
    _rideSub?.cancel();
    _rideSub = FirestoreApi.rideStream(id).listen((snap) {
      final d = snap.data();
      if (d == null) return;
      if (d['status'] == 'cancelled' && d['cancelledBy'] == 'rider' && job?.id == id) {
        _rideSub?.cancel();
        job = null;
        stage = DriverStage.idle;
        notice = 'The rider cancelled this trip.';
        notifyListeners();
        _afterJob();
      }
    }, onError: (Object e) => debugPrint('CarryMe: ride watch error: $e'));
  }

  void _afterJob() {
    if (!online) {
      if (live) _stopGps();
      return;
    }
    if (live) {
      _evaluateRequests();
    } else {
      _scheduleOffer();
    }
  }

  // ------------------------------------------------------------ demo offers

  void _scheduleOffer() {
    _offerTimer?.cancel();
    _offerTimer = Timer(Duration(seconds: 5 + _rand.nextInt(7)), _demoOffer);
  }

  void _demoOffer() {
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
    _showOffer(DriverJob(
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
    ));
  }

  // ------------------------------------------------------------ trip steps

  /// Returns null on success, or a message to show.
  Future<String?> accept() async {
    _countdownTimer?.cancel();
    final j = job;
    if (j == null) return 'This request is no longer available.';
    if (!live) {
      stage = DriverStage.toPickup;
      notifyListeners();
      return null;
    }
    final p = profile;
    final ok = await FirestoreApi.acceptRide(j.id, {
      'driverName': p?.name ?? '',
      'driverPhone': p?.phone ?? '',
      'vehicleDesc': vehicleModel,
      'colorName': colorName,
      'plate': plate,
      'driverRating': p?.rating ?? 5.0,
      'driverTrips': p?.trips ?? 0,
      if (myPos != null) 'driverLat': myPos!.latitude,
      if (myPos != null) 'driverLng': myPos!.longitude,
    });
    if (!ok) {
      _declined.add(j.id);
      job = null;
      stage = DriverStage.idle;
      notifyListeners();
      _afterJob();
      return 'Could not accept - another driver may have taken it, or your connection dropped.';
    }
    stage = DriverStage.toPickup;
    notifyListeners();
    _watchRide(j.id);
    return null;
  }

  void decline() {
    _countdownTimer?.cancel();
    final j = job;
    if (j != null && j.id.isNotEmpty) _declined.add(j.id);
    job = null;
    stage = DriverStage.idle;
    notifyListeners();
    _afterJob();
  }

  void arrived() {
    final j = job;
    if (live && j != null) {
      FirestoreApi.markArrived(j.id).catchError((Object e) => debugPrint('$e'));
    }
    stage = DriverStage.atPickup;
    notifyListeners();
  }

  /// Rider tells the driver their 4-digit PIN. In live mode the database
  /// itself checks it, so a wrong PIN can never start the trip.
  Future<bool> startTrip(String enteredPin) async {
    final j = job;
    if (j == null) return false;
    final pinText = enteredPin.trim();
    final ok = live ? await FirestoreApi.startRide(j.id, pinText) : pinText == j.pin;
    if (!ok) return false;
    stage = DriverStage.onTrip;
    notifyListeners();
    return true;
  }

  DriverTrip completeTrip() {
    final j = job!;
    if (live) {
      FirestoreApi.completeRide(j.id).catchError((Object e) => debugPrint('$e'));
      _rideSub?.cancel();
    }
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
    _afterJob();
    return trip;
  }

  void cancelJob({String reason = 'Driver cancelled'}) {
    final j = job;
    if (live && j != null && j.id.isNotEmpty) {
      _rideSub?.cancel();
      FirestoreApi.cancelRide(j.id, reason: reason, by: 'driver').catchError((Object e) => debugPrint('$e'));
      _declined.add(j.id);
    }
    job = null;
    stage = DriverStage.idle;
    notifyListeners();
    _afterJob();
  }

  void cashOut(double amount) {
    paidOutLrd += amount;
    notifyListeners();
  }

  /// Stop everything (on logout or switching to rider mode).
  void detach() {
    if (online) goOffline();
    _profileSub?.cancel();
    _rideSub?.cancel();
    _stopGps();
    _attachedUid = null;
    profile = null;
  }

  @override
  void dispose() {
    _offerTimer?.cancel();
    _countdownTimer?.cancel();
    _profileSub?.cancel();
    _requestsSub?.cancel();
    _rideSub?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }
}
