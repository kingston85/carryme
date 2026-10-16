/// Liberian phone number helpers.
class LiberiaPhone {
  /// Accepts 0777123456, 777123456, +231777123456, 231 777 123 456.
  /// Returns the 9-digit national number, or null if invalid.
  static String? national(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('231') && d.length == 12) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length != 9) return null;
    return d;
  }

  static String? e164(String input) {
    final n = national(input);
    return n == null ? null : '+231$n';
  }

  /// Best-guess network from the prefix (shown as a hint only).
  static String? network(String input) {
    var d = input.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('231')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length < 2) return null;
    final p = d.substring(0, 2);
    if (p == '77' || p == '55') return 'Orange';
    if (p == '88') return 'Lonestar Cell MTN';
    return null;
  }

  /// +231777123456 -> 0777 123 456
  static String pretty(String e164) {
    final n = national(e164);
    if (n == null) return e164;
    return '0${n.substring(0, 3)} ${n.substring(3, 6)} ${n.substring(6)}';
  }
}
