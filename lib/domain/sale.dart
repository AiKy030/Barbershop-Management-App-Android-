/// A recorded sale. No Flutter and no database imports here.
library;

import 'split.dart';

enum PaymentMethod { cash, gcash }

/// The shop's day as `YYYY-MM-DD`, taken from the phone's local date.
String businessDateOf(DateTime moment) {
  final local = moment.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

/// The business date for a new entry made at [now]. [forDate] puts it on an
/// earlier day (a forgotten entry). It can never be a day after [now].
String entryDateOf(DateTime now, DateTime? forDate) {
  final today = businessDateOf(now);
  if (forDate == null) return today;
  final key = businessDateOf(forDate);
  if (key.compareTo(today) > 0) throw ArgumentError.value(forDate, 'forDate');
  return key;
}

class Sale {
  const Sale({
    required this.id,
    required this.businessDate,
    required this.createdAt,
    required this.staffId,
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.staffPercent,
    required this.staffShare,
    required this.shopShare,
    required this.tip,
    required this.tipHeld,
    required this.paymentMethod,
    required this.note,
    required this.voided,
    this.batchId,
  });

  /// Builds a new sale, copying the service name, price and percent as they
  /// are right now so later changes in Settings never alter it. [forDate]
  /// backdates it to an earlier day.
  factory Sale.record({
    required String id,
    required DateTime now,
    DateTime? forDate,
    required String staffId,
    required int staffPercent,
    required String? serviceId,
    required String serviceName,
    required int price,
    int tip = 0,
    bool tipHeld = false,
    required PaymentMethod paymentMethod,
    String? note,
    String? batchId,
  }) {
    if (tip < 0) throw ArgumentError.value(tip, 'tip');
    final split = splitSale(price: price, staffPercent: staffPercent);
    return Sale(
      id: id,
      businessDate: entryDateOf(now, forDate),
      createdAt: now.toUtc(),
      staffId: staffId,
      serviceId: serviceId,
      serviceName: serviceName,
      price: price,
      staffPercent: staffPercent,
      staffShare: split.staffShare,
      shopShare: split.shopShare,
      tip: tip,
      tipHeld: tip > 0 && tipHeld,
      paymentMethod: paymentMethod,
      note: note,
      voided: false,
      batchId: batchId,
    );
  }

  /// A corrected copy of this sale. Anything left out stays as it was.
  ///
  /// - The shares are worked out again from the price and the percent
  ///   stored on this sale. Changing the split in Settings later never
  ///   reaches an old sale through an edit.
  /// - Only a change of staff member changes the percent: pass the new
  ///   person's current percent as [staffPercent]. For the same person
  ///   [staffPercent] is ignored.
  /// - [date] moves the sale to that day. It can never be after [now].
  /// - The id, the time it was typed in and the tally batch do not change.
  Sale edited({
    required DateTime now,
    DateTime? date,
    String? staffId,
    int? staffPercent,
    ({String? id, String name})? service,
    int? price,
    int? tip,
    bool? tipHeld,
    PaymentMethod? paymentMethod,
  }) {
    final newStaffId = staffId ?? this.staffId;
    final staffChanged = newStaffId != this.staffId;
    if (staffChanged && staffPercent == null) {
      throw ArgumentError.notNull('staffPercent');
    }
    final percent = staffChanged ? staffPercent! : this.staffPercent;
    final newPrice = price ?? this.price;
    final newTip = tip ?? this.tip;
    if (newTip < 0) throw ArgumentError.value(newTip, 'tip');
    final split = splitSale(price: newPrice, staffPercent: percent);
    return Sale(
      id: id,
      businessDate: date == null ? businessDate : entryDateOf(now, date),
      createdAt: createdAt,
      staffId: newStaffId,
      serviceId: service == null ? serviceId : service.id,
      serviceName: service == null ? serviceName : service.name,
      price: newPrice,
      staffPercent: percent,
      staffShare: split.staffShare,
      shopShare: split.shopShare,
      tip: newTip,
      tipHeld: newTip > 0 && (tipHeld ?? this.tipHeld),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note,
      voided: voided,
      batchId: batchId,
    );
  }

  /// True when [other] would be saved exactly like this sale.
  bool sameValuesAs(Sale other) =>
      businessDate == other.businessDate &&
      staffId == other.staffId &&
      serviceId == other.serviceId &&
      serviceName == other.serviceName &&
      price == other.price &&
      staffPercent == other.staffPercent &&
      staffShare == other.staffShare &&
      shopShare == other.shopShare &&
      tip == other.tip &&
      tipHeld == other.tipHeld &&
      paymentMethod == other.paymentMethod &&
      note == other.note;

  final String id;
  final String businessDate;
  final DateTime createdAt;
  final String staffId;

  /// Null for an "Other" sale with a custom name.
  final String? serviceId;
  final String serviceName;

  /// Centavos.
  final int price;
  final int staffPercent;
  final int staffShare;
  final int shopShare;

  /// Centavos. All of it belongs to the staff member, never the shop.
  final int tip;

  /// True when the shop is holding the tip (GCash), so it adds to the
  /// balance. False for a cash tip handed straight over.
  final bool tipHeld;
  final PaymentMethod paymentMethod;
  final String? note;
  final bool voided;

  /// Shared by the sales saved together from one past-day tally. Null for
  /// a sale entered on its own.
  final String? batchId;
}
