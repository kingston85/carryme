import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../data/liberia_places.dart';
import '../../models/place.dart';
import '../../models/vehicle_type.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../state/app_state.dart';
import '../../state/ride_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/geo.dart';
import '../../widgets/app_map.dart';
import '../../widgets/common.dart';
import 'choose_ride_screen.dart';
import 'rider_drawer.dart';
import 'search_screen.dart';
import 'trip_screen.dart';

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  final MapController _map = MapController();
  bool _mapReady = false;
  LatLng _me = AppConfig.monroviaCenter;
  Place? _pickup;
  bool _locating = true;
  bool _hasGps = false;
  VehicleType? _preferred;

  @override
  void initState() {
    super.initState();
    _locate();
    // Live mode: reopen a ride that was still going when the app closed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RideController>().resumeIfAny();
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final p = await LocationService.current();
    if (!mounted) return;
    if (p != null) {
      _me = p;
      _hasGps = true;
      if (_mapReady) _map.move(p, 16);
      final place = await GeocodingService.describe(p);
      if (!mounted) return;
      setState(() {
        _pickup = Place(name: place.name, area: place.area, point: p, icon: Icons.my_location);
        _locating = false;
      });
    } else {
      setState(() {
        _locating = false;
        _hasGps = false;
        _pickup = null;
      });
      showSnack(context, 'Turn on location to set your pickup automatically.');
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _openSearch({Place? destination}) async {
    final plan = await Navigator.push<TripPlan>(
      context,
      MaterialPageRoute(builder: (_) => SearchScreen(initialPickup: _pickup, initialDestination: destination)),
    );
    if (plan != null && mounted) _goChoose(plan.pickup, plan.destination);
  }

  void _goChoose(Place pickup, Place destination) {
    if (kmBetween(pickup.point, destination.point) < 0.15) {
      showSnack(context, 'Pickup and destination are too close together.');
      return;
    }
    final app = context.read<AppState>();
    context.read<RideController>().startPlanning(
          pickup: pickup,
          destination: destination,
          defaultPayment: app.defaultPayment,
          raining: app.simulateRain,
          preferred: _preferred,
        );
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChooseRideScreen()));
  }

  /// Quick destination tap (saved place or landmark): skip search if we
  /// already know the pickup.
  void _quickDestination(Place dest) {
    if (_pickup != null) {
      _goChoose(_pickup!, dest);
    } else {
      _openSearch(destination: dest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ride = context.watch<RideController>();
    final user = app.user!;

    return Scaffold(
      drawer: const RiderDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _map,
              center: _me,
              zoom: 15,
              onMapReady: () {
                _mapReady = true;
                if (_hasGps) _map.move(_me, 16);
              },
              layers: [MarkerLayer(markers: [meMarker(_me)])],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => CircleIconButton(
                      icon: Icons.menu,
                      tooltip: 'Menu',
                      onTap: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  if (app.simulateRain)
                    const Pill(text: 'Rain pricing on', icon: Icons.water_drop, color: AppColors.navy),
                  const SizedBox(width: 8),
                  CircleIconButton(icon: Icons.my_location, tooltip: 'My location', onTap: _locate),
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
                  if (ride.hasActiveRide) ...[
                    _ActiveRideBanner(onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const TripScreen()));
                    }),
                    const SizedBox(height: 12),
                  ],
                  Text('$_greeting, ${user.firstName}', style: AppText.h2),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.my_location, size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locating
                              ? 'Finding your location…'
                              : (_pickup == null ? 'Location off - set pickup in search' : 'Pickup: ${_pickup!.fullLabel}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _WhereToBar(onTap: () => _openSearch()),
                  const SizedBox(height: 14),
                  _VehicleStrip(
                    selected: _preferred,
                    onSelect: (v) => setState(() => _preferred = _preferred == v ? null : v),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _QuickChip(
                          icon: Icons.home_rounded,
                          label: app.home == null ? 'Add home' : 'Home',
                          onTap: () {
                            if (app.home == null) {
                              _openSearch();
                            } else {
                              _quickDestination(app.home!);
                            }
                          },
                        ),
                        _QuickChip(
                          icon: Icons.work_rounded,
                          label: app.work == null ? 'Add work' : 'Work',
                          onTap: () {
                            if (app.work == null) {
                              _openSearch();
                            } else {
                              _quickDestination(app.work!);
                            }
                          },
                        ),
                        for (final p in app.favorites.take(3))
                          _QuickChip(icon: Icons.favorite, label: p.name, onTap: () => _quickDestination(p)),
                        for (final p in LiberiaPlaces.popular)
                          _QuickChip(icon: p.icon, label: p.name, onTap: () => _quickDestination(p)),
                      ],
                    ),
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

class _WhereToBar extends StatelessWidget {
  final VoidCallback onTap;
  const _WhereToBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.ink, size: 26),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Where to?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                child: const Row(
                  children: [
                    Icon(Icons.schedule, size: 16),
                    SizedBox(width: 4),
                    Text('Now', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleStrip extends StatelessWidget {
  final VehicleType? selected;
  final ValueChanged<VehicleType> onSelect;
  const _VehicleStrip({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final v in VehicleType.values)
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == v ? AppColors.navy : AppColors.navySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(v.icon, color: selected == v ? Colors.white : AppColors.navy, size: 26),
                    const SizedBox(height: 4),
                    Text(
                      v.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected == v ? Colors.white : AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: AppColors.navy),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _ActiveRideBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.directions_car, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text('You have a ride in progress',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              Text('View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
