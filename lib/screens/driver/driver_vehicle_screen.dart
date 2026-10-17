import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/vehicle_type.dart';
import '../../services/money.dart';
import '../../state/driver_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DriverVehicleScreen extends StatefulWidget {
  const DriverVehicleScreen({super.key});

  @override
  State<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends State<DriverVehicleScreen> {
  late VehicleType _type;
  late final TextEditingController _model;
  late final TextEditingController _plate;
  late final TextEditingController _color;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final drv = context.read<DriverController>();
    _type = drv.vehicle;
    _model = TextEditingController(text: drv.vehicleModel);
    _plate = TextEditingController(text: drv.plate == 'No plate set' ? '' : drv.plate);
    _color = TextEditingController(text: drv.colorName);
  }

  @override
  void dispose() {
    _model.dispose();
    _plate.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_model.text.trim().isEmpty || _plate.text.trim().isEmpty) {
      showSnack(context, 'Enter the make/model and number plate.');
      return;
    }
    setState(() => _saving = true);
    final error = await context.read<DriverController>().setVehicle(
          type: _type,
          model: _model.text.trim(),
          plateNo: _plate.text.trim().toUpperCase(),
          color: _color.text.trim(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showSnack(context, error ?? 'Vehicle saved');
    if (error == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My vehicle')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionTitle('What do you drive?'),
          for (final v in VehicleType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                color: _type == v ? AppColors.navySoft : null,
                onTap: () => setState(() => _type = v),
                child: Row(
                  children: [
                    Icon(v.icon, color: AppColors.navy, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.label, style: AppText.h3),
                          Text(
                            'Base ${Money.lrd(AppConfig.fares[v]!.base)} + ${Money.lrd(AppConfig.fares[v]!.perKm)}/km',
                            style: AppText.small,
                          ),
                        ],
                      ),
                    ),
                    if (_type == v) const Icon(Icons.check_circle, color: AppColors.navy),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: 'Make & model',
              hintText: 'e.g. Toyota Corolla, Bajaj keke',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _plate,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Number plate',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _color,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Colour',
              hintText: 'e.g. Yellow',
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save vehicle',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
