import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/money.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';
import 'help_screen.dart';
import 'promotions_screen.dart';
import 'safety_screen.dart';
import 'settings_screen.dart';
import 'trips_screen.dart';
import 'wallet_screen.dart';

class RiderDrawer extends StatelessWidget {
  const RiderDrawer({super.key});

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
            color: AppColors.navy,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 22),
            child: Row(
              children: [
                InitialsAvatar(name: user.name, size: 58, color: AppColors.red),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(LiberiaPhone.pretty(user.phone), style: TextStyle(color: Colors.white.withAlpha(200))),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFF5B301), size: 18),
                          const SizedBox(width: 3),
                          Text(user.rating.toStringAsFixed(1),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _item(Icons.receipt_long_outlined, 'Your trips', () => go(const TripsScreen())),
          _item(
            Icons.account_balance_wallet_outlined,
            'Wallet & payment',
            () => go(const WalletScreen()),
            trailing: Text(Money.lrd(app.walletLrd), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _item(Icons.local_offer_outlined, 'Promotions', () => go(const PromotionsScreen())),
          _item(Icons.shield_outlined, 'Safety', () => go(const SafetyScreen())),
          _item(Icons.settings_outlined, 'Settings', () => go(const SettingsScreen())),
          _item(Icons.help_outline, 'Help & support', () => go(const HelpScreen())),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              color: AppColors.navySoft,
              onTap: () {
                Navigator.pop(context);
                context.read<AppState>().setMode(AppMode.driver);
              },
              child: const Row(
                children: [
                  Icon(Icons.local_taxi, color: AppColors.navy, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Drive with CarryMe', style: AppText.h3),
                        Text('Earn with your car, keke or motorbike', style: AppText.small),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap, {Widget? trailing}) => ListTile(
        leading: Icon(icon, color: AppColors.ink),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: trailing,
        onTap: onTap,
      );
}
