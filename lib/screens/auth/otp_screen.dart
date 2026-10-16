import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

class OtpScreen extends StatefulWidget {
  final String name;
  final String phone;
  final AppMode mode;

  const OtpScreen({super.key, required this.name, required this.phone, required this.mode});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  int _resendIn = 30;
  Timer? _timer;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) t.cancel();
      if (mounted) setState(() => _resendIn--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    // DEMO: replace with real SMS verification (e.g. Firebase phone auth).
    if (_code.text.trim() != AppConfig.demoOtp) {
      setState(() {
        _verifying = false;
        _error = 'That code is not correct. Try again.';
      });
      return;
    }
    context.read<AppState>().login(name: widget.name, phone: widget.phone, asMode: widget.mode);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          const Text('Enter the code', style: AppText.h1),
          const SizedBox(height: 8),
          Text('We sent a 6-digit code by SMS to ${LiberiaPhone.pretty(widget.phone)}.', style: AppText.muted),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.amber, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Demo build: use code ${AppConfig.demoOtp}', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 14),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '······',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 24),
          PrimaryButton(label: 'Verify', loading: _verifying, onPressed: _verify),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _resendIn > 0
                  ? null
                  : () {
                      _startTimer();
                      showSnack(context, 'A new code is on its way.');
                    },
              child: Text(_resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code'),
            ),
          ),
        ],
      ),
    );
  }
}
