/// What the shop owes a staff member. Always computed, never stored.
library;

/// All-time totals for one staff member, in centavos, with voided rows
/// already left out.
class BalanceParts {
  const BalanceParts({
    this.earnings = 0,
    this.heldTips = 0,
    this.payouts = 0,
    this.advances = 0,
    this.adjustments = 0,
  });

  /// Sum of staff shares from sales.
  final int earnings;

  /// Tips the shop is holding (GCash). Cash tips are not counted.
  final int heldTips;
  final int payouts;
  final int advances;

  /// Signed: positive raises the balance, negative lowers it.
  final int adjustments;

  /// Positive: the shop owes the staff member. Negative: he owes the shop.
  int get balance => earnings + heldTips - payouts - advances + adjustments;
}

/// "Owed to barbers": the sum of the positive balances only.
int totalOwed(Iterable<int> balances) =>
    balances.where((b) => b > 0).fold(0, (sum, b) => sum + b);
