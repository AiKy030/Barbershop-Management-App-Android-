/// Money helpers. All amounts are integer centavos; pesos exist only as text.
library;

const String pesoSign = '₱';

/// Formats centavos for display, for example 15000 -> "₱150" and
/// 123450 -> "₱1,234.50". Centavos are shown only when they are not zero.
String formatPesos(int centavos) {
  final abs = centavos.abs();
  final digits = (abs ~/ 100).toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  final cents = abs % 100;
  final fraction = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  return '${centavos < 0 ? '−' : ''}$pesoSign$grouped$fraction';
}

/// Plain text for an input field, for example 15000 -> "150".
String pesosInputText(int centavos) {
  final cents = centavos % 100;
  final fraction = cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}';
  return '${centavos ~/ 100}$fraction';
}

final RegExp _pesosPattern = RegExp(r'^(\d{1,9})(?:\.(\d{1,2}))?$');

/// Parses typed pesos into centavos without using floats.
/// Returns null when the text is not a valid non-negative amount.
int? parsePesos(String input) {
  final text = input.trim().replaceAll(',', '').replaceAll(pesoSign, '');
  final match = _pesosPattern.firstMatch(text);
  if (match == null) return null;
  final pesos = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return pesos * 100 + int.parse(fraction);
}

/// Parses a whole-number percent from 0 to 100. Returns null when invalid.
int? parsePercent(String input) {
  final text = input.trim();
  if (!RegExp(r'^\d{1,3}$').hasMatch(text)) return null;
  final value = int.parse(text);
  return value <= 100 ? value : null;
}
