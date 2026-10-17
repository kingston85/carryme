import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/money.dart';
import '../../state/driver_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final drv = context.watch<DriverController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Earnings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.navy, AppColors.navyDark]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available to cash out', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(Money.lrd(drv.availableBalance),
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                Text('≈ ${Money.usdFromLrd(drv.availableBalance)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.navy),
                  onPressed: drv.availableBalance <= 0
                      ? null
                      : () {
                          final amt = drv.availableBalance;
                          drv.cashOut(amt);
                          showSnack(context, '${Money.lrd(amt)} sent to your mobile money (demo)');
                        },
                  icon: const Icon(Icons.phone_android),
                  label: const Text('Cash out to Orange Money / MTN MoMo'),
                ),
                const SizedBox(height: 6),
                const Text('Note: in-app trips paid in cash are already in your pocket.',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _tile('Today', Money.lrd(drv.todayEarnings), '${drv.todayTrips.length} trips'),
              const SizedBox(width: 10),
              _tile('Last 7 days', Money.lrd(drv.weekEarnings), '${drv.trips.length} trips'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'CarryMe keeps a ${(AppConfig.commissionRate * 100).round()}% service fee on each fare. Tips are 100% yours.',
            style: AppText.small,
          ),
          const SectionTitle('Trip history'),
          if (drv.trips.isEmpty)
            const AppCard(child: Text('Go online and complete trips to see your earnings here.', style: AppText.muted)),
          for (final t in drv.trips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Icon(t.job.vehicle.icon, color: AppColors.navy),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${t.job.pickup.name} → ${t.job.destination.name}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.h3),
                          Text('${DateFormat('d MMM, h:mm a').format(t.date)} · ${t.job.payment.label}', style: AppText.small),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(Money.lrd(t.earningLrd), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green)),
                        Text('fare ${Money.lrd(t.fareLrd)}', style: AppText.small),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, String sub) => Expanded(
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.small),
              const SizedBox(height: 4),
              Text(value, style: AppText.h2),
              Text(sub, style: AppText.small),
            ],
          ),
        ),
      );
}
