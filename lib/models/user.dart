class UserProfile {
  final String name;
  final String phone; // stored as +231XXXXXXXXX
  final String email;
  final String referralCode;
  final double rating;
  final DateTime joined;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.referralCode,
    required this.joined,
    this.email = '',
    this.rating = 5.0,
  });

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }

  UserProfile copyWith({String? name, String? email}) => UserProfile(
        name: name ?? this.name,
        phone: phone,
        email: email ?? this.email,
        referralCode: referralCode,
        rating: rating,
        joined: joined,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'referralCode': referralCode,
        'rating': rating,
        'joined': joined.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        referralCode: j['referralCode'] as String? ?? 'CARRYME',
        rating: (j['rating'] as num?)?.toDouble() ?? 5.0,
        joined: DateTime.tryParse(j['joined'] as String? ?? '') ?? DateTime.now(),
      );
}

class EmergencyContact {
  final String name;
  final String phone;

  const EmergencyContact({required this.name, required this.phone});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        name: j['name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
      );
}

class WalletTxn {
  final String label;
  final double amount; // positive = money in, negative = money out (L$)
  final DateTime date;

  const WalletTxn({required this.label, required this.amount, required this.date});

  Map<String, dynamic> toJson() =>
      {'label': label, 'amount': amount, 'date': date.toIso8601String()};

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        label: j['label'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      );
}
