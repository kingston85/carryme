import 'dart:math';

import '../models/driver.dart';
import '../models/vehicle_type.dart';

/// Sample drivers for the demo. In production these come from your backend.
class MockDrivers {
  static const _names = [
    'Moses Kollie',
    'Amos Flomo',
    'Patience Kpadeh',
    'Emmanuel Tarr',
    'Musu Kamara',
    'Joseph Gbatu',
    'Fatu Massaquoi',
    'Varney Sumo',
    'Prince Zubah',
    'Hawa Konneh',
  ];

  static const Map<VehicleType, List<String>> _vehicles = {
    VehicleType.penPen: ['Haojue motorbike', 'TVS Apache motorbike', 'Honda motorbike'],
    VehicleType.keke: ['Bajaj keke', 'TVS King keke'],
    VehicleType.sharedTaxi: ['Toyota Corolla', 'Nissan Sunny'],
    VehicleType.taxi: ['Toyota Corolla', 'Toyota Yaris', 'Nissan Almera'],
    VehicleType.comfort: ['Toyota RAV4', 'Toyota Land Cruiser Prado', 'Honda CR-V'],
  };

  static const _colors = ['Yellow', 'White', 'Silver', 'Black', 'Blue', 'Red'];

  static Driver pick(VehicleType type, Random r) {
    final models = _vehicles[type]!;
    final isTaxi = type == VehicleType.taxi || type == VehicleType.sharedTaxi;
    final prefix = switch (type) {
      VehicleType.penPen => 'MC',
      VehicleType.keke => 'TC',
      VehicleType.taxi || VehicleType.sharedTaxi => 'TX',
      VehicleType.comfort => 'PP',
    };
    return Driver(
      name: _names[r.nextInt(_names.length)],
      phone: '+23177${1000000 + r.nextInt(8999999)}',
      rating: 4.6 + r.nextInt(5) / 10,
      trips: 120 + r.nextInt(3200),
      type: type,
      vehicleDesc: models[r.nextInt(models.length)],
      colorName: isTaxi ? 'Yellow' : _colors[r.nextInt(_colors.length)],
      plate: '$prefix-${1000 + r.nextInt(8999)}',
      yearsDriving: 2 + r.nextInt(12),
    );
  }

  static const riderNames = [
    'Comfort T.',
    'Prince K.',
    'Hawa B.',
    'Samuel D.',
    'Mercy W.',
    'Varney S.',
    'Rebecca N.',
    'Jefferson G.',
  ];
}
