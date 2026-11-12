import 'package:barbershop_app/domain/pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 11, 12, 9);
  DateTime after(int seconds) => t0.add(Duration(seconds: seconds));

  test('four wrong tries do not lock', () {
    final a = PinAttempts();
    for (var i = 0; i < 4; i++) {
      a.wrong(t0);
    }
    expect(a.isLocked(t0), isFalse);
  });

  test('the fifth wrong try locks for 30 seconds', () {
    final a = PinAttempts();
    for (var i = 0; i < 5; i++) {
      a.wrong(t0);
    }
    expect(a.isLocked(t0), isTrue);
    expect(a.lockedUntil(t0), after(30));
    expect(a.isLocked(after(29)), isTrue);
    expect(a.isLocked(after(30)), isFalse);
  });

  test('a right PIN clears the count', () {
    final a = PinAttempts();
    for (var i = 0; i < 4; i++) {
      a.wrong(t0);
    }
    a.correct();
    for (var i = 0; i < 4; i++) {
      a.wrong(t0);
    }
    expect(a.isLocked(t0), isFalse);
  });

  test('tries made while locked are not counted', () {
    final a = PinAttempts();
    for (var i = 0; i < 5; i++) {
      a.wrong(t0);
    }
    for (var i = 0; i < 10; i++) {
      a.wrong(after(5));
    }
    expect(a.lockedUntil(after(5)), after(30));
    expect(a.isLocked(after(31)), isFalse);
  });

  test('after the wait, five more wrong tries lock again', () {
    final a = PinAttempts();
    for (var i = 0; i < 5; i++) {
      a.wrong(t0);
    }
    for (var i = 0; i < 4; i++) {
      a.wrong(after(40));
    }
    expect(a.isLocked(after(40)), isFalse);
    a.wrong(after(40));
    expect(a.lockedUntil(after(40)), after(70));
  });
}
