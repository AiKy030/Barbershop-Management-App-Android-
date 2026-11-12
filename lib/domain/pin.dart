/// PIN hashing. The PIN itself is never stored.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

const int pinLength = 4;

bool isValidPin(String pin) => RegExp('^\\d{$pinLength}\$').hasMatch(pin);

/// Returns `salt:hash` for storing in settings.
String makePinHash(String pin, String salt) =>
    '$salt:${sha256.convert(utf8.encode('$salt:$pin'))}';

/// Counts wrong PIN tries. After [maxTries] wrong tries in a row, no more
/// tries are allowed for [wait]. The caller passes the time in, so this
/// holds no clock of its own.
class PinAttempts {
  static const int maxTries = 5;
  static const Duration wait = Duration(seconds: 30);

  int _wrong = 0;
  DateTime? _lockedUntil;

  /// When tries are allowed again, or null when they are allowed now.
  DateTime? lockedUntil(DateTime now) {
    final until = _lockedUntil;
    if (until == null) return null;
    if (now.isBefore(until)) return until;
    _lockedUntil = null;
    return null;
  }

  bool isLocked(DateTime now) => lockedUntil(now) != null;

  /// Records a wrong try. Ignored while locked.
  void wrong(DateTime now) {
    if (isLocked(now)) return;
    _wrong++;
    if (_wrong >= maxTries) {
      _wrong = 0;
      _lockedUntil = now.add(wait);
    }
  }

  /// A right PIN clears the count.
  void correct() {
    _wrong = 0;
    _lockedUntil = null;
  }
}

bool verifyPin(String pin, String stored) {
  final split = stored.indexOf(':');
  if (split <= 0) return false;
  return makePinHash(pin, stored.substring(0, split)) == stored;
}
