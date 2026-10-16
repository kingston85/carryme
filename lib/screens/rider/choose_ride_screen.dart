import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/payment.dart';
import '../../models/vehicle_type.dart';
import '../../services/fare_service.dart';
import '../../services/money.dart';
import '../../state/app_state.dart';
import '../../state/ride_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_map.dart';
import '../../widgets/common.dart';
import 'trip_screen.dart';

class ChooseRideScreen extends StatefulWidget {
  const ChooseRideScreen({super.key});

  @override
  State<ChooseRideScreen> createState() => _ChooseRideScreenState();
}

class _ChooseRideScreenState extends State<ChooseRideScreen> {
  final MapController _map = MapController();
  bool _mapReady = false;
  bool _fitted = false;

  void _fit(List<LatLng> pts) {
    if (!_mapReady || pts.length < 2) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(50, 90, 50, 30),
      maxZoom: 16,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideController>();
    final app = context.watch<AppState>();
    final pickup = ride.pickup!;
    final dest = ride.destination!;
    final pts = ride.route?.points ?? [pickup.point, dest.point];

    if (ride.route != null && _mapReady && !_fitted) {
      _fitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit(pts);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.34,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppMap(
                    controller: _map,
                    center: pickup.point,
                    zoom: 13,
                    onMapReady: () {
                      _mapReady = true;
                      _fit(pts);
                    },
                    layers: [
                      if (ride.route != null) routeLayer(pts),
                      MarkerLayer(markers: [pickupMarker(pickup.point), destinationMarker(dest.point)]),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircleIconButton(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ride.route == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Working out the best route…', style: AppText.muted),
                      ],
                    ),
                  )
                : _panel(context, ride, app),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, RideController ride, AppState app) {
    final route = ride.route!;
    final q = ride.quoteFor(ride.selected);
    final chips = <Widget>[
      if (ride.isAirportTrip) const Pill(text: 'Airport trip', icon: Icons.flight, color: AppColors.navy),
      if (ride.raining)
        const Pill(text: 'Rain pricing', icon: Icons.water_drop, color: AppColors.navy),
      if (FareService.isNight(ride.scheduledAt ?? DateTime.now()))
        const Pill(text: 'Night fare', icon: Icons.nightlight_round, color: AppColors.amber, background: AppColors.amberSoft),
      if (ride.promoCode != null)
        Pill(text: '${ride.promoCode} applied', icon: Icons.local_offer, color: AppColors.green, background: AppColors.greenSoft),
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: [
              RouteSummary(
                from: ride.pickup!.name,
                fromSub: ride.pickup!.area,
                to: ride.destination!.name,
                toSub: ride.destination!.area,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.route, size: 16, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    '${route.distanceKm.toStringAsFixed(1)} km · about ${route.durationMin.ceil()} min'
                    '${route.isEstimate ? ' (estimate)' : ' in Monrovia traffic'}',
                    style: AppText.small,
                  ),
                ],
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: chips),
              ],
              const SizedBox(height: 14),
              for (final v in VehicleType.values) _vehicleCard(v, ride, app),
              if (ride.selected == VehicleType.sharedTaxi) _seatPicker(ride),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: Icon(ride.payment.icon, size: 18, color: ride.payment.color),
                    label: Text(ride.payment.label),
                    onPressed: () => _pickPayment(ride, app),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.local_offer_outlined, size: 18),
                    label: Text(ride.promoCode ?? 'Promo code'),
                    onPressed: () => _promo(ride, app),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(ride.scheduledAt == null
                        ? 'Ride now'
                        : DateFormat('EEE d MMM, h:mm a').format(ride.scheduledAt!)),
                    onPressed: () => _schedule(ride),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.edit_note, size: 18),
                    label: Text(ride.note.isEmpty ? 'Note to driver' : 'Note added'),
                    onPressed: () => _note(ride),
                  ),
                ],
              ),
              if (q != null) ...[
                const SizedBox(height: 10),
                _Breakdown(quote: q, currency: app.currency),
              ],
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3))],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: PrimaryButton(
                label: q == null
                    ? 'Choose a ride'
                    : '${ride.scheduledAt == null ? 'Book' : 'Schedule'} ${ride.selected.label} · ${Money.primary(q.total, app.currency)}',
                onPressed: q == null || !ride.isAllowed(ride.selected) ? null : () => _book(ride, app, q),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _vehicleCard(VehicleType v, RideController ride, AppState app) {
    final reason = ride.restriction(v);
    final q = ride.quoteFor(v);
    final selected = ride.selected == v && reason == null;
    final secondary = q == null ? null : Money.secondary(q.total, app.currency);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppColors.navySoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: reason == null ? () => ride.selectVehicle(v) : () => showSnack(context, reason),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppColors.navy : AppColors.line, width: selected ? 2 : 1),
            ),
            child: Opacity(
              opacity: reason == null ? 1 : 0.45,
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navy : AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(v.icon, size: 30, color: selected ? Colors.white : AppColors.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(v.label, style: AppText.h3),
                            const SizedBox(width: 6),
                            const Icon(Icons.person, size: 14, color: AppColors.muted),
                            Text('${v.capacity}', style: AppText.small),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(reason ?? v.subtitle, style: AppText.small, maxLines: 2),
                        if (reason == null) ...[
                          const SizedBox(height: 2),
                          Text('${ride.pickupEtaFor(v)} min away',
                              style: const TextStyle(color: AppColors.green, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ],
                    ),
                  ),
                  if (q != null && reason == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Money.primary(q.total, app.currency),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        if (secondary != null) Text(secondary, style: AppText.small),
                        if (v == VehicleType.sharedTaxi) const Text('per booking', style: AppText.small),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seatPicker(RideController ride) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.event_seat, color: AppColors.navy),
              const SizedBox(width: 10),
              const Expanded(child: Text('Seats needed', style: AppText.h3)),
              IconButton(
                onPressed: ride.seats > 1 ? () => ride.setSeats(ride.seats - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('${ride.seats}', style: AppText.h2),
              IconButton(
                onPressed: ride.seats < 3 ? () => ride.setSeats(ride.seats + 1) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      );

  void _pickPayment(RideController ride, AppState app) {
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
              child: Align(alignment: Alignment.centerLeft, child: Text('Pay with', style: AppText.h2)),
            ),
            for (final m in PaymentMethod.values)
              ListTile(
                leading: CircleAvatar(backgroundColor: m.color.withAlpha(30), child: Icon(m.icon, color: m.color)),
                title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(switch (m) {
                  PaymentMethod.wallet => 'Balance ${Money.lrd(app.walletLrd)}',
                  PaymentMethod.orangeMoney || PaymentMethod.mtnMomo => 'Approve the prompt on your phone after the trip',
                  PaymentMethod.cashUsd => 'Driver gives change in L\$ at today\'s rate',
                  PaymentMethod.cashLrd => 'Pay the driver at the end of the trip',
                }),
                trailing: ride.payment == m ? const Icon(Icons.check_circle, color: AppColors.navy) : null,
                onTap: () {
                  ride.setPayment(m);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _promo(RideController ride, AppState app) async {
    if (ride.promoCode != null) {
      ride.removePromo();
      showSnack(context, 'Promo removed');
      return;
    }
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add promo code'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. WELCOME'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Apply')),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    final error = ride.applyPromo(code, firstRideDone: app.firstRideDone);
    showSnack(context, error ?? 'Promo applied - ${AppConfig.promoDescriptions[code.trim().toUpperCase()] ?? ''}');
  }

  Future<void> _schedule(RideController ride) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('Ride now'),
              onTap: () => Navigator.pop(ctx, 'now'),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Schedule for later'),
              subtitle: const Text('Up to 7 days ahead - great for early flights at RIA'),
              onTap: () => Navigator.pop(ctx, 'later'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'now') {
      ride.setSchedule(null);
      return;
    }
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (when.isBefore(now.add(const Duration(minutes: 20)))) {
      showSnack(context, 'Pick a time at least 20 minutes from now.');
      return;
    }
    ride.setSchedule(when);
  }

  Future<void> _note(RideController ride) async {
    final ctrl = TextEditingController(text: ride.note);
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Note to driver'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 140,
          decoration: const InputDecoration(hintText: 'e.g. I\'m by the blue gate behind the church'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (note != null) ride.setNote(note);
  }

  void _book(RideController ride, AppState app, FareQuote q) {
    if (ride.payment == PaymentMethod.wallet && app.walletLrd < q.total) {
      showSnack(context, 'Your wallet balance is too low. Top up or choose another way to pay.');
      return;
    }
    if (ride.scheduledAt != null) {
      app.addScheduled(ride.scheduledRecord());
      showSnack(context, 'Ride scheduled for ${DateFormat('EEE d MMM, h:mm a').format(ride.scheduledAt!)}');
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }
    ride.requestRide();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TripScreen()));
  }
}

class _Breakdown extends StatelessWidget {
  final FareQuote quote;
  final CurrencyPref currency;
  const _Breakdown({required this.quote, required this.currency});

  @override
  Widget build(BuildContext context) {
    Widget row(String l, double v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: color))),
              Text(Money.lrd(v), style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
            ],
          ),
        );
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text('Fare breakdown', style: AppText.h3),
        subtitle: Text('Upfront price - ${Money.full(quote.total, currency)}', style: AppText.small),
        children: [
          row('Base fare', quote.base),
          row('Distance (${quote.distanceKm.toStringAsFixed(1)} km)', quote.distanceCharge),
          row('Time (${quote.durationMin.ceil()} min)', quote.timeCharge),
          for (final e in quote.extras) row(e.label, e.amount),
          if (quote.seats > 1) Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('× ${quote.seats} seats', style: AppText.small),
          ),
          if (quote.discount > 0) row('Promo discount', -quote.discount, color: AppColors.green),
          const Divider(),
          row('Total (rounded)', quote.total, bold: true),
          const SizedBox(height: 4),
          Text('US\$1 = ${Money.lrd(AppConfig.lrdPerUsd)} today', style: AppText.small),
        ],
      ),
    );
  }
}
