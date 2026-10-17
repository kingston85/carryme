import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../state/driver_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';
import '../rider/help_screen.dart';
import 'driver_documents_screen.dart';
import 'driver_earnings_screen.dart';
import 'driver_vehicle_screen.dart';

class DriverDrawer extends StatelessWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user!;

    void go(Widget screen) {
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.navyDark,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 22),
            child: Row(
              children: [
                InitialsAvatar(name: user.name, size: 58, color: AppColors.red),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(LiberiaPhone.pretty(user.phone), style: TextStyle(color: Colors.white.withAlpha(200))),
                      const SizedBox(height: 6),
                      const Pill(text: 'DRIVER', color: Colors.white, background: AppColors.red),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => go(const DriverEarningsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Documents', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => go(const DriverDocumentsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.directions_car_outlined),
            title: const Text('My vehicle', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => go(const DriverVehicleScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & support', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => go(const HelpScreen()),
          ),
          const Divider(height: 28),
          ListTile(
            leading: const Icon(Icons.hail, color: AppColors.navy),
            title: const Text('Switch to rider mode', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              context.read<DriverController>().detach();
              Navigator.pop(context);
              context.read<AppState>().setMode(AppMode.rider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.red),
            title: const Text('Log out', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
            onTap: () {
              context.read<DriverController>().detach();
              Navigator.pop(context);
              context.read<AppState>().logout();
            },
          ),
        ],
      ),
    );
  }
}
