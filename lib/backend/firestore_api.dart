import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/vehicle_type.dart';
import 'backend.dart';

/// A driver's account as stored in Firestore (drivers/{uid}).
/// `approved` can only be set by you (the operator) in the Firebase console.
class DriverProfile {
  final String uid;
  final String name;
  final String phone;
  final bool approved;
  final VehicleType vehicleType;
  final String vehicleModel;
  final String plate;
  final String colorName;
  final double rating;
  final int trips;

  const DriverProfile({
    required this.uid,
    required this.name,
    required this.phone,
    required this.approved,
    required this.vehicleType,
    required this.vehicleModel,
    required this.plate,
    required this.colorName,
    required this.rating,
    required this.trips,
  });

  factory DriverProfile.fromDoc(String uid, Map<String, dynamic> d) => DriverProfile(
        uid: uid,
        name: d['name'] as String? ?? '',
        phone: d['phone'] as String? ?? '',
        approved: d['approved'] == true,
        vehicleType: vehicleFromName(d['vehicleType'] as String?),
        vehicleModel: d['vehicleModel'] as String? ?? '',
        plate: d['plate'] as String? ?? '',
        colorName: d['colorName'] as String? ?? '',
        rating: (d['rating'] as num?)?.toDouble() ?? 5.0,
        trips: (d['trips'] as num?)?.toInt() ?? 0,
      );
}

VehicleType vehicleFromName(String? name) {
  for (final v in VehicleType.values) {
    if (v.name == name) return v;
  }
  return VehicleType.taxi;
}

Map<String, dynamic> placeToMap(Place p) => {
      'name': p.name,
      'area': p.area,
      'lat': p.point.latitude,
      'lng': p.point.longitude,
    };

Place placeFromMap(dynamic raw) {
  final m = (raw as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  return Place(
    name: m['name'] as String? ?? 'Place',
    area: m['area'] as String? ?? '',
    point: LatLng((m['lat'] as num?)?.toDouble() ?? 0, (m['lng'] as num?)?.toDouble() ?? 0),
  );
}

LatLng? latLngFrom(Map<String, dynamic> d, String latKey, String lngKey) {
  final lat = d[latKey];
  final lng = d[lngKey];
  if (lat is num && lng is num) return LatLng(lat.toDouble(), lng.toDouble());
  return null;
}

DateTime? dateFrom(dynamic v) => v is Timestamp ? v.toDate() : null;

/// Every read and write the app makes. The matching security rules are in
/// firestore.rules - keep the two in step when you add fields.
class FirestoreApi {
  static FirebaseFirestore get _db => Backend.db;
  static CollectionReference<Map<String, dynamic>> get rides => _db.collection('rides');
  static CollectionReference<Map<String, dynamic>> get drivers => _db.collection('drivers');
  static CollectionReference<Map<String, dynamic>> get users => _db.collection('users');

  // ------------------------------------------------------------------ users

  static Future<void> saveUser({required String name, required String phone, required String role}) {
    final uid = Backend.uid!;
    return users.doc(uid).set({
      'name': name,
      'phone': phone,
      'lastRole': role,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------- drivers

  /// Creates the driver record the first time someone switches to driving.
  static Future<void> ensureDriver({required String name, required String phone}) async {
    final uid = Backend.uid!;
    final ref = drivers.doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'name': name,
      'phone': phone,
      'approved': false,
      'vehicleType': VehicleType.taxi.name,
      'vehicleModel': '',
      'plate': '',
      'colorName': '',
      'rating': 5.0,
      'trips': 0,
      'online': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<DriverProfile?> driverStream(String uid) => drivers.doc(uid).snapshots().map(
        (s) => s.data() == null ? null : DriverProfile.fromDoc(uid, s.data()!),
      );

  static Future<void> updateVehicle({
    required VehicleType type,
    required String model,
    required String plate,
    required String colorName,
  }) =>
      drivers.doc(Backend.uid!).update({
        'vehicleType': type.name,
        'vehicleModel': model,
        'plate': plate,
        'colorName': colorName,
      });

  static Future<void> setOnline(bool online, {LatLng? at}) => drivers.doc(Backend.uid!).update({
        'online': online,
        if (at != null) 'lat': at.latitude,
        if (at != null) 'lng': at.longitude,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

  static Future<void> updateDriverLocation(LatLng at) => drivers.doc(Backend.uid!).update({
        'lat': at.latitude,
        'lng': at.longitude,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

  // ------------------------------------------------------------ rider side

  /// Prepares a new ride id and the write that creates it, so the app can
  /// start listening right away even when the network is slow.
  static ({String id, Future<void> commit}) createRide(Map<String, dynamic> data, String pin) {
    final ref = rides.doc();
    final batch = _db.batch()
      ..set(ref, {
        ...data,
        'riderId': Backend.uid,
        'status': 'searching',
        'driverId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(ref.collection('secret').doc('pin'), {'pin': pin});
    return (id: ref.id, commit: batch.commit());
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> rideStream(String id) => rides.doc(id).snapshots();

  static Future<DocumentSnapshot<Map<String, dynamic>>> getRide(String id) => rides.doc(id).get();

  static Future<String?> getPin(String rideId) async {
    final s = await rides.doc(rideId).collection('secret').doc('pin').get();
    return s.data()?['pin'] as String?;
  }

  static Future<void> cancelRide(String id, {required String reason, required String by}) => rides.doc(id).update({
        'status': 'cancelled',
        'cancelReason': reason,
        'cancelledBy': by,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> rateRide(String id, {required int rating, required double tipLrd, String comment = ''}) =>
      rides.doc(id).update({
        'riderRating': rating,
        'tipLrd': tipLrd,
        'riderComment': comment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ----------------------------------------------------------- driver side

  /// Open requests for one vehicle type (equality filters only, so no
  /// composite index is needed).
  static Stream<QuerySnapshot<Map<String, dynamic>>> openRequests(VehicleType type) => rides
      .where('status', isEqualTo: 'searching')
      .where('vehicle', isEqualTo: type.name)
      .limit(25)
      .snapshots();

  /// Claims a ride. Returns false if another driver got it first.
  static Future<bool> acceptRide(String id, Map<String, dynamic> driverFields) async {
    final ref = rides.doc(id);
    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        if (snap.data()?['status'] != 'searching') return false;
        tx.update(ref, {
          ...driverFields,
          'status': 'accepted',
          'driverId': Backend.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } on FirebaseException {
      return false;
    }
  }

  static Future<void> rideLocation(String id, LatLng at) => rides.doc(id).update({
        'driverLat': at.latitude,
        'driverLng': at.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> markArrived(String id) => rides.doc(id).update({
        'status': 'arrived',
        'arrivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// The security rules only allow this when [pin] matches the rider's PIN.
  static Future<bool> startRide(String id, String pin) async {
    try {
      await rides.doc(id).update({
        'status': 'in_progress',
        'pinEntered': pin,
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 20));
      return true;
    } on FirebaseException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  static Future<void> completeRide(String id) => rides.doc(id).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> driverHistory() async {
    final q = await rides.where('driverId', isEqualTo: Backend.uid).limit(100).get();
    final docs = q.docs.where((d) => d.data()['status'] == 'completed').toList()
      ..sort((a, b) => (dateFrom(b.data()['completedAt']) ?? DateTime(2000))
          .compareTo(dateFrom(a.data()['completedAt']) ?? DateTime(2000)));
    return docs;
  }
}
