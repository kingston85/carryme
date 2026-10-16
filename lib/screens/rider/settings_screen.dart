import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/money.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = app.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                InitialsAvatar(name: user.name, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: AppText.h2),
                      Text(LiberiaPhone.pretty(user.phone), style: AppText.muted),
                      if (user.email.isNotEmpty) Text(user.email, style: AppText.small),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, app)),
              ],
            ),
          ),
          const SectionTitle('Saved places'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.home_rounded),
                  title: const Text('Home'),
                  subtitle: Text(app.home?.fullLabel ?? 'Not set - use ⋮ on any search result'),
                  trailing: app.home == null
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: () => app.setHome(null)),
                ),
                ListTile(
                  leading: const Icon(Icons.work_rounded),
                  title: const Text('Work'),
                  subtitle: Text(app.work?.fullLabel ?? 'Not set - use ⋮ on any search result'),
                  trailing: app.work == null
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: () => app.setWork(null)),
                ),
              ],
            ),
          ),
          const SectionTitle('Prices'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Show prices in', style: AppText.h3),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<CurrencyPref>(
                    segments: const [
                      ButtonSegment(value: CurrencyPref.lrd, label: Text('L\$')),
                      ButtonSegment(value: CurrencyPref.usd, label: Text('US\$')),
                      ButtonSegment(value: CurrencyPref.both, label: Text('Both')),
                    ],
                    selected: {app.currency},
                    onSelectionChanged: (s) => app.setCurrency(s.first),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Today\'s rate: US\$1 = ${Money.lrd(AppConfig.lrdPerUsd)}', style: AppText.small),
              ],
            ),
          ),
          const SectionTitle('Data & network'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                SwitchListTile(
                  value: app.dataSaver,
                  onChanged: app.setDataSaver,
                  title: const Text('Data saver', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Uses less mobile data on maps - good for slow connections'),
                ),
                SwitchListTile(
                  value: app.simulateRain,
                  onChanged: app.setSimulateRain,
                  title: const Text('Rain pricing (demo)', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('In the live app this is switched on by operations during heavy rain'),
                ),
              ],
            ),
          ),
          const SectionTitle('Account'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.local_taxi),
                  title: const Text('Switch to driver mode'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.popUntil(context, (r) => r.isFirst);
                    app.setMode(AppMode.driver);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About CarryMe'),
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppConfig.appName,
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Made for Liberia 🇱🇷\nMap data © OpenStreetMap contributors',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.red),
                  title: const Text('Log out', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700)),
                  onTap: () {
                    Navigator.popUntil(context, (r) => r.isFirst);
                    app.logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, AppState app) async {
    final name = TextEditingController(text: app.user!.name);
    final email = TextEditingController(text: app.user!.email);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (for receipts)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      app.updateProfile(name: name.text.trim(), email: email.text.trim());
    }
  }
}
