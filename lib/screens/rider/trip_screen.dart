import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/driver.dart';
import '../../models/ride.dart';
import '../../state/app_state.dart';
import '../../state/ride_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/launch.dart';
import '../../widgets/app_map.dart';
import '../../widgets/common.dart';
import 'trip_complete_screen.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  final MapController _map = MapController();
  bool _mapReady = false;
  bool _follow = true;
  bool _leaving = false;
  bool _sharedOnce = false;

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideController>();
    final app = context.watch<AppState>();
    final status = ride.status;

    if (status == RideStatus.completed && !_leaving) {
      _leaving = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TripCompleteScreen()));
      });
    }

    // Auto-share with trusted contacts once a driver is assigned.
    if (status == RideStatus.driverEnRoute && app.autoShareTrips && !_sharedOnce && app.contacts.isNotEmpty) {
      _sharedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _shareTrip(ride);
      });
    }

    final pos = ride.driverPos;
    if (_mapReady && _follow && pos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) _map.move(pos, _map.camera.zoom);
      });
    }

    final pickup = ride.pickup;
    final dest = ride.destination;
    if (status == null || pickup == null || dest == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No active ride')),
      );
    }

    final markers = <Marker>[
      pickupMarker(pickup.point),
      destinationMarker(dest.point),
      if (pos != null) vehicleMarker(pos, ride.selected),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AppMap(
              controller: _map,
              center: pickup.point,
              zoom: 15,
              onMapReady: () => _mapReady = true,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _follow) setState(() => _follow = false);
              },
              layers: [
                if (ride.route != null) routeLayer(ride.route!.points),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  if (!_follow && pos != null)
                    CircleIconButton(
                      icon: Icons.center_focus_strong,
                      tooltip: 'Follow driver',
                      onTap: () => setState(() => _follow = true),
                    ),
                  const SizedBox(width: 8),
                  if (status == RideStatus.inProgress || status == RideStatus.driverArrived)
                    CircleIconButton(icon: Icons.sos, color: AppColors.red, tooltip: 'Emergency', onTap: () => _sos(ride, app)),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SheetPanel(child: _statusCard(ride, app, status)),
          ),
        ],
      ),
    );
  }

  Widget _statusCard(RideController ride, AppState app, RideStatus status) {
    return switch (status) {
      RideStatus.searching => _searchingCard(ride, app),
      RideStatus.driverEnRoute || RideStatus.driverArrived => _driverComingCard(ride, app, status),
      RideStatus.inProgress => _inProgressCard(ride, app),
      RideStatus.cancelled => _cancelledCard(ride),
      RideStatus.completed => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
    };
  }

  Widget _searchingCard(RideController ride, AppState app) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Finding your ${ride.selected.label}…', style: AppText.h2),
            const SizedBox(height: 6),
            Text('Drivers near ${ride.pickup!.name} are seeing your request.', style: AppText.muted),
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 6),
            const SizedBox(height: 18),
            SecondaryButton(label: 'Cancel request', color: AppColors.red, onPressed: () => _cancel(ride, app)),
          ],
        );
  }

  Widget _driverComingCard(RideController ride, AppState app, RideStatus status) {
        final arrived = status == RideStatus.driverArrived;
        final d = ride.driver!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    arrived ? 'Your driver has arrived' : '${d.firstName} is on the way',
                    style: AppText.h2,
                  ),
                ),
                Pill(
                  text: arrived ? 'Here now' : '${ride.etaMin} min',
                  color: arrived ? AppColors.green : AppColors.navy,
                  background: arrived ? AppColors.greenSoft : AppColors.navySoft,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              arrived
                  ? 'Look for the ${d.colorName.toLowerCase()} ${d.vehicleDesc} at ${ride.pickup!.name}.'
                  : 'Meet at ${ride.pickup!.name}${ride.note.isEmpty ? '' : ' · "${ride.note}"'}',
              style: AppText.muted,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            _DriverCard(driver: d),
            const SizedBox(height: 12),
            _PinBox(pin: ride.pin),
            const SizedBox(height: 14),
            Row(
              children: [
                _Action(icon: Icons.call, label: 'Call', onTap: () => Launch.call(context, d.phone)),
                _Action(
                  icon: Icons.sms_outlined,
                  label: 'Message',
                  onTap: () => Launch.sms(context, d.phone, 'Hello ${d.firstName}, I\'m at ${ride.pickup!.name}.'),
                ),
                _Action(icon: Icons.share_location, label: 'Share trip', onTap: () => _shareTrip(ride)),
                _Action(icon: Icons.close, label: 'Cancel', color: AppColors.red, onTap: () => _cancel(ride, app)),
              ],
            ),
          ],
        );
  }

  Widget _inProgressCard(RideController ride, AppState app) {
        final d = ride.driver!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(child: Text('On the way', style: AppText.h2)),
                Pill(text: '${ride.etaMin} min left', color: AppColors.navy),
              ],
            ),
            const SizedBox(height: 4),
            Text('Heading to ${ride.destination!.fullLabel}', style: AppText.muted, maxLines: 2),
            const SizedBox(height: 14),
            _DriverCard(driver: d),
            const SizedBox(height: 14),
            Row(
              children: [
                _Action(icon: Icons.share_location, label: 'Share trip', onTap: () => _shareTrip(ride)),
                _Action(icon: Icons.call, label: 'Call driver', onTap: () => Launch.call(context, d.phone)),
                _Action(icon: Icons.sos, label: 'SOS', color: AppColors.red, onTap: () => _sos(ride, app)),
              ],
            ),
          ],
        );
  }

  Widget _cancelledCard(RideController ride) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ride cancelled', style: AppText.h2),
            const SizedBox(height: 6),
            Text(ride.cancelReason ?? '', style: AppText.muted),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Back to home',
              onPressed: () {
                ride.clear();
                Navigator.popUntil(context, (r) => r.isFirst);
              },
            ),
          ],
        );
  }

  Future<void> _cancel(RideController ride, AppState app) async {
    const reasons = [
      'Driver is taking too long',
      'I changed my plans',
      'Wrong pickup location',
      'Driver asked me to cancel',
      'I found another ride',
    ];
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Why are you cancelling?', style: AppText.h2)),
            ),
            for (final r in reasons)
              ListTile(title: Text(r), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.pop(ctx, r)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SecondaryButton(label: 'Keep my ride', onPressed: () => Navigator.pop(ctx)),
            ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final hadDriver = ride.driver != null;
    ride.cancel(reason);
    if (hadDriver) app.addHistory(ride.cancelledRecord());
  }

  void _shareTrip(RideController ride) {
    final text = ride.shareText();
    final contacts = context.read<AppState>().contacts;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(alignment: Alignment.centerLeft, child: Text('Share your trip', style: AppText.h2)),
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE7F8EE), child: Icon(Icons.chat, color: Color(0xFF25D366))),
              title: const Text('WhatsApp'),
              subtitle: const Text('Send to anyone'),
              onTap: () {
                Navigator.pop(ctx);
                Launch.whatsApp(context, text);
              },
            ),
            for (final c in contacts)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.sms_outlined)),
                title: Text('SMS ${c.name}'),
                subtitle: Text(c.phone),
                onTap: () {
                  Navigator.pop(ctx);
                  Launch.sms(context, c.phone, text);
                },
              ),
            if (contacts.isEmpty)
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Add trusted contacts in Safety to share by SMS in one tap'),
              ),
          ],
        ),
      ),
    );
  }

  void _sos(RideController ride, AppState app) {
    final text = 'EMERGENCY - I need help. ${ride.shareText()}';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Emergency help', style: AppText.h2),
              const SizedBox(height: 4),
              const Text('Your trip details are ready to send.', style: AppText.muted),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Call emergency ${AppConfig.emergencyNumber}',
                icon: Icons.call,
                color: AppColors.red,
                onPressed: () => Launch.call(context, AppConfig.emergencyNumber),
              ),
              const SizedBox(height: 10),
              for (final c in app.contacts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SecondaryButton(
                    label: 'Alert ${c.name}',
                    icon: Icons.sms,
                    color: AppColors.red,
                    onPressed: () => Launch.sms(context, c.phone, text),
                  ),
                ),
              SecondaryButton(
                label: 'Call CarryMe safety line',
                icon: Icons.support_agent,
                onPressed: () => Launch.call(context, AppConfig.supportPhone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final Driver driver;
  const _DriverCard({required this.driver});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(name: driver.name, size: 54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: Text(driver.name, style: AppText.h3, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, size: 16, color: AppColors.navy),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5B301)),
                  Text(' ${driver.rating.toStringAsFixed(1)} · ${driver.trips} trips', style: AppText.small),
                ],
              ),
              Text('${driver.colorName} ${driver.vehicleDesc}', style: AppText.small),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8D6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.ink, width: 1.5),
          ),
          child: Text(driver.plate, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ],
    );
  }
}

class _PinBox extends StatelessWidget {
  final String pin;
  const _PinBox({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.navySoft, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.pin, color: AppColors.navy),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Give this PIN to your driver to start the ride', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(pin, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4, color: AppColors.navy)),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _Action({required this.icon, required this.label, required this.onTap, this.color = AppColors.navy});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              CircleAvatar(radius: 24, backgroundColor: color.withAlpha(24), child: Icon(icon, color: color)),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
