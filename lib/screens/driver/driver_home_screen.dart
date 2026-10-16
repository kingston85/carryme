import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/payment.dart';
import '../../services/location_service.dart';
import '../../services/money.dart';
import '../../state/app_state.dart';
import '../../state/driver_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/launch.dart';
import '../../widgets/app_map.dart';
import '../../widgets/common.dart';
import 'driver_drawer.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final MapController _map = MapController();
  bool _mapReady = false;
  LatLng _me = AppConfig.monroviaCenter;
  DriverStage? _lastStage;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final p = await LocationService.current();
    if (p == null || !mounted) return;
    setState(() => _me = p);
    if (_mapReady) _map.move(p, 15);
  }

  void _fitJob(DriverJob job) {
    if (!_mapReady) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([job.pickup.point, job.destination.point]),
      padding: const EdgeInsets.fromLTRB(60, 120, 60, 360),
      maxZoom: 16,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final drv = context.watch<DriverController>();
    final app = context.watch<AppState>();
    final job = drv.job;

    if (drv.stage != _lastStage) {
      _lastStage = drv.stage;
      if (job != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fitJob(job);
        });
      }
    }

    return Scaffold(
      drawer: const DriverDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _map,
              center: _me,
              zoom: 14,
              onMapReady: () => _mapReady = true,
              layers: [
                if (job != null) routeLayer([job.pickup.point, job.destination.point], color: AppColors.navy),
                MarkerLayer(markers: [
                  meMarker(_me),
                  if (job != null) pickupMarker(job.pickup.point),
                  if (job != null) destinationMarker(job.destination.point),
                ]),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Builder(
                    builder: (ctx) => CircleIconButton(icon: Icons.menu, onTap: () => Scaffold.of(ctx).openDrawer()),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.white,
                    elevation: 3,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Row(
                        children: [
                          const Icon(Icons.payments_outlined, size: 18, color: AppColors.green),
                          const SizedBox(width: 6),
                          Text(Money.lrd(drv.todayEarnings), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  CircleIconButton(icon: Icons.my_location, onTap: _locate),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SheetPanel(child: _panel(drv, app)),
          ),
        ],
      ),
    );
  }

  Widget _panel(DriverController drv, AppState app) {
    switch (drv.stage) {
      case DriverStage.idle:
        return _idlePanel(drv, app);
      case DriverStage.incoming:
        return _offerPanel(drv, app);
      case DriverStage.toPickup:
        return _toPickupPanel(drv);
      case DriverStage.atPickup:
        return _atPickupPanel(drv);
      case DriverStage.onTrip:
        return _onTripPanel(drv, app);
    }
  }

  Widget _idlePanel(DriverController drv, AppState app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: drv.online ? AppColors.green : AppColors.muted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(drv.online ? 'You\'re online' : 'You\'re offline', style: AppText.h2),
            ),
            Pill(text: '${drv.vehicle.label} · ${drv.plate}', icon: drv.vehicle.icon),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          drv.online
              ? 'Looking for riders near you. Stay near busy spots like junctions and markets.'
              : 'Go online to start getting ride requests.',
          style: AppText.muted,
        ),
        if (drv.online) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(minHeight: 4),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            _stat('Today', Money.lrd(drv.todayEarnings)),
            _stat('Trips', '${drv.todayTrips.length}'),
            _stat('Rating', '4.9 ★'),
          ],
        ),
        const SizedBox(height: 14),
        PrimaryButton(
          label: drv.online ? 'Go offline' : 'Go online',
          icon: Icons.power_settings_new,
          color: drv.online ? AppColors.red : AppColors.green,
          onPressed: drv.toggleOnline,
        ),
      ],
    );
  }

  Widget _offerPanel(DriverController drv, AppState app) {
    final j = drv.job!;
    final progress = drv.countdown / DriverController.offerSeconds;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: Text('New ride request', style: AppText.h2)),
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: progress, strokeWidth: 4, color: AppColors.red),
                  Text('${drv.countdown}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(Money.lrd(j.fareLrd), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('≈ ${Money.usdFromLrd(j.fareLrd)}', style: AppText.muted),
            ),
            const Spacer(),
            Pill(text: j.payment.label, icon: j.payment.icon, color: j.payment.color, background: j.payment.color.withAlpha(28)),
          ],
        ),
        Text(
          'You earn ${Money.lrd(j.fareLrd * (1 - AppConfig.commissionRate))} after ${(AppConfig.commissionRate * 100).round()}% service fee',
          style: AppText.small,
        ),
        const SizedBox(height: 14),
        RouteSummary(
          from: j.pickup.name,
          fromSub: '${j.pickupKm.toStringAsFixed(1)} km away · ${j.pickup.area}',
          to: j.destination.name,
          toSub: '${j.distanceKm.toStringAsFixed(1)} km trip · ${j.destination.area}',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.person, size: 18, color: AppColors.muted),
            const SizedBox(width: 4),
            Text('${j.riderName} · ${j.riderRating.toStringAsFixed(1)} ★', style: AppText.muted),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SecondaryButton(label: 'Decline', color: AppColors.red, onPressed: drv.decline)),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: PrimaryButton(label: 'Accept', icon: Icons.check, color: AppColors.green, onPressed: drv.accept)),
          ],
        ),
      ],
    );
  }

  Widget _toPickupPanel(DriverController drv) {
    final j = drv.job!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Pick up ${j.riderName}', style: AppText.h2),
        const SizedBox(height: 4),
        Text('at ${j.pickup.fullLabel}', style: AppText.muted),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Navigate',
                icon: Icons.navigation,
                onPressed: () => Launch.navigate(context, j.pickup.point),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(
                label: 'Call rider',
                icon: Icons.call,
                onPressed: () => showSnack(context, 'Calls are routed through CarryMe in the live app.'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        PrimaryButton(label: 'I\'ve arrived', icon: Icons.place, onPressed: drv.arrived),
        TextButton(
          onPressed: () => _confirmCancel(drv),
          child: const Text('Cancel trip', style: TextStyle(color: AppColors.red)),
        ),
      ],
    );
  }

  Widget _atPickupPanel(DriverController drv) {
    final j = drv.job!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Waiting for rider', style: AppText.h2),
        const SizedBox(height: 4),
        Text('Ask ${j.riderName} for their 4-digit ride PIN before they get in.', style: AppText.muted),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(10)),
          child: Text('Demo: the rider\'s PIN is ${j.pin}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Enter PIN & start trip', icon: Icons.pin, onPressed: () => _enterPin(drv)),
        TextButton(
          onPressed: () => _confirmCancel(drv),
          child: const Text('Rider didn\'t show up', style: TextStyle(color: AppColors.red)),
        ),
      ],
    );
  }

  Widget _onTripPanel(DriverController drv, AppState app) {
    final j = drv.job!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Trip in progress', style: AppText.h2),
        const SizedBox(height: 4),
        Text('Drop off at ${j.destination.fullLabel}', style: AppText.muted),
        const SizedBox(height: 14),
        SecondaryButton(
          label: 'Navigate to drop-off',
          icon: Icons.navigation,
          onPressed: () => Launch.navigate(context, j.destination.point),
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Complete trip',
          icon: Icons.flag,
          color: AppColors.green,
          onPressed: () => _complete(drv),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Text(value, style: AppText.h3),
              const SizedBox(height: 2),
              Text(label, style: AppText.small),
            ],
          ),
        ),
      );

  Future<void> _enterPin(DriverController drv) async {
    final ctrl = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rider\'s PIN'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w800),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Start trip')),
        ],
      ),
    );
    if (pin == null || !mounted) return;
    if (!drv.startTrip(pin)) showSnack(context, 'Wrong PIN. Check you have the right rider.');
  }

  Future<void> _complete(DriverController drv) async {
    final j = drv.job!;
    final trip = drv.completeTrip();
    final collectCash = j.payment.isCash;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.green, size: 48),
        title: const Text('Trip complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (collectCash)
              Text(
                j.payment == PaymentMethod.cashUsd
                    ? 'Collect ${Money.usdFromLrd(j.fareLrd)} cash (${Money.lrd(j.fareLrd)})'
                    : 'Collect ${Money.lrd(j.fareLrd)} cash',
                textAlign: TextAlign.center,
                style: AppText.h3,
              )
            else
              Text('${j.payment.label} payment - no cash to collect', textAlign: TextAlign.center, style: AppText.h3),
            const SizedBox(height: 10),
            Text('You earned ${Money.lrd(trip.earningLrd)}', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
            Text('Service fee ${Money.lrd(trip.commissionLrd)}', style: AppText.small),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _confirmCancel(DriverController drv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this trip?'),
        content: const Text('Frequent cancellations lower your acceptance rate.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep trip')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel trip'),
          ),
        ],
      ),
    );
    if (ok == true) drv.cancelJob();
  }
}
