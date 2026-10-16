import 'package:flutter/material.dart';

/// Payment options that work in Liberia.
enum PaymentMethod {
  cashLrd(
    label: 'Cash (L\$)',
    icon: Icons.payments_outlined,
    color: Color(0xFF15803D),
  ),
  cashUsd(
    label: 'Cash (US\$)',
    icon: Icons.attach_money,
    color: Color(0xFF0F766E),
  ),
  orangeMoney(
    label: 'Orange Money',
    icon: Icons.phone_android,
    color: Color(0xFFFF7900),
  ),
  mtnMomo(
    label: 'MTN MoMo',
    icon: Icons.phone_iphone,
    color: Color(0xFFD4A000),
  ),
  wallet(
    label: 'CarryMe Wallet',
    icon: Icons.account_balance_wallet_outlined,
    color: Color(0xFF002868),
  );

  const PaymentMethod({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  bool get isMobileMoney =>
      this == PaymentMethod.orangeMoney || this == PaymentMethod.mtnMomo;

  bool get isCash => this == PaymentMethod.cashLrd || this == PaymentMethod.cashUsd;
}
