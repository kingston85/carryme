import 'payment.dart';
import 'place.dart';
import 'vehicle_type.dart';

enum RideStatus { searching, driverEnRoute, driverArrived, inProgress, completed, cancelled }

/// A finished, cancelled or scheduled ride, kept in history.
class RideRecord {
  final String id;
  final Place pickup;
  final Place destination;
  final VehicleType vehicle;
  final double fareLrd;
  final PaymentMethod payment;
  final DateTime date;
  final String driverName;
  final String plate;
  final double distanceKm;
  final double durationMin;
  final String status; // completed | cancelled | scheduled
  final int rating;
  final double tipLrd;
  final int seats;

  const RideRecord({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.vehicle,
    required this.fareLrd,
    required this.payment,
    required this.date,
    required this.status,
    this.driverName = '',
    this.plate = '',
    this.distanceKm = 0,
    this.durationMin = 0,
    this.rating = 0,
    this.tipLrd = 0,
    this.seats = 1,
  });

  RideRecord copyWith({int? rating, double? tipLrd, String? status}) => RideRecord(
        id: id,
        pickup: pickup,
        destination: destination,
        vehicle: vehicle,
        fareLrd: fareLrd,
        payment: payment,
        date: date,
        status: status ?? this.status,
        driverName: driverName,
        plate: plate,
        distanceKm: distanceKm,
        durationMin: durationMin,
        rating: rating ?? this.rating,
        tipLrd: tipLrd ?? this.tipLrd,
        seats: seats,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'pickup': pickup.toJson(),
        'destination': destination.toJson(),
        'vehicle': vehicle.name,
        'fareLrd': fareLrd,
        'payment': payment.name,
        'date': date.toIso8601String(),
        'status': status,
        'driverName': driverName,
        'plate': plate,
        'distanceKm': distanceKm,
        'durationMin': durationMin,
        'rating': rating,
        'tipLrd': tipLrd,
        'seats': seats,
      };

  factory RideRecord.fromJson(Map<String, dynamic> j) => RideRecord(
        id: j['id'] as String? ?? '',
        pickup: Place.fromJson(j['pickup'] as Map<String, dynamic>),
        destination: Place.fromJson(j['destination'] as Map<String, dynamic>),
        vehicle: VehicleType.values.byName(j['vehicle'] as String? ?? 'taxi'),
        fareLrd: (j['fareLrd'] as num?)?.toDouble() ?? 0,
        payment: PaymentMethod.values.byName(j['payment'] as String? ?? 'cashLrd'),
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        status: j['status'] as String? ?? 'completed',
        driverName: j['driverName'] as String? ?? '',
        plate: j['plate'] as String? ?? '',
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        durationMin: (j['durationMin'] as num?)?.toDouble() ?? 0,
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        tipLrd: (j['tipLrd'] as num?)?.toDouble() ?? 0,
        seats: (j['seats'] as num?)?.toInt() ?? 1,
      );
}
