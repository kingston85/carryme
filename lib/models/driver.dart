import 'vehicle_type.dart';

class Driver {
  final String name;
  final String phone;
  final double rating;
  final int trips;
  final VehicleType type;
  final String vehicleDesc;
  final String colorName;
  final String plate;
  final int yearsDriving;

  const Driver({
    required this.name,
    required this.phone,
    required this.rating,
    required this.trips,
    required this.type,
    required this.vehicleDesc,
    required this.colorName,
    required this.plate,
    required this.yearsDriving,
  });

  String get firstName => name.split(' ').first;
}
