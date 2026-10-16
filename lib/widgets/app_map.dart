import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/vehicle_type.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// OpenStreetMap-based map: no API key needed, works well across Liberia.
class AppMap extends StatelessWidget {
  final MapController? controller;
  final LatLng center;
  final double zoom;
  final List<Widget> layers;
  final VoidCallback? onMapReady;
  final PositionCallback? onPositionChanged;

  const AppMap({
    super.key,
    required this.center,
    this.controller,
    this.zoom = 14,
    this.layers = const [],
    this.onMapReady,
    this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Data saver: fetch fewer, lower-detail tiles on slow or costly connections.
    final saver = context.select<AppState, bool>((a) => a.dataSaver);
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 6,
        maxZoom: 18,
        onMapReady: onMapReady,
        onPositionChanged: onPositionChanged,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.tileUrl,
          userAgentPackageName: AppConfig.packageId,
          maxZoom: 19,
          maxNativeZoom: saver ? 15 : 19,
          keepBuffer: saver ? 1 : 2,
        ),
        ...layers,
        SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }
}

class MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;

  const MapPin({super.key, required this.color, required this.icon, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Pulsing-style blue "you are here" dot.
class MeDot extends StatelessWidget {
  const MeDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x332563EB),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x552563EB)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}

Marker pickupMarker(LatLng p) => Marker(
      point: p,
      width: 40,
      height: 40,
      child: const MapPin(color: AppColors.navy, icon: Icons.person_pin_circle),
    );

Marker destinationMarker(LatLng p) => Marker(
      point: p,
      width: 40,
      height: 40,
      child: const MapPin(color: AppColors.red, icon: Icons.flag),
    );

Marker vehicleMarker(LatLng p, VehicleType v) => Marker(
      point: p,
      width: 46,
      height: 46,
      child: MapPin(color: AppColors.ink, icon: v.icon, size: 46),
    );

Marker meMarker(LatLng p) => Marker(point: p, width: 44, height: 44, child: const MeDot());

PolylineLayer routeLayer(List<LatLng> points, {Color color = AppColors.navy}) => PolylineLayer(
      polylines: [
        Polyline(
          points: points,
          strokeWidth: 5,
          color: color,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
      ],
    );
