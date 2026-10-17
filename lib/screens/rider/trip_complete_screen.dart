import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment.dart';
import '../../services/money.dart';
import '../../state/app_state.dart';
import '../../state/ride_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class TripCompleteScreen extends StatefulWidget {
  const TripCompleteScreen({super.key});

  @override
  State<TripCompleteScreen> createState() => _TripCompleteScreenState();
}

class _TripCompleteScreenState extends State<TripCompleteScreen> {
  int _rating = 5;
  double _tip = 0;
  final Set<String> _compliments = {};
  final _comment = TextEditingController();
  bool _momoApproved = false;

  static const _tips = [0.0, 50.0, 100.0, 200.0];
  static const _good = ['Safe driving', 'Clean vehicle', 'Knew the road', 'Friendly', 'Good music', 'On time'];
  static const _bad = ['Unsafe driving', 'Took a longer route', 'Overcharged', 'Rude', 'Vehicle not clean', 'Late'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _done() {
    final ride = context.read<RideController>();
    final app = context.read<AppState>();
    final record = ride.completedRide;
    if (record == null) {
      ride.clear();
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }
    if (record.payment == PaymentMethod.wallet) {
      final ok = app.payFromWallet(record.fareLrd + _tip, 'Ride to ${record.destination.name}');
      if (!ok) {
        showSnack(context, 'Wallet balance too low - please pay the driver in cash.');
      }
    }
    app.addHistory(record.copyWith(rating: _rating, tipLrd: _tip));
    final comment = [..._compliments, if (_comment.text.trim().isNotEmpty) _comment.text.trim()].join('; ');
    ride.submitRating(rating: _rating, tipLrd: _tip, comment: comment);
    ride.clear();
    showSnack(context, 'Thanks for riding with CarryMe!');
    Navigator.popUntil(context, (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideController>();
    final app = context.watch<AppState>();
    final record = ride.completedRide;
    if (record == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Trip finished')),
      );
    }
    final total = record.fareLrd + _tip;
    final options = _rating >= 4 ? _good : _bad;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            const Center(
              child: CircleAvatar(
                radius: 38,
                backgroundColor: AppColors.greenSoft,
                child: Icon(Icons.check_rounded, size: 46, color: AppColors.green),
              ),
            ),
            const SizedBox(height: 14),
            const Text('You have arrived!', textAlign: TextAlign.center, style: AppText.h1),
            const SizedBox(height: 4),
            Text(record.destination.fullLabel, textAlign: TextAlign.center, style: AppText.muted),
            const SizedBox(height: 22),
            AppCard(
              child: Column(
                children: [
                  Text(Money.lrd(total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                  Text('≈ ${Money.usdFromLrd(total)}', style: AppText.muted),
                  const SizedBox(height: 12),
                  _paymentStatus(record.payment, total),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('How was your ride with ${record.driverName.split(' ').first}?',
                textAlign: TextAlign.center, style: AppText.h3),
            StarRating(value: _rating, onChanged: (v) => setState(() {
              _rating = v;
              _compliments.clear();
            })),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in options)
                  FilterChip(
                    label: Text(c),
                    selected: _compliments.contains(c),
                    onSelected: (s) => setState(() => s ? _compliments.add(c) : _compliments.remove(c)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _comment,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Anything else? (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              ),
            ),
            if (_rating >= 4) ...[
              const SizedBox(height: 22),
              const Text('Add a tip', style: AppText.h3),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final t in _tips)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(t == 0 ? 'No tip' : Money.lrd(t), textAlign: TextAlign.center),
                          ),
                          selected: _tip == t,
                          onSelected: (_) => setState(() => _tip = t),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('100% of tips go to your driver.', style: AppText.small),
            ],
            const SizedBox(height: 26),
            PrimaryButton(
              label: 'Done',
              onPressed: record.payment.isMobileMoney && !_momoApproved ? null : _done,
            ),
            if (record.payment.isMobileMoney && !_momoApproved)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Confirm your mobile money payment first.', textAlign: TextAlign.center, style: AppText.small),
              ),
            const SizedBox(height: 6),
            Center(child: Text('Trip ID ${record.id} · ${app.user?.firstName ?? ''}', style: AppText.small)),
          ],
        ),
      ),
    );
  }

  Widget _paymentStatus(PaymentMethod m, double total) {
    if (m.isMobileMoney) {
      if (_momoApproved) {
        return Pill(text: 'Paid with ${m.label}', icon: Icons.check_circle, color: AppColors.green, background: AppColors.greenSoft);
      }
      return Column(
        children: [
          Text('A ${m.label} request for ${Money.lrd(total)} has been sent to your phone. '
              'Enter your PIN on the prompt to approve.', textAlign: TextAlign.center, style: AppText.muted),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'I approved the payment',
            icon: m.icon,
            color: m.color,
            onPressed: () => setState(() => _momoApproved = true),
          ),
        ],
      );
    }
    if (m == PaymentMethod.wallet) {
      return const Pill(text: 'Charged to CarryMe Wallet', icon: Icons.account_balance_wallet, color: AppColors.navy);
    }
    return Pill(
      text: 'Pay your driver in ${m == PaymentMethod.cashUsd ? 'US\$ cash' : 'L\$ cash'}',
      icon: Icons.payments_outlined,
      color: AppColors.amber,
      background: AppColors.amberSoft,
    );
  }
}
