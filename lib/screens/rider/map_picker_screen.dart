import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/place.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/common.dart';

/// Drag the map under a fixed pin - handy where streets have no names.
class MapPickerScreen extends StatefulWidget {
  final LatLng initial;
  final String title;

  const MapPickerScreen({super.key, required this.initial, required this.title});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _map = MapController();
  bool _ready = false;
  Timer? _debounce;
  Place? _place;
  bool _looking = true;
  int _lookup = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  LatLng get _center => _ready ? _map.camera.center : widget.initial;

  void _scheduleLookup() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      final id = ++_lookup;
      if (mounted && !_looking) setState(() => _looking = true);
      final p = await GeocodingService.describe(_center);
      if (!mounted || id != _lookup) return;
      setState(() {
        _place = p;
        _looking = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _map,
              center: widget.initial,
              zoom: 17,
              onMapReady: () {
                _ready = true;
                _scheduleLookup();
              },
              onPositionChanged: (_, __) => _scheduleLookup(),
            ),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 44),
              child: Icon(Icons.location_on, size: 52, color: AppColors.red),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: Text(widget.title, style: AppText.h3),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SheetPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Move the map to place the pin', style: AppText.small),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place, color: AppColors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _looking
                            ? const Text('Finding this spot…', style: AppText.muted)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_place?.name ?? 'Pinned location', style: AppText.h3),
                                  if ((_place?.area ?? '').isNotEmpty) Text(_place!.area, style: AppText.small),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Confirm location',
                    onPressed: () {
                      final c = _center;
                      Navigator.pop(
                        context,
                        Place(
                          name: _place?.name ?? 'Pinned location',
                          area: _place?.area ?? '',
                          point: c,
                          icon: Icons.push_pin,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
