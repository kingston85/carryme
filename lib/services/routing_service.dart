import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../utils/geo.dart';

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;

  /// True when we could not reach the routing server and guessed instead.
  final bool isEstimate;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    required this.isEstimate,
  });
}

class RoutingService {
  static const _headers = {'User-Agent': 'CarryMe/1.0 (Liberia ride-hailing app)'};

  /// Road route between two points, with a straight-line fallback for when
  /// data is poor or the server is unreachable.
  static Future<RouteResult> route(LatLng a, LatLng b) async {
    try {
      final uri = Uri.parse('${AppConfig.osrmBase}/route/v1/driving/'
          '${a.longitude},${a.latitude};${b.longitude},${b.latitude}'
          '?overview=full&geometries=geojson');
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = (data['routes'] as List<dynamic>?) ?? const [];
        if (routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final geometry = r['geometry'] as Map<String, dynamic>;
          final coords = (geometry['coordinates'] as List<dynamic>).map((c) {
            final pair = c as List<dynamic>;
            return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
          }).toList();
          if (coords.length >= 2) {
            return RouteResult(
              points: coords,
              distanceKm: (r['distance'] as num).toDouble() / 1000.0,
              durationMin: (r['duration'] as num).toDouble() / 60.0 * AppConfig.trafficFactor,
              isEstimate: false,
            );
          }
        }
      }
    } catch (_) {
      // fall through to estimate
    }
    return estimate(a, b);
  }

  static RouteResult estimate(LatLng a, LatLng b) {
    final km = kmBetween(a, b) * AppConfig.roadDetourFactor;
    final minutes = km / AppConfig.avgCitySpeedKmh * 60.0;
    return RouteResult(
      points: resample([a, b], 30),
      distanceKm: km,
      durationMin: minutes < 2 ? 2.0 : minutes,
      isEstimate: true,
    );
  }

  /// Returns [n] points spaced evenly along the polyline [pts].
  static List<LatLng> resample(List<LatLng> pts, int n) {
    if (pts.isEmpty || n < 2) return List<LatLng>.of(pts);
    if (pts.length == 1) return List<LatLng>.filled(n, pts.first);

    final cum = <double>[0.0];
    for (var i = 1; i < pts.length; i++) {
      cum.add(cum.last + kmBetween(pts[i - 1], pts[i]));
    }
    final total = cum.last;
    if (total <= 0) return List<LatLng>.filled(n, pts.first);

    final out = <LatLng>[];
    var seg = 0;
    for (var k = 0; k < n; k++) {
      final target = total * k / (n - 1);
      while (seg < cum.length - 2 && cum[seg + 1] < target) {
        seg++;
      }
      final segLen = cum[seg + 1] - cum[seg];
      var t = segLen == 0 ? 0.0 : (target - cum[seg]) / segLen;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
      final a = pts[seg];
      final b = pts[seg + 1];
      out.add(LatLng(
        a.latitude + (b.latitude - a.latitude) * t,
        a.longitude + (b.longitude - a.longitude) * t,
      ));
    }
    return out;
  }
}
