import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart' show newId;
import '../../domain/entries.dart';
import '../../domain/pin.dart';
import '../../domain/report.dart';
import '../../domain/sale.dart';
import '../lock/pin_screen.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import 'cards.dart';
import 'sheet.dart';

/// "Today" for a null date, otherwise the short date ("Tue, Nov 3").
String entryDateLabel(DateTime? date) =>
    date == null ? S.today : S.shortDay(date);

/// Lets the owner choose the day for a new entry. Returns null when he
/// cancels. The date inside is null when he chose today.
Future<({DateTime? date})?> pickEntryDate(
  BuildContext context,
  DateTime? current,
) async {
  final now = DateTime.now();
  final picked = await showAppSheet<DateTime>(
    context,
    (_) => DateSheet(title: S.date, initial: current ?? now),
  );
  if (picked == null) return null;
  final isToday = businessDateOf(picked) == businessDateOf(now);
  return (date: isToday ? null : picked);
}

/// Wrong tries at the closed-day PIN. Kept here, outside the PIN screen, so
/// closing the screen and opening it again does not reset the count. The
/// app lock screen does not use this.
final PinAttempts closedDayPinAttempts = PinAttempts();

/// The days the PIN was just given for, and until when that still counts.
/// It lets Undo on a toast work without asking for the PIN a second time.
({Set<String> days, DateTime until})? _pass;

/// A little longer than an Undo toast stays on screen.
const _passLasts = Duration(seconds: 6);

bool _hasPass(Iterable<String> days, DateTime now) {
  final pass = _pass;
  if (pass == null) return false;
  if (!now.isBefore(pass.until)) {
    _pass = null;
    return false;
  }
  return pass.days.containsAll(days);
}

/// A context that stays valid after the screen or sheet that started an
/// action has closed. Use it for Undo on a toast.
BuildContext lastingContext(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).overlay!.context;

String _dayNames(List<String> days) =>
    days.map((d) => S.monthDay(parseBusinessDate(d))).join(' and ');

/// Asks for the PIN that protects closed days. With no PIN set yet, the
/// owner is asked to set one first. Returns false when he backs out.
///
/// [days] are the closed days about to be changed, as business dates. They
/// are named on the PIN screen unless [title] is given.
Future<bool> unlockClosedDays(
  BuildContext context,
  List<String> days, {
  String? title,
}) async {
  if (_hasPass(days, DateTime.now())) return true;
  final config = context.read<ShopConfig>();
  final navigator = Navigator.of(context, rootNavigator: true);

  final stored = config.settings.pinHash;
  if (stored == null) {
    final setUp = await showAppSheet<bool>(
      context,
      (_) => const ConfirmSheet(
        title: S.setPinFirstTitle,
        body: S.setPinFirstBody,
        confirmLabel: S.setPin,
      ),
    );
    if (setUp != true) return false;
    final pin = await navigator.push(
      CupertinoPageRoute<String>(
        fullscreenDialog: true,
        builder: (_) => const PinSetupScreen(),
      ),
    );
    if (pin == null) return false;
    // A PIN made here protects closed days only. Asking for it when the app
    // opens is a separate switch in Settings. He has just typed the new PIN
    // twice, so it is not asked a third time.
    await config.setPinHash(makePinHash(pin, newId()), lockOnOpen: false);
  } else {
    final ok = await navigator.push(
      CupertinoPageRoute<bool>(
        fullscreenDialog: true,
        builder: (routeContext) => PinScreen(
          title: title ?? S.enterPinToChange(_dayNames(days)),
          onCancel: () => Navigator.of(routeContext).pop(),
          lockedUntil: () => closedDayPinAttempts.lockedUntil(DateTime.now()),
          onEntered: (pin) {
            final now = DateTime.now();
            if (closedDayPinAttempts.isLocked(now)) return S.tooManyTries;
            if (!verifyPin(pin, stored)) {
              closedDayPinAttempts.wrong(now);
              return closedDayPinAttempts.isLocked(now)
                  ? S.tooManyTries
                  : S.wrongPin;
            }
            closedDayPinAttempts.correct();
            Navigator.of(routeContext).pop(true);
            return null;
          },
        ),
      ),
    );
    if (ok != true) return false;
  }
  _pass = (days: days.toSet(), until: DateTime.now().add(_passLasts));
  return true;
}

/// Runs [save] for a change that touches [days] (business dates). Returns
/// false when nothing was saved.
///
/// Open days save straight away. A closed day needs the PIN first. The day
/// stays locked the whole time, with its cash count, and the change is
/// noted in the reopen log with [reason]. One PIN entry covers every closed
/// day in [days], for example both days when an entry is moved.
Future<bool> guardedSave(
  BuildContext context, {
  required Iterable<String> days,
  required ReopenReason reason,
  required Future<void> Function() save,
}) async {
  final ledger = context.read<Ledger>();
  final closed = days.toSet().where(ledger.isClosed).toList()..sort();
  if (closed.isEmpty) {
    await save();
    return true;
  }
  if (!await unlockClosedDays(context, closed)) return false;
  await save();
  for (final day in closed) {
    await ledger.logReopen(day, reason);
  }
  return true;
}

/// [guardedSave] for a new entry dated [date].
Future<bool> saveIntoDay(
  BuildContext context,
  DateTime date,
  Future<void> Function() save, {
  ReopenReason reason = ReopenReason.addEntry,
}) => guardedSave(
  context,
  days: [businessDateOf(date)],
  reason: reason,
  save: save,
);

/// Where a toast sits on the screen that started a change.
class ToastPlace {
  const ToastPlace({this.aboveTabBar = true, this.aboveFooterButton = false});

  /// Full screens with no tab bar pass false.
  final bool aboveTabBar;
  final bool aboveFooterButton;
}

/// Makes one change to an entry through [guardedSave], then shows [message]
/// with Undo. Undo goes through the guard too; within the same toast it
/// does not ask for the PIN again. Returns false when nothing was changed.
///
/// [days] are every day the change touches: both days when an entry moves.
Future<bool> changeEntry(
  BuildContext context, {
  required Iterable<String> days,
  required ReopenReason reason,
  required String message,
  required Future<void> Function() change,
  required Future<void> Function() undo,
  ToastPlace place = const ToastPlace(),
}) async {
  // The sheet that started this is usually closed by the time Undo is
  // tapped, so Undo runs from a context that outlives it.
  final lasting = lastingContext(context);
  final touched = days.toSet();
  final done = await guardedSave(
    context,
    days: touched,
    reason: reason,
    save: change,
  );
  if (!done) return false;
  if (context.mounted) {
    showToast(
      context,
      message,
      actionLabel: S.undo,
      onAction: () => guardedSave(
        lasting,
        days: touched,
        reason: reason,
        save: undo,
      ),
      aboveTabBar: place.aboveTabBar,
      aboveFooterButton: place.aboveFooterButton,
    );
  }
  return true;
}
