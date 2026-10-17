import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/backend.dart';
import '../models/payment.dart';
import '../models/place.dart';
import '../models/ride.dart';
import '../models/user.dart';
import '../services/money.dart';
import '../utils/phone.dart';

enum AppMode { rider, driver }

/// Account, settings and history. Saved on the phone with SharedPreferences.
/// Swap the load/save methods for your backend (e.g. Firestore) when ready.
class AppState extends ChangeNotifier {
  bool loaded = false;
  bool onboarded = false;
  UserProfile? user;
  AppMode mode = AppMode.rider;

  CurrencyPref currency = CurrencyPref.both;
  bool dataSaver = false;
  bool simulateRain = false;
  bool autoShareTrips = false;
  PaymentMethod defaultPayment = PaymentMethod.cashLrd;

  double walletLrd = 0;
  List<WalletTxn> walletTxns = [];

  Place? home;
  Place? work;
  List<Place> favorites = [];

  List<RideRecord> history = [];
  List<RideRecord> scheduled = [];
  List<EmergencyContact> contacts = [];

  SharedPreferences? _prefs;

  bool get firstRideDone => history.any((r) => r.status == 'completed');

  /// Recent unique destinations, newest first.
  List<Place> get recentDestinations {
    final seen = <String>{};
    final out = <Place>[];
    for (final r in history) {
      if (seen.add(r.destination.name)) out.add(r.destination);
      if (out.length >= 5) break;
    }
    return out;
  }

