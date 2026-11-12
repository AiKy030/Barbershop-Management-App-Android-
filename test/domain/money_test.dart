import 'package:barbershop_app/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPesos', () {
    test('whole pesos have no decimals', () {
      expect(formatPesos(15000), '₱150');
      expect(formatPesos(0), '₱0');
    });

    test('centavos are shown when present', () {
      expect(formatPesos(15050), '₱150.50');
      expect(formatPesos(5), '₱0.05');
    });

    test('thousands are grouped', () {
      expect(formatPesos(100000), '₱1,000');
      expect(formatPesos(123456789), '₱1,234,567.89');
    });

    test('negative amounts keep the sign in front', () {
      expect(formatPesos(-5000), '−₱50');
      expect(formatPesos(-123450), '−₱1,234.50');
    });
  });

  group('parsePesos', () {
    test('parses whole and decimal pesos into centavos', () {
      expect(parsePesos('150'), 15000);
      expect(parsePesos('150.5'), 15050);
      expect(parsePesos('150.05'), 15005);
      expect(parsePesos(' 1,000 '), 100000);
      expect(parsePesos('₱80'), 8000);
      expect(parsePesos('0'), 0);
    });

    test('has no float drift', () {
      expect(parsePesos('0.29'), 29);
      expect(parsePesos('1.15'), 115);
      expect(parsePesos('19.99'), 1999);
    });

    test('rejects invalid text', () {
      expect(parsePesos(''), isNull);
      expect(parsePesos('abc'), isNull);
      expect(parsePesos('-5'), isNull);
      expect(parsePesos('1.234'), isNull);
      expect(parsePesos('1.'), isNull);
      expect(parsePesos('.5'), isNull);
    });
  });

  test('pesosInputText round-trips through parsePesos', () {
    for (final centavos in [0, 5, 8000, 15050, 100000]) {
      expect(parsePesos(pesosInputText(centavos)), centavos);
    }
    expect(pesosInputText(15000), '150');
    expect(pesosInputText(15050), '150.50');
  });

  test('parsePercent accepts 0 to 100 only', () {
    expect(parsePercent('60'), 60);
    expect(parsePercent('0'), 0);
    expect(parsePercent('100'), 100);
    expect(parsePercent('101'), isNull);
    expect(parsePercent(''), isNull);
    expect(parsePercent('6.5'), isNull);
    expect(parsePercent('-1'), isNull);
  });
}
