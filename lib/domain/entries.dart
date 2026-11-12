/// Staff payments, expenses and day closures. Pure Dart.
library;

import 'sale.dart';

enum PaymentType { payout, advance, adjustment }

/// Money given to a staff member (payout or advance), or a manual
/// adjustment to his balance.
class StaffPayment {
  const StaffPayment({
    required this.id,
    required this.businessDate,
    required this.createdAt,
    required this.staffId,
    required this.type,
    required this.amount,
    required this.paymentMethod,
    required this.note,
    required this.voided,
  });

  factory StaffPayment.record({
    required String id,
    required DateTime now,
    DateTime? forDate,
    required String staffId,
    required PaymentType type,
    required int amount,
    PaymentMethod? paymentMethod,
    String? note,
  }) {
    if (type != PaymentType.adjustment && amount <= 0) {
      throw ArgumentError.value(amount, 'amount');
    }
    final trimmed = note?.trim();
    return StaffPayment(
      id: id,
      businessDate: entryDateOf(now, forDate),
      createdAt: now.toUtc(),
      staffId: staffId,
      type: type,
      amount: amount,
      paymentMethod: paymentMethod,
      note: trimmed == null || trimmed.isEmpty ? null : trimmed,
      voided: false,
    );
  }

  final String id;
  final String businessDate;
  final DateTime createdAt;
  final String staffId;
  final PaymentType type;

  /// Centavos. Positive for payouts and advances. Adjustments are signed.
  final int amount;
  final PaymentMethod? paymentMethod;
  final String? note;
  final bool voided;

  /// How this entry changes the balance.
  int get balanceEffect => type == PaymentType.adjustment ? amount : -amount;
}

class Expense {
  const Expense({
    required this.id,
    required this.businessDate,
    required this.createdAt,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.note,
    required this.voided,
  });

  factory Expense.record({
    required String id,
    required DateTime now,
    DateTime? forDate,
    required String category,
    required int amount,
    required PaymentMethod paymentMethod,
    String? note,
  }) {
    if (amount <= 0) throw ArgumentError.value(amount, 'amount');
    final trimmed = note?.trim();
    return Expense(
      id: id,
      businessDate: entryDateOf(now, forDate),
      createdAt: now.toUtc(),
      category: category,
      amount: amount,
      paymentMethod: paymentMethod,
      note: trimmed == null || trimmed.isEmpty ? null : trimmed,
      voided: false,
    );
  }

  final String id;
  final String businessDate;
  final DateTime createdAt;

  /// Category name, copied at the time of the expense.
  final String category;

  /// Centavos.
  final int amount;
  final PaymentMethod paymentMethod;
  final String? note;
  final bool voided;

  /// The note when there is one, otherwise the category.
  String get title => note ?? category;
}

/// Why a closed day was opened up. Saved in the `day_reopens` log.
enum ReopenReason {
  /// The owner tapped Reopen Day. The day stays open.
  manual('manual'),
  addEntry('add_entry'),

  /// An entry was changed, or moved to or from the day.
  editEntry('edit_entry'),

  /// An entry was voided or restored.
  voidEntry('void_entry'),

  /// A past-day tally was saved.
  tally('tally');

  const ReopenReason(this.code);

  /// The text stored in the database.
  final String code;
}

/// A closed (locked) day.
class DayClosure {
  const DayClosure({
    required this.businessDate,
    required this.closedAt,
    required this.cashCounted,
  });

  final String businessDate;
  final DateTime closedAt;

  /// Centavos. Null when the owner closed without counting.
  final int? cashCounted;
}
