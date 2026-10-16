import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class _Slide {
  final List<IconData> icons;
  final String title;
  final String body;
  final Color color;
  const _Slide(this.icons, this.title, this.body, this.color);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  int _index = 0;

  static const _slides = [
    _Slide(
      [Icons.two_wheeler, Icons.electric_rickshaw, Icons.local_taxi],
      'Ride your way',
      'Pen-pen, keke, a seat in a shared taxi or the whole car. Pick the ride that fits your pocket.',
      AppColors.navy,
    ),
    _Slide(
      [Icons.payments_outlined, Icons.phone_android, Icons.account_balance_wallet_outlined],
      'Pay how you like',
      'Cash in Liberian or US dollars, Orange Money, MTN MoMo or your CarryMe wallet. Prices are shown upfront.',
      AppColors.red,
    ),
    _Slide(
      [Icons.place, Icons.alt_route, Icons.storefront],
      'We know the landmarks',
      'Say "ELWA Junction" or "Red Light" - pickups work the way people in Liberia give directions.',
      AppColors.green,
    ),
    _Slide(
      [Icons.verified_user, Icons.pin, Icons.sos],
      'Safe every trip',
      'Verified drivers, a ride PIN, live trip sharing with family on WhatsApp, and one-tap SOS.',
      AppColors.navy,
    ),
  ];

  void _finish() => context.read<AppState>().completeOnboarding();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const BrandLogo(size: 34),
                  const Spacer(),
                  if (!last) TextButton(onPressed: _finish, child: const Text('Skip')),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.navy : AppColors.line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                label: last ? 'Get started' : 'Next',
                icon: last ? Icons.arrow_forward : null,
                onPressed: () {
                  if (last) {
                    _finish();
                  } else {
                    _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(color: slide.color.withAlpha(22), shape: BoxShape.circle),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(color: slide.color, shape: BoxShape.circle),
                  child: Icon(slide.icons[1], size: 60, color: Colors.white),
                ),
                Positioned(top: 26, left: 30, child: _bubble(slide.icons[0])),
                Positioned(bottom: 30, right: 26, child: _bubble(slide.icons[2])),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(slide.title, style: AppText.h1, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _bubble(IconData icon) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Icon(icon, color: slide.color, size: 28),
      );
}
