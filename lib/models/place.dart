import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Place {
  final String name;
  final String area;
  final LatLng point;
  final IconData icon;

  const Place({
    required this.name,
    required this.point,
    this.area = '',
    this.icon = Icons.place_outlined,
  });

  String get fullLabel => area.isEmpty ? name : '$name, $area';

  Map<String, dynamic> toJson() => {
        'name': name,
        'area': area,
        'lat': point.latitude,
        'lng': point.longitude,
      };

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String? ?? 'Place',
        area: j['area'] as String? ?? '',
        point: LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
      );
}
