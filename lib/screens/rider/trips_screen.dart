import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/ride.dart';
import '../../services/money.dart';
import '../../state/app_state.dart';
import '../../state/ride_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'choose_ride_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your trips'),
          bottom: TabBar(tabs: [
            Tab(text: 'Past (${app.history.length})'),
            Tab(text: 'Scheduled (${app.scheduled.length})'),
          ]),
        ),
        body: TabBarView(
          children: [
            _list(context, app.history, emptyText: 'No trips yet. Your rides will show here.'),
            _list(context, app.scheduled, emptyText: 'No scheduled rides. Plan ahead for early flights or appointments.'),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<RideRecord> rides, {required String emptyText}) {
    if (rides.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.receipt_long, size: 56, color: AppColors.line),
              const SizedBox(height: 12),
              Text(emptyText, textAlign: TextAlign.center, style: AppText.muted),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TripCard(ride: rides[i]),
    );
  }
}

class _TripCard extends StatelessWidget {
  final RideRecord ride;
  const _TripCard({required this.ride});

  @override
  Widget build(BuildContext context) {
    final (label, color, bg) = switch (ride.status) {
      'cancelled' => ('Cancelled', AppColors.red, AppColors.redSoft),
      'scheduled' => ('Scheduled', AppColors.navy, AppColors.navySoft),
      _ => ('Completed', AppColors.green, AppColors.greenSoft),
    };
    return AppCard(
      onTap: () => _details(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ride.vehicle.icon, color: AppColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('EEE d MMM yyyy · h:mm a').format(ride.date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Pill(text: label, color: color, background: bg),
            ],
          ),
          const SizedBox(height: 12),
          RouteSummary(from: ride.pickup.name, to: ride.destination.name),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${ride.vehicle.label} · ${ride.payment.label}', style: AppText.small),
              const Spacer(),
              if (ride.status != 'cancelled')
                Text(Money.lrd(ride.fareLrd + ride.tipLrd), style: AppText.h3),
            ],
          ),
        ],
      ),
    );
  }

  void _details(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ride.status == 'scheduled' ? 'Scheduled ride' : 'Receipt', style: AppText.h2),
              const SizedBox(height: 4),
              Text('Trip ID ${ride.id}', style: AppText.small),
              const SizedBox(height: 16),
              RouteSummary(
                from: ride.pickup.name,
                fromSub: ride.pickup.area,
                to: ride.destination.name,
                toSub: ride.destination.area,
              ),
              const Divider(height: 28),
              _row('Date', DateFormat('EEE d MMM yyyy, h:mm a').format(ride.date)),
              _row('Ride', '${ride.vehicle.label}${ride.seats > 1 ? ' · ${ride.seats} seats' : ''}'),
              if (ride.driverName.isNotEmpty) _row('Driver', '${ride.driverName} · ${ride.plate}'),
              if (ride.distanceKm > 0) _row('Distance', '${ride.distanceKm.toStringAsFixed(1)} km'),
              _row('Payment', ride.payment.label),
              if (ride.status != 'cancelled') _row('Fare', Money.lrd(ride.fareLrd)),
              if (ride.tipLrd > 0) _row('Tip', Money.lrd(ride.tipLrd)),
              if (ride.rating > 0) _row('Your rating', '${'★' * ride.rating}${'☆' * (5 - ride.rating)}'),
              const SizedBox(height: 16),
              if (ride.status == 'scheduled')
                SecondaryButton(
                  label: 'Cancel scheduled ride',
                  color: AppColors.red,
                  onPressed: () {
                    context.read<AppState>().removeScheduled(ride.id);
                    Navigator.pop(ctx);
                  },
                )
              else
                PrimaryButton(
                  label: 'Book this trip again',
                  icon: Icons.replay,
                  onPressed: () {
                    final app = context.read<AppState>();
                    context.read<RideController>().startPlanning(
                          pickup: ride.pickup,
                          destination: ride.destination,
                          defaultPayment: app.defaultPayment,
                          raining: app.simulateRain,
                          preferred: ride.vehicle,
                        );
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChooseRideScreen()));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: AppText.muted)),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
