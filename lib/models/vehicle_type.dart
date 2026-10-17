import 'package:flutter/material.dart';

/// The ride types people actually use in Liberia.
enum VehicleType {
  penPen(
    label: 'Pen-Pen',
    subtitle: 'Motorbike · 1 rider · beat the traffic',
    icon: Icons.two_wheeler,
    capacity: 1,
  ),
  keke(
    label: 'Keke',
    subtitle: 'Tricycle · up to 3 riders',
    icon: Icons.electric_rickshaw,
    capacity: 3,
  ),
  sharedTaxi(
    label: 'Shared Taxi',
    subtitle: 'Book seats · share the car, pay less',
    icon: Icons.groups,
    capacity: 3,
  ),
  taxi(
    label: 'Taxi',
    subtitle: 'Whole car · up to 4 riders',
    icon: Icons.local_taxi,
    capacity: 4,
  ),
  comfort(
    label: 'Comfort',
    subtitle: 'AC car or SUV · top-rated drivers',
    icon: Icons.directions_car_filled,
    capacity: 4,
  );

  const VehicleType({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.capacity,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final int capacity;
}
