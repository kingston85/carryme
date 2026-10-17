import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../data/liberia_places.dart';
import '../../models/place.dart';
import '../../services/geocoding_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'map_picker_screen.dart';

class TripPlan {
  final Place pickup;
  final Place destination;
  const TripPlan(this.pickup, this.destination);
}

enum _Field { pickup, destination }

class SearchScreen extends StatefulWidget {
  final Place? initialPickup;
  final Place? initialDestination;

  const SearchScreen({super.key, this.initialPickup, this.initialDestination});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _pickupCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _pickupFocus = FocusNode();
  final _destFocus = FocusNode();

  Place? _pickup;
  Place? _dest;
  _Field _active = _Field.destination;
  List<Place> _results = [];
  bool _searching = false;
  Timer? _debounce;
  int _query = 0;

  @override
  void initState() {
    super.initState();
    _pickup = widget.initialPickup;
    _dest = widget.initialDestination;
    _pickupCtrl.text = _pickup?.name ?? '';
    _destCtrl.text = _dest?.name ?? '';
    _active = _pickup == null ? _Field.pickup : _Field.destination;
    _pickupFocus.addListener(() {
      if (_pickupFocus.hasFocus) setState(() => _active = _Field.pickup);
    });
    _destFocus.addListener(() {
      if (_destFocus.hasFocus) setState(() => _active = _Field.destination);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (_active == _Field.pickup ? _pickupFocus : _destFocus).requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupCtrl.dispose();
    _destCtrl.dispose();
    _pickupFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    if (_active == _Field.pickup) {
      _pickup = null;
    } else {
      _dest = null;
    }
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _results = LiberiaPlaces.search(text);
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final id = ++_query;
      final found = await GeocodingService.search(text);
      if (!mounted || id != _query) return;
      setState(() {
        _results = found;
        _searching = false;
      });
    });
  }

  void _choose(Place p) {
    setState(() {
      if (_active == _Field.pickup) {
        _pickup = p;
        _pickupCtrl.text = p.name;
        _active = _Field.destination;
        if (_dest == null) _destFocus.requestFocus();
      } else {
        _dest = p;
        _destCtrl.text = p.name;
        if (_pickup == null) _pickupFocus.requestFocus();
      }
      _results = [];
    });
    if (_pickup != null && _dest != null) {
      Navigator.pop(context, TripPlan(_pickup!, _dest!));
    }
  }

  Future<void> _pickOnMap() async {
    final start = (_active == _Field.pickup ? _pickup : _dest)?.point ??
        _pickup?.point ??
        AppConfig.monroviaCenter;
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initial: start,
          title: _active == _Field.pickup ? 'Set pickup' : 'Set destination',
        ),
      ),
    );
    if (place != null && mounted) _choose(place);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final typing = (_active == _Field.pickup ? _pickupCtrl.text : _destCtrl.text).trim().length >= 2 &&
        (_active == _Field.pickup ? _pickup == null : _dest == null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Plan your ride', style: AppText.h3),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.navy, width: 3)),
                    ),
                    Container(width: 2, height: 40, color: AppColors.line),
                    Container(width: 12, height: 12, color: AppColors.red),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _field(_pickupCtrl, _pickupFocus, 'Pickup location'),
                      const SizedBox(height: 10),
                      _field(_destCtrl, _destFocus, 'Where to?'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                _actionTile(Icons.map_outlined, 'Choose on map', 'Drop a pin where you are standing', _pickOnMap),
                if (typing) ...[
                  for (final p in _results) _placeTile(p),
                  if (!_searching && _results.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No places found. Try a landmark like "Red Light" or "ELWA Junction", or choose on the map.',
                        textAlign: TextAlign.center,
                        style: AppText.muted,
                      ),
                    ),
                ] else ...[
                  if (_active == _Field.pickup && widget.initialPickup != null)
                    _placeTile(widget.initialPickup!, icon: Icons.my_location, subtitle: 'Current location'),
                  if (app.home != null) _placeTile(app.home!, icon: Icons.home_rounded, subtitle: 'Home'),
                  if (app.work != null) _placeTile(app.work!, icon: Icons.work_rounded, subtitle: 'Work'),
                  for (final p in app.favorites) _placeTile(p, icon: Icons.favorite),
                  if (app.recentDestinations.isNotEmpty) const _Header('Recent'),
                  for (final p in app.recentDestinations) _placeTile(p, icon: Icons.history),
                  const _Header('Popular landmarks'),
                  for (final p in LiberiaPlaces.all.take(18)) _placeTile(p),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, FocusNode f, String hint) {
    final active = (f == _pickupFocus && _active == _Field.pickup) || (f == _destFocus && _active == _Field.destination);
    return TextField(
      controller: c,
      focusNode: f,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: active ? AppColors.navySoft : AppColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        suffixIcon: c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  c.clear();
                  _onChanged('');
                },
              ),
      ),
    );
  }

  Widget _placeTile(Place p, {IconData? icon, String? subtitle}) {
    final app = context.read<AppState>();
    final isFav = app.favorites.any((f) => f.name == p.name);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.bg,
        child: Icon(icon ?? p.icon, color: AppColors.ink, size: 20),
      ),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle ?? p.area, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
        onSelected: (v) {
          if (v == 'home') app.setHome(p);
          if (v == 'work') app.setWork(p);
          if (v == 'fav') {
            if (isFav) {
              app.removeFavorite(p);
            } else {
              app.addFavorite(p);
            }
          }
          showSnack(context, 'Saved');
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'home', child: Text('Set as Home')),
          const PopupMenuItem(value: 'work', child: Text('Set as Work')),
          PopupMenuItem(value: 'fav', child: Text(isFav ? 'Remove from favourites' : 'Add to favourites')),
        ],
      ),
      onTap: () => _choose(p),
    );
  }

  Widget _actionTile(IconData icon, String title, String sub, VoidCallback onTap) => ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.navySoft, child: Icon(icon, color: AppColors.navy, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
        onTap: onTap,
      );
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8)),
      );
}
