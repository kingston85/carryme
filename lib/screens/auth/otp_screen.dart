import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../backend/backend.dart';
import '../../backend/firestore_api.dart';
import '../../backend/phone_auth.dart';
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
  final PhoneAuth _auth = PhoneAuth();
  int _resendIn = 30;
  Timer? _timer;
  bool _verifying = false;
  bool _sending = false;
  bool _finished = false;
  bool _waitingForSend = false; // code typed before Firebase was ready
  bool _slow = false;
  Timer? _slowTimer;
  String? _error;

  bool get _live => Backend.enabled;

  @override
  void initState() {
    super.initState();
    _send();
  }

  void _send() {
    _startTimer();
    if (!_live) return;
    setState(() {
      _sending = true;
      _slow = false;
      _error = null;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _sending) setState(() => _slow = true);
    });
    _auth.sendCode(
      widget.phone,
      onCodeSent: () {
        if (!mounted) return;
        final pending = _waitingForSend;
        setState(() {
          _sending = false;
          _slow = false;
          _waitingForSend = false;
          _verifying = false;
        });
        // The code was typed while we were still waiting - check it now.
        if (pending) _verify();
      },
      onAutoVerified: _signedIn,
      onError: (m) {
        if (mounted) {
          setState(() {
            _sending = false;
            _slow = false;
            _waitingForSend = false;
            _verifying = false;
            _error = m;
          });
        }
      },
    );
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
    _slowTimer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_finished) return;
    if (_live && !_auth.codeSent) {
      // Firebase hasn't confirmed sending yet: verify as soon as it does.
      setState(() {
        _waitingForSend = true;
        _verifying = true;
        _error = null;
      });
      return;
    }
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    String? error;
    if (_live) {
      error = await _auth.verify(_code.text);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_code.text.trim() != AppConfig.demoOtp) error = 'That code is not correct. Try again.';
    }
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _verifying = false;
        _error = error;
      });
      return;
    }
    await _signedIn();
  }

  /// Saves the profile and opens the app (called after manual or automatic verification).
  Future<void> _signedIn() async {
    if (_finished || !mounted) return;
    _finished = true;
    setState(() => _verifying = true);
    if (_live) {
      try {
        await FirestoreApi.saveUser(
          name: widget.name,
          phone: widget.phone,
          role: widget.mode == AppMode.driver ? 'driver' : 'rider',
        ).timeout(const Duration(seconds: 10));
      } catch (e) {
        // The profile write is retried by Firestore when the network returns.
        debugPrint('CarryMe: profile save delayed: $e');
      }
    }
    if (!mounted) return;
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
          Text(
            _sending
                ? 'Sending a code to ${LiberiaPhone.pretty(widget.phone)}…'
                : 'We sent a 6-digit code by SMS to ${LiberiaPhone.pretty(widget.phone)}.',
            style: AppText.muted,
          ),
          if (_live && _slow) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'This is taking longer than usual. If a browser window opened, finish the '
                '"I\'m not a robot" check there. Also check your internet connection.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (!_live) ...[
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
          ],
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
              onPressed: _resendIn > 0 || _sending
                  ? null
                  : () {
                      _send();
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
