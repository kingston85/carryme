import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/user.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/launch.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            color: AppColors.redSoft,
            child: Row(
              children: [
                const Icon(Icons.sos, color: AppColors.red, size: 36),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In an emergency', style: AppText.h3),
                      Text('Call for help right away. The SOS button is on every trip screen.', style: AppText.small),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.red),
                  onPressed: () => Launch.call(context, AppConfig.emergencyNumber),
                  child: const Text('Call ${AppConfig.emergencyNumber}'),
                ),
              ],
            ),
          ),
          SectionTitle(
            'Trusted contacts',
            trailing: TextButton.icon(
              onPressed: () => _addContact(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ),
          if (app.contacts.isEmpty)
            const AppCard(
              child: Text(
                'Add family or friends. You can send them your live trip details by SMS or WhatsApp in one tap.',
                style: AppText.muted,
              ),
            ),
          for (final c in app.contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InitialsAvatar(name: c.name, size: 40),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(LiberiaPhone.pretty(c.phone)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => app.removeContact(c),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SwitchListTile(
              value: app.autoShareTrips,
              onChanged: app.setAutoShare,
              title: const Text('Share every trip automatically', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Opens sharing as soon as a driver is assigned'),
            ),
          ),
          const SectionTitle('How CarryMe keeps you safe'),
          const _Feature(Icons.verified_user, 'Verified drivers',
              'Every driver submits a driver\'s licence, vehicle registration, insurance and police clearance before driving.'),
          const _Feature(Icons.pin, 'Ride PIN',
              'Your trip only starts when you give the driver your 4-digit PIN - so you never enter the wrong vehicle.'),
          const _Feature(Icons.share_location, 'Live trip sharing',
              'Send your driver, plate number and route to family on WhatsApp or SMS.'),
          const _Feature(Icons.two_wheeler, 'Helmets on pen-pen',
              'Pen-pen drivers must carry a helmet for you. Ask for it before you climb on.'),
          const _Feature(Icons.nightlight_round, 'Night rides',
              'After 10pm, sit in the back, share your trip and check the plate matches the app.'),
        ],
      ),
    );
  }

  Future<void> _addContact(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add trusted contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (e.g. 0886 123 456)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !context.mounted) return;
    final e164 = LiberiaPhone.e164(phone.text);
    if (name.text.trim().isEmpty || e164 == null) {
      showSnack(context, 'Enter a name and a valid Liberian number.');
      return;
    }
    context.read<AppState>().addContact(EmergencyContact(name: name.text.trim(), phone: e164));
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Feature(this.icon, this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(backgroundColor: AppColors.navySoft, child: Icon(icon, color: AppColors.navy, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.h3),
                const SizedBox(height: 2),
                Text(body, style: AppText.muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
