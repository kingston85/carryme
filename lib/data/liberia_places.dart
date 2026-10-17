import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../models/place.dart';
import '../utils/geo.dart';

/// Well-known landmarks. Liberians give directions by landmark ("by ELWA
/// Junction", "behind Red Light"), so these power search, pickup labels and
/// suggestions. Coordinates are approximate - verify and extend before launch.
class LiberiaPlaces {
  static final List<Place> all = [
    // Central Monrovia
    Place(name: 'Broad Street', area: 'Central Monrovia', point: LatLng(6.3106, -10.8047), icon: Icons.storefront),
    Place(name: 'Waterside Market', area: 'Central Monrovia', point: LatLng(6.3140, -10.8075), icon: Icons.shopping_basket),
    Place(name: 'Mamba Point', area: 'Monrovia', point: LatLng(6.3180, -10.8125), icon: Icons.location_city),
    Place(name: 'Capitol Hill', area: 'Monrovia', point: LatLng(6.3035, -10.7990), icon: Icons.account_balance),
    Place(name: 'University of Liberia (Capitol Hill)', area: 'Capitol Hill', point: LatLng(6.3030, -10.7965), icon: Icons.school),
    Place(name: 'Jallah Town', area: 'Monrovia', point: LatLng(6.3010, -10.7920), icon: Icons.home_work),
    Place(name: 'Vai Town', area: 'Monrovia', point: LatLng(6.3240, -10.8000), icon: Icons.home_work),
    // Sinkor / Congo Town
    Place(name: 'Sinkor (Tubman Boulevard)', area: 'Sinkor', point: LatLng(6.2930, -10.7780), icon: Icons.add_road),
    Place(name: 'JFK Medical Center', area: 'Sinkor', point: LatLng(6.2880, -10.7770), icon: Icons.local_hospital),
    Place(name: 'Old Road', area: 'Sinkor', point: LatLng(6.2840, -10.7650), icon: Icons.add_road),
    Place(name: 'Spriggs Payne Airport', area: 'Sinkor', point: LatLng(6.2896, -10.7587), icon: Icons.flight),
    Place(name: 'Congo Town', area: 'Monrovia', point: LatLng(6.2760, -10.7470), icon: Icons.home_work),
    // Paynesville
    Place(name: '72nd Junction', area: 'Paynesville', point: LatLng(6.2600, -10.7280), icon: Icons.alt_route),
    Place(name: 'SKD Sports Complex', area: 'Paynesville', point: LatLng(6.2680, -10.7180), icon: Icons.stadium),
    Place(name: 'Red Light Market', area: 'Paynesville', point: LatLng(6.2820, -10.7010), icon: Icons.shopping_basket),
    Place(name: 'ELWA Junction', area: 'Paynesville', point: LatLng(6.2440, -10.7040), icon: Icons.alt_route),
    Place(name: 'Rehab Junction', area: 'Paynesville', point: LatLng(6.2650, -10.6850), icon: Icons.alt_route),
    // North / Bushrod Island
    Place(name: 'Gardnersville', area: 'Monrovia', point: LatLng(6.3220, -10.7570), icon: Icons.home_work),
    Place(name: 'Barnersville', area: 'Monrovia', point: LatLng(6.3270, -10.7400), icon: Icons.home_work),
    Place(name: 'Duala Market', area: 'Bushrod Island', point: LatLng(6.3460, -10.7970), icon: Icons.shopping_basket),
    Place(name: 'Freeport of Monrovia', area: 'Bushrod Island', point: LatLng(6.3440, -10.8060), icon: Icons.directions_boat),
    Place(name: 'Logan Town', area: 'Bushrod Island', point: LatLng(6.3570, -10.7930), icon: Icons.home_work),
    Place(name: 'New Kru Town', area: 'Bushrod Island', point: LatLng(6.3660, -10.7980), icon: Icons.home_work),
    Place(name: 'Brewerville', area: 'Montserrado', point: LatLng(6.4100, -10.7700), icon: Icons.home_work),
    // Out of town
    Place(name: 'Roberts International Airport (RIA)', area: 'Margibi', point: LatLng(6.2338, -10.3623), icon: Icons.flight_takeoff),
    Place(name: 'Harbel', area: 'Margibi', point: LatLng(6.2800, -10.3500), icon: Icons.location_city),
    Place(name: 'Kakata', area: 'Margibi', point: LatLng(6.5300, -10.3530), icon: Icons.location_city),
    Place(name: 'Tubmanburg', area: 'Bomi', point: LatLng(6.8710, -10.8180), icon: Icons.location_city),
    Place(name: 'Robertsport', area: 'Grand Cape Mount', point: LatLng(6.7530, -11.3680), icon: Icons.beach_access),
    Place(name: 'Buchanan', area: 'Grand Bassa', point: LatLng(5.8808, -10.0467), icon: Icons.location_city),
    Place(name: 'Gbarnga', area: 'Bong', point: LatLng(6.9956, -9.4722), icon: Icons.location_city),
    Place(name: 'Ganta', area: 'Nimba', point: LatLng(7.2350, -8.9810), icon: Icons.location_city),
  ];

  static const List<String> popularNames = [
    'Red Light Market',
    'ELWA Junction',
    'Broad Street',
    'Roberts International Airport (RIA)',
    'JFK Medical Center',
    'Duala Market',
    'SKD Sports Complex',
    'University of Liberia (Capitol Hill)',
  ];

  static List<Place> get popular =>
      popularNames.map(byName).whereType<Place>().toList();

  /// Landmarks inside greater Monrovia (used for simulated driver jobs).
  static List<Place> get monrovia =>
      all.where((p) => kmBetween(p.point, AppConfig.monroviaCenter) < 15).toList();

  static Place? byName(String name) {
    for (final p in all) {
      if (p.name == name) return p;
    }
    return null;
  }

  static List<Place> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return all
        .where((p) => p.name.toLowerCase().contains(q) || p.area.toLowerCase().contains(q))
        .toList();
  }

  /// Closest known landmark within [maxKm], used for "Near ELWA Junction".
  static Place? nearest(LatLng point, {double maxKm = 1.5}) {
    Place? best;
    var bestKm = maxKm;
    for (final p in all) {
      final d = kmBetween(point, p.point);
      if (d <= bestKm) {
        best = p;
        bestKm = d;
      }
    }
    return best;
  }
}
