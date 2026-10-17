import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

enum DocStatus { missing, pending, verified }

class _Doc {
  final String title;
  final String hint;
  final IconData icon;
  DocStatus status;
  _Doc(this.title, this.hint, this.icon, this.status);
}

/// Driver verification checklist. In production, upload images to storage
/// (e.g. Firebase Storage) and let your operations team approve them.
class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  final List<_Doc> _docs = [
    _Doc('Driver\'s licence', 'Valid licence for your vehicle class', Icons.badge, DocStatus.verified),
    _Doc('National ID card', 'Liberia national ID or passport', Icons.credit_card, DocStatus.verified),
    _Doc('Vehicle registration', 'Current registration and number plate', Icons.directions_car, DocStatus.pending),
    _Doc('Insurance certificate', 'Third-party or comprehensive cover', Icons.verified_user, DocStatus.missing),
    _Doc('Police clearance', 'Issued within the last 12 months', Icons.local_police, DocStatus.missing),
    _Doc('Vehicle photos', 'Front, back and inside, plate visible', Icons.photo_camera, DocStatus.missing),
    _Doc('Profile photo', 'Clear photo of your face, no sunglasses', Icons.face, DocStatus.verified),
  ];

  @override
  Widget build(BuildContext context) {
    final done = _docs.where((d) => d.status == DocStatus.verified).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$done of ${_docs.length} verified', style: AppText.h2),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: done / _docs.length, minHeight: 8),
                const SizedBox(height: 8),
                const Text('We review documents within 2 working days. You can drive once everything is verified.',
                    style: AppText.small),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final d in _docs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppColors.navySoft, child: Icon(d.icon, color: AppColors.navy)),
                  title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(d.hint),
                  trailing: _status(d),
                  onTap: d.status == DocStatus.missing
                      ? () {
                          setState(() => d.status = DocStatus.pending);
                          showSnack(context, '${d.title} uploaded - under review (demo)');
                        }
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _status(_Doc d) => switch (d.status) {
        DocStatus.verified => const Pill(text: 'Verified', color: AppColors.green, background: AppColors.greenSoft),
        DocStatus.pending => const Pill(text: 'In review', color: AppColors.amber, background: AppColors.amberSoft),
        DocStatus.missing => const Pill(text: 'Upload', icon: Icons.upload, color: AppColors.red, background: AppColors.redSoft),
      };
}
