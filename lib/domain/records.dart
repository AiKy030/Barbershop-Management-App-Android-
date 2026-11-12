/// The Records table: which entries to show and how they are counted.
/// Pure Dart.
library;

import 'money.dart';
import 'report.dart';
import 'sale.dart';

enum RecordsTab { sales, payouts, expenses }

/// An entry was "added later" when it was put on a day before the day it
/// was typed in. Nothing is stored for this; it is worked out each time.
bool isAddedLater(String businessDate, DateTime createdAt) =>
    businessDate.compareTo(businessDateOf(createdAt)) < 0;

/// What the owner typed in the search box.
class RecordsSearch {
  const RecordsSearch._(this.text, this.centavos);

  factory RecordsSearch.parse(String input) {
    final text = input.trim();
    return RecordsSearch._(text, text.isEmpty ? null : parsePesos(text));
  }

  /// Matched against names, services, categories and notes.
  final String text;

  /// Set when the text is an amount. "150" matches entries of exactly ₱150.
  final int? centavos;

  bool get isEmpty => text.isEmpty;
}

/// The filters above the Records table.
class RecordsFilter {
  RecordsFilter({
    required this.tab,
    required this.range,
    this.staffId,
    this.category,
    this.showVoided = false,
    this.search = '',
  });

  /// The last seven days, today included.
  factory RecordsFilter.lastSevenDays(RecordsTab tab, DateTime now) =>
      RecordsFilter(
        tab: tab,
        range: DateRange(DateTime(now.year, now.month, now.day - 6), now),
      );

  final RecordsTab tab;
  final DateRange range;

  /// Sales and Payouts tabs: one staff member, or null for everyone.
  final String? staffId;

  /// Expenses tab: one category, or null for all.
  final String? category;
  final bool showVoided;
  final String search;

  RecordsFilter copyWith({
    RecordsTab? tab,
    DateRange? range,
    String? Function()? staffId,
    String? Function()? category,
    bool? showVoided,
    String? search,
  }) => RecordsFilter(
    tab: tab ?? this.tab,
    range: range ?? this.range,
    staffId: staffId == null ? this.staffId : staffId(),
    category: category == null ? this.category : category(),
    showVoided: showVoided ?? this.showVoided,
    search: search ?? this.search,
  );

  /// Changes when anything that affects the rows changes.
  String get key =>
      '${tab.name}|${range.startKey}|${range.endKey}|$staffId|$category|'
      '$showVoided|${search.trim()}';
}

/// What is already recorded on one day, shown under the calendar.
class DayEntries {
  const DayEntries({
    required this.clients,
    required this.sales,
    required this.others,
  });

  final int clients;

  /// Centavos.
  final int sales;

  /// Payouts, advances, adjustments and expenses on the day.
  final int others;

  bool get isEmpty => clients == 0 && others == 0;
}

/// The total row: how many entries match the filters and what they add up
/// to. Voided entries are never counted, even when they are shown.
class RecordsTotal {
  const RecordsTotal({required this.count, required this.sum});

  static const zero = RecordsTotal(count: 0, sum: 0);

  final int count;

  /// Centavos. Sales: prices. Payouts: amounts, adjustments signed.
  /// Expenses: amounts.
  final int sum;
}
