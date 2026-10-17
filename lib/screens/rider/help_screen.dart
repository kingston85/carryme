import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../theme/app_theme.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How are prices worked out?',
      'You see the full price before you book. It is based on distance and time, with extra for night trips, '
          'heavy rain and the airport. Prices are rounded up to the nearest L\$5 so cash is easy.'
    ),
    (
      'Can I pay in US dollars?',
      'Yes. Choose "Cash (US\$)". The app shows the US\$ amount and the driver gives change in L\$ at the day\'s rate.'
    ),
    (
      'How does Orange Money or MTN MoMo work?',
      'At the end of the trip you get a payment prompt on your phone. Enter your mobile money PIN to approve. '
          'You can also top up your CarryMe wallet in advance.'
    ),
    (
      'Why can\'t I book a pen-pen?',
      'Motorbikes are not allowed in some parts of Monrovia, and pen-pen and keke are not offered for long-distance trips. '
          'The app hides them when they are not allowed.'
    ),
    (
      'What is a shared taxi?',
      'You book one or more seats in a taxi that may pick up other riders going the same way. It costs less than booking the whole car.'
    ),
    (
      'I left something in the vehicle',
      'Open Your trips, tap the ride, and call or message support with the trip ID. We will contact the driver.'
    ),
    (
      'How do I become a driver?',
      'Open the menu and tap "Drive with CarryMe". Upload your documents and we will verify you, usually within 2 working days.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: AppCard(
                  onTap: () => Launch.whatsApp(context, 'Hello CarryMe support, ', number: AppConfig.supportWhatsApp),
                  child: const Column(
                    children: [
                      Icon(Icons.chat, color: Color(0xFF25D366), size: 30),
                      SizedBox(height: 6),
                      Text('WhatsApp us', style: AppText.h3),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppCard(
                  onTap: () => Launch.call(context, AppConfig.supportPhone),
                  child: const Column(
                    children: [
                      Icon(Icons.call, color: AppColors.navy, size: 30),
                      SizedBox(height: 6),
                      Text('Call support', style: AppText.h3),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SectionTitle('Common questions'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: Column(
                children: [
                  for (final f in _faqs)
                    ExpansionTile(
                      title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      children: [Text(f.$2, style: AppText.muted)],
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
