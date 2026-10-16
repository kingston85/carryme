import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  AppMode _mode = AppMode.rider;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _continue() {
    final name = _name.text.trim();
    final phone = LiberiaPhone.e164(_phone.text);
    if (name.length < 2) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    if (phone == null) {
      setState(() => _error = 'Enter a valid Liberian number, e.g. 0777 123 456.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OtpScreen(name: name, phone: phone, mode: _mode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final network = LiberiaPhone.network(_phone.text);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          children: [
            const BrandLogo(size: 40),
            const SizedBox(height: 36),
            const Text('Welcome!', style: AppText.h1),
            const SizedBox(height: 6),
            const Text('Sign in with your phone number. We\'ll text you a code.', style: AppText.muted),
            const SizedBox(height: 28),
            const Text('I want to', style: AppText.h3),
            const SizedBox(height: 10),
            SegmentedButton<AppMode>(
              segments: const [
                ButtonSegment(value: AppMode.rider, icon: Icon(Icons.hail), label: Text('Ride')),
                ButtonSegment(value: AppMode.driver, icon: Icon(Icons.local_taxi), label: Text('Drive & earn')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone number',
                hintText: '0777 123 456',
                prefixIcon: const Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 6, 14),
                  child: Text('🇱🇷 +231', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                suffixIcon: network == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Center(
                          widthFactor: 1,
                          child: Pill(
                            text: network,
                            color: network == 'Orange' ? const Color(0xFFE06A00) : const Color(0xFF8A6D00),
                            background: network == 'Orange' ? const Color(0xFFFFEEDD) : const Color(0xFFFFF6CC),
                          ),
                        ),
                      ),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 28),
            PrimaryButton(label: 'Continue', icon: Icons.sms_outlined, onPressed: _continue),
            const SizedBox(height: 18),
            const Text(
              'By continuing you agree to CarryMe\'s Terms of Service and Privacy Policy. '
              'Standard SMS rates may apply.',
              textAlign: TextAlign.center,
              style: AppText.small,
            ),
          ],
        ),
      ),
    );
  }
}
