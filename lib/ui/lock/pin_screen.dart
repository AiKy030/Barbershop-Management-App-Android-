import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../domain/pin.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';

/// Full-screen PIN pad. Calls [onEntered] when four digits are typed; it
/// returns null to accept the PIN, or a message to show and try again.
class PinScreen extends StatefulWidget {
  const PinScreen({
    super.key,
    required this.title,
    required this.onEntered,
    this.onCancel,
    this.lockedUntil,
  });

  final String title;
  final String? Function(String pin) onEntered;

  /// When set, a Cancel link is shown.
  final VoidCallback? onCancel;

  /// When set and it returns a time, typing is off until then and the "too
  /// many tries" message shows. Used for the closed-day check only.
  final DateTime? Function()? lockedUntil;

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String? _error;
  Timer? _unlockTimer;

  bool get _waiting => widget.lockedUntil?.call() != null;

  @override
  void initState() {
    super.initState();
    _watchLock();
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  /// While tries are locked, rebuilds when the wait is over.
  void _watchLock() {
    _unlockTimer?.cancel();
    final until = widget.lockedUntil?.call();
    if (until == null) return;
    _error = S.tooManyTries;
    _unlockTimer = Timer(
      until.difference(DateTime.now()) + const Duration(milliseconds: 50),
      () {
        if (mounted) setState(() => _error = null);
      },
    );
  }

  void _digit(String d) {
    if (_waiting) return;
    if (_pin.length >= pinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length < pinLength) return;
    final error = widget.onEntered(_pin);
    if (mounted) {
      setState(() {
        _pin = '';
        _error = error;
        _watchLock();
      });
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget key(String d) => _Key(
      onTap: () => _digit(d),
      child: Text(d, style: AppText.title.copyWith(color: colors.textPrimary)),
    );

    return Material(
      color: colors.bgApp,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              width: double.infinity,
              child: widget.onCancel == null
                  ? null
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Pressable(
                        onTap: widget.onCancel,
                        builder: (context, pressed) => Opacity(
                          opacity: pressed ? 0.5 : 1,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Center(
                              widthFactor: 1,
                              child: Text(
                                S.cancel,
                                style: AppText.body.copyWith(
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppText.title.copyWith(color: colors.textPrimary),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 16,
              children: [
                for (var i = 0; i < pinLength; i++)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length ? colors.accent : colors.bgFill,
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 56,
              child: Center(
                child: Text(
                  _error ?? '',
                  style: AppText.subhead.copyWith(color: colors.moneyNegative),
                ),
              ),
            ),
            Opacity(
              opacity: _waiting ? 0.35 : 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 24,
                        children: [for (final d in row) key(d)],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 24,
                    children: [
                      const SizedBox(width: 76, height: 76),
                      key('0'),
                      _Key(
                        onTap: _backspace,
                        filled: false,
                        child: Icon(
                          LucideIcons.delete,
                          size: 26,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, required this.child, this.filled = true});

  final VoidCallback onTap;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Pressable(
      onTap: onTap,
      builder: (context, pressed) => Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: pressed
              ? colors.bgFill
              : (filled ? colors.bgSurface : Colors.transparent),
        ),
        child: child,
      ),
    );
  }
}

/// Asks for a new PIN twice. Pops with the PIN when both match.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;

  @override
  Widget build(BuildContext context) {
    return PinScreen(
      title: _first == null ? S.newPin : S.confirmPin,
      onCancel: () => Navigator.of(context).pop(),
      onEntered: (pin) {
        if (_first == null) {
          setState(() => _first = pin);
          return null;
        }
        if (pin == _first) {
          Navigator.of(context).pop(pin);
          return null;
        }
        setState(() => _first = null);
        return S.pinMismatch;
      },
    );
  }
}