  // ---------------------------------------------------------------- storage

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      onboarded = p.getBool('onboarded') ?? false;
      final u = p.getString('user');
      if (u != null) user = UserProfile.fromJson(jsonDecode(u) as Map<String, dynamic>);
      mode = AppMode.values.byName(p.getString('mode') ?? 'rider');
      currency = CurrencyPref.values.byName(p.getString('currency') ?? 'both');
      dataSaver = p.getBool('dataSaver') ?? false;
      simulateRain = p.getBool('simulateRain') ?? false;
      autoShareTrips = p.getBool('autoShareTrips') ?? false;
      defaultPayment = PaymentMethod.values.byName(p.getString('defaultPayment') ?? 'cashLrd');
      walletLrd = p.getDouble('walletLrd') ?? 0;
      walletTxns = _decodeList(p.getString('walletTxns'), WalletTxn.fromJson);
      home = _decodePlace(p.getString('home'));
      work = _decodePlace(p.getString('work'));
      favorites = _decodeList(p.getString('favorites'), Place.fromJson);
      history = _decodeList(p.getString('history'), RideRecord.fromJson);
      scheduled = _decodeList(p.getString('scheduled'), RideRecord.fromJson);
      contacts = _decodeList(p.getString('contacts'), EmergencyContact.fromJson);
    } catch (e) {
      debugPrint('CarryMe: could not load saved data: $e');
    }
    // In live mode the Firebase sign-in is the source of truth.
    if (Backend.enabled && Backend.auth.currentUser == null && user != null) {
      user = null;
    }
    // Short pause so the splash screen is visible.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    loaded = true;
    notifyListeners();
  }

  List<T> _decodeList<T>(String? raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw == null || raw.isEmpty) return <T>[];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  Place? _decodePlace(String? raw) =>
      raw == null ? null : Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  Future<void> _save() async {
    final p = _prefs ?? await SharedPreferences.getInstance();
    _prefs = p;
    await p.setBool('onboarded', onboarded);
    if (user != null) {
      await p.setString('user', jsonEncode(user!.toJson()));
    } else {
      await p.remove('user');
    }
    await p.setString('mode', mode.name);
    await p.setString('currency', currency.name);
    await p.setBool('dataSaver', dataSaver);
    await p.setBool('simulateRain', simulateRain);
    await p.setBool('autoShareTrips', autoShareTrips);
    await p.setString('defaultPayment', defaultPayment.name);
    await p.setDouble('walletLrd', walletLrd);
    await p.setString('walletTxns', jsonEncode(walletTxns.map((e) => e.toJson()).toList()));
    if (home != null) {
      await p.setString('home', jsonEncode(home!.toJson()));
    } else {
      await p.remove('home');
    }
    if (work != null) {
      await p.setString('work', jsonEncode(work!.toJson()));
    } else {
      await p.remove('work');
    }
    await p.setString('favorites', jsonEncode(favorites.map((e) => e.toJson()).toList()));
    await p.setString('history', jsonEncode(history.map((e) => e.toJson()).toList()));
    await p.setString('scheduled', jsonEncode(scheduled.map((e) => e.toJson()).toList()));
    await p.setString('contacts', jsonEncode(contacts.map((e) => e.toJson()).toList()));
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------------------------------------------------------------- account

  void completeOnboarding() {
    onboarded = true;
    _changed();
  }

  void login({required String name, required String phone, required AppMode asMode}) {
    final digits = (LiberiaPhone.national(phone) ?? '000000000');
    final letters = name.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
    final prefix = letters.length >= 3 ? letters.substring(0, 3) : 'LIB';
    user = UserProfile(
      name: name.trim(),
      phone: LiberiaPhone.e164(phone) ?? phone,
      referralCode: '$prefix${digits.substring(digits.length - 3)}',
      joined: DateTime.now(),
    );
    mode = asMode;
    _changed();
  }

  void updateProfile({String? name, String? email}) {
    if (user == null) return;
    user = user!.copyWith(name: name, email: email);
    _changed();
  }

  void logout() {
    if (Backend.enabled) Backend.auth.signOut();
    user = null;
    mode = AppMode.rider;
    _changed();
  }

  // ---------------------------------------------------------------- settings

  void setMode(AppMode m) {
    mode = m;
    _changed();
  }

  void setCurrency(CurrencyPref c) {
    currency = c;
    _changed();
  }

  void setDataSaver(bool v) {
    dataSaver = v;
    _changed();
  }

  void setSimulateRain(bool v) {
    simulateRain = v;
    _changed();
  }

  void setAutoShare(bool v) {
    autoShareTrips = v;
    _changed();
  }

  void setDefaultPayment(PaymentMethod m) {
    defaultPayment = m;
    _changed();
  }

  // ---------------------------------------------------------------- places

  void setHome(Place? p) {
    home = p;
    _changed();
  }

  void setWork(Place? p) {
    work = p;
    _changed();
  }

  void addFavorite(Place p) {
    favorites.removeWhere((f) => f.name == p.name);
    favorites.insert(0, p);
    _changed();
  }

  void removeFavorite(Place p) {
    favorites.removeWhere((f) => f.name == p.name);
    _changed();
  }

  // ---------------------------------------------------------------- rides

  void addHistory(RideRecord r) {
    history.insert(0, r);
    _changed();
  }

  void addScheduled(RideRecord r) {
    scheduled.add(r);
    scheduled.sort((a, b) => a.date.compareTo(b.date));
    _changed();
  }

  void removeScheduled(String id) {
    scheduled.removeWhere((r) => r.id == id);
    _changed();
  }

  // ---------------------------------------------------------------- safety

  void addContact(EmergencyContact c) {
    contacts.add(c);
    _changed();
  }

  void removeContact(EmergencyContact c) {
    contacts.removeWhere((x) => x.phone == c.phone && x.name == c.name);
    _changed();
  }

  // ---------------------------------------------------------------- wallet

  void topUp(double amountLrd, PaymentMethod from) {
    walletLrd += amountLrd;
    walletTxns.insert(0, WalletTxn(label: 'Top up from ${from.label}', amount: amountLrd, date: DateTime.now()));
    _changed();
  }

  /// Returns false when the balance is too low.
  bool payFromWallet(double amountLrd, String label) {
    if (walletLrd < amountLrd) return false;
    walletLrd -= amountLrd;
    walletTxns.insert(0, WalletTxn(label: label, amount: -amountLrd, date: DateTime.now()));
    _changed();
    return true;
  }
}
