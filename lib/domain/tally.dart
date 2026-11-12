/// The past-day tally: how many clients each staff member served for each
/// service, copied from a notebook, turned into sales. Pure Dart.
library;

import 'sale.dart';
import 'split.dart';

/// The largest count one box of the tally grid can hold.
const int maxTallyCount = 99;

/// The earliest year a past entry can be put in.
const int firstEntryYear = 2020;

/// One box of the grid with the price and percent as they are today.
class TallyLine {
  const TallyLine({
    required this.staffId,
    required this.staffPercent,
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.count,
  });

  final String staffId;

  /// The staff member's percent today.
  final int staffPercent;
  final String serviceId;
  final String serviceName;

  /// Centavos. The service's price today.
  final int price;
  final int count;
}

/// What a tally adds up to, shown before saving.
class TallySummary {
  const TallySummary({
    required this.clients,
    required this.sales,
    required this.staffShare,
    required this.shopShare,
  });

  factory TallySummary.of(Iterable<TallyLine> lines) {
    var clients = 0;
    var sales = 0;
    var staffShare = 0;
    for (final line in lines) {
      _check(line);
      // Each sale is split on its own, then counted, so the total matches
      // the sales that will be saved to the centavo.
      final split = splitSale(
        price: line.price,
        staffPercent: line.staffPercent,
      );
      clients += line.count;
      sales += line.price * line.count;
      staffShare += split.staffShare * line.count;
    }
    return TallySummary(
      clients: clients,
      sales: sales,
      staffShare: staffShare,
      shopShare: sales - staffShare,
    );
  }

  final int clients;

  /// Centavos.
  final int sales;
  final int staffShare;
  final int shopShare;
}

void _check(TallyLine line) {
  if (line.count < 0 || line.count > maxTallyCount) {
    throw ArgumentError.value(line.count, 'count');
  }
}

/// One sale per client counted, all on [forDate], all sharing [batchId].
///
/// Each sale is paid in cash with no tip, and stores the price and percent
/// from its line. [newId] makes the id of each sale.
List<Sale> tallySales({
  required Iterable<TallyLine> lines,
  required DateTime now,
  required DateTime forDate,
  required String batchId,
  required String Function() newId,
}) {
  final sales = <Sale>[];
  for (final line in lines) {
    _check(line);
    for (var i = 0; i < line.count; i++) {
      sales.add(
        Sale.record(
          id: newId(),
          now: now,
          forDate: forDate,
          staffId: line.staffId,
          staffPercent: line.staffPercent,
          serviceId: line.serviceId,
          serviceName: line.serviceName,
          price: line.price,
          paymentMethod: PaymentMethod.cash,
          batchId: batchId,
        ),
      );
    }
  }
  return sales;
}

/// Whether a past entry can be put on [day]: not after today, and not
/// before [firstEntryYear].
bool isPickableDay(DateTime day, DateTime now) {
  if (day.year < firstEntryYear) return false;
  return businessDateOf(day).compareTo(businessDateOf(now)) <= 0;
}

/// The cells of a month calendar that starts each week on Sunday: null for
/// the blanks before the 1st, then every day of the month.
List<DateTime?> monthCells(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final days = DateTime(month.year, month.month + 1, 0).day;
  return [
    // DateTime.weekday is 1 for Monday to 7 for Sunday.
    for (var i = 0; i < first.weekday % 7; i++) null,
    for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d),
  ];
}
