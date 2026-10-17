import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/payment.dart';
import '../../services/money.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet & payment')),
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
                Row(
                  children: [
                    const Text('CarryMe Wallet', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Icon(Icons.star_rounded, color: Colors.white.withAlpha(150)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(Money.lrd(app.walletLrd),
                    style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                Text('≈ ${Money.usdFromLrd(app.walletLrd)}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _topUpButton(context, PaymentMethod.orangeMoney)),
                    const SizedBox(width: 10),
                    Expanded(child: _topUpButton(context, PaymentMethod.mtnMomo)),
                  ],
                ),
              ],
            ),
          ),
          const SectionTitle('Default payment'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final m in PaymentMethod.values)
                  ListTile(
                    leading: CircleAvatar(backgroundColor: m.color.withAlpha(30), child: Icon(m.icon, color: m.color)),
                    title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: app.defaultPayment == m
                        ? const Icon(Icons.check_circle, color: AppColors.navy)
                        : const Icon(Icons.circle_outlined, color: AppColors.line),
                    onTap: () => app.setDefaultPayment(m),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Cash in US\$ is accepted - drivers give change in L\$ at the day\'s rate '
            '(US\$1 = ${Money.lrd(AppConfig.lrdPerUsd)}).',
            style: AppText.small,
          ),
          const SectionTitle('Recent activity'),
          if (app.walletTxns.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No wallet activity yet.', style: AppText.muted),
            ),
          for (final t in app.walletTxns.take(20))
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(t.amount >= 0 ? Icons.south_west : Icons.north_east,
                  color: t.amount >= 0 ? AppColors.green : AppColors.red),
              title: Text(t.label),
              subtitle: Text(DateFormat('d MMM, h:mm a').format(t.date)),
              trailing: Text(
                '${t.amount >= 0 ? '+' : '-'}${Money.lrd(t.amount.abs())}',
                style: TextStyle(fontWeight: FontWeight.w800, color: t.amount >= 0 ? AppColors.green : AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topUpButton(BuildContext context, PaymentMethod m) => FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          backgroundColor: Colors.white,
          builder: (_) => _TopUpSheet(method: m),
        ),
        icon: Icon(m.icon, color: m.color, size: 20),
        label: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}

class _TopUpSheet extends StatefulWidget {
  final PaymentMethod method;
  const _TopUpSheet({required this.method});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  static const _amounts = [500.0, 1000.0, 2500.0, 5000.0];
  double _amount = 1000;
  late final TextEditingController _phone;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AppState>().user;
    _phone = TextEditingController(text: user == null ? '' : LiberiaPhone.pretty(user.phone));
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (LiberiaPhone.e164(_phone.text) == null) {
      showSnack(context, 'Enter a valid mobile money number.');
      return;
    }
    setState(() => _sending = true);
    // DEMO: integrate the Orange Money / MTN MoMo merchant API on your server.
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    context.read<AppState>().topUp(_amount, widget.method);
    Navigator.pop(context);
    showSnack(context, '${Money.lrd(_amount)} added to your wallet');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Top up with ${widget.method.label}', style: AppText.h2),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in _amounts)
                ChoiceChip(
                  label: Text(Money.lrd(a)),
                  selected: _amount == a,
                  onSelected: (_) => setState(() => _amount = a),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '${widget.method.label} number',
              prefixIcon: Icon(widget.method.icon, color: widget.method.color),
              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 10),
          const Text('You will get a prompt on your phone. Enter your mobile money PIN to approve.',
              style: AppText.small),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Send payment request · ${Money.lrd(_amount)}',
            loading: _sending,
            color: widget.method.color,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
