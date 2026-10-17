import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../data/liberia_places.dart';
import '../models/place.dart';

/// Place search and "what is here?" lookups.
/// Local landmarks come first (they work offline), then OpenStreetMap results
/// limited to Liberia.
class GeocodingService {
  static const _headers = {
    'User-Agent': 'CarryMe/1.0 (Liberia ride-hailing app)',
    'Accept-Language': 'en',
  };

  static Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final local = LiberiaPlaces.search(q);
    final remote = <Place>[];
    try {
      final uri = Uri.parse('${AppConfig.nominatimBase}/search').replace(queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'countrycodes': 'lr',
        'limit': '8',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        for (final item in list) {
          final m = item as Map<String, dynamic>;
          final display = m['display_name'] as String? ?? '';
          final parts = display.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final rawName = m['name'] as String? ?? '';
          final name = rawName.isNotEmpty ? rawName : (parts.isNotEmpty ? parts.first : q);
          final area = parts.length > 1 ? parts.sublist(1, min(3, parts.length)).join(', ') : '';
          final lat = double.tryParse('${m['lat']}');
          final lon = double.tryParse('${m['lon']}');
          if (lat == null || lon == null) continue;
          remote.add(Place(name: name, area: area, point: LatLng(lat, lon)));
        }
      }
    } catch (_) {
      // offline: local results only
    }
    final seen = <String>{};
    return [...local, ...remote].where((p) => seen.add(p.name.toLowerCase())).toList();
  }

  /// Turns a map point into a friendly label, preferring Liberian landmarks.
  static Future<Place> describe(LatLng p) async {
    final near = LiberiaPlaces.nearest(p, maxKm: 0.8);
    String? street;
    String? suburb;
    try {
      final uri = Uri.parse('${AppConfig.nominatimBase}/reverse').replace(queryParameters: {
        'lat': p.latitude.toStringAsFixed(6),
        'lon': p.longitude.toStringAsFixed(6),
        'format': 'jsonv2',
        'zoom': '17',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = m['address'] as Map<String, dynamic>?;
        final name = m['name'] as String? ?? '';
        final road = addr?['road'] as String?;
        street = name.isNotEmpty ? name : road;
        suburb = (addr?['suburb'] ?? addr?['neighbourhood'] ?? addr?['city'] ?? addr?['town']) as String?;
      }
    } catch (_) {
      // offline
    }

    if (near != null) {
      return Place(
        name: street ?? 'Near ${near.name}',
        area: street != null ? 'Near ${near.name}' : near.area,
        point: p,
      );
    }
    return Place(name: street ?? 'Pinned location', area: suburb ?? '', point: p);
  }
}
