import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/launch.dart';
import '../../widgets/common.dart';

class PromotionsScreen extends StatelessWidget {
  const PromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = app.user?.referralCode ?? '';
    final invite = 'Ride with CarryMe - pen-pen, keke and taxi across Liberia, '
        'pay with cash, Orange Money or MTN MoMo. Use my code $code for a discount on your first ride!';

    return Scaffold(
      appBar: AppBar(title: const Text('Promotions')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.card_giftcard, color: Colors.white, size: 34),
                const SizedBox(height: 10),
                const Text('Invite friends, ride for less',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Share your code. When a friend takes their first ride, you both get a discount.',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Text(code,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.red),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        showSnack(context, 'Code copied');
                      },
                      icon: const Icon(Icons.copy),
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF25D366)),
                      onPressed: () => Launch.whatsApp(context, invite),
                      icon: const Icon(Icons.chat),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('Available offers'),
          for (final e in AppConfig.promoCodes.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.greenSoft,
                      child: Text('${(e.value * 100).round()}%',
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.key, style: AppText.h3),
                          Text(AppConfig.promoDescriptions[e.key] ?? '', style: AppText.small),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: e.key));
                        showSnack(context, '${e.key} copied - add it when you book');
                      },
                      child: const Text('Copy'),
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
