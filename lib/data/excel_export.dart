import 'package:excel/excel.dart';

import '../domain/entries.dart';
import '../domain/records.dart';
import '../domain/report.dart';
import '../domain/sale.dart';

/// One month's part of an export. Voided rows must already be left out.
/// When the chosen dates start or end inside the month, [range] covers
/// only the chosen days.
class MonthExport {
  const MonthExport({
    required this.range,
    required this.report,
    required this.sales,
    required this.payments,
    required this.expenses,
    required this.balancesAtEnd,
  });

  final DateRange range;
  final PeriodReport report;

  /// Oldest first.
  final List<Sale> sales;
  final List<StaffPayment> payments;
  final List<Expense> expenses;

  /// Staff id to balance (centavos) at the end of [range].
  final Map<String, int> balancesAtEnd;
}

/// Everything one Excel file needs.
class ExportData {
  const ExportData({
    required this.range,
    required this.months,
    required this.staffNames,
    required this.staffLabel,
  });

  /// The dates the owner chose.
  final DateRange range;

  /// One entry per calendar month in [range], oldest first.
  final List<MonthExport> months;

  /// Staff id to name.
  final Map<String, String> staffNames;

  /// For example "Barber". Used in headings.
  final String staffLabel;
}

/// `Barbershop_YYYY-MM-DD.xlsx`, or `..._to_YYYY-MM-DD.xlsx` for a range.
String exportFileName(DateRange range) => range.isSingleDay
    ? 'Barbershop_${range.startKey}.xlsx'
    : 'Barbershop_${range.startKey}_to_${range.endKey}.xlsx';

/// The first sheet of a file that covers more than one month.
const exportSummarySheet = 'Summary';

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The sheet for a month, for example "Nov 2026".
String monthSheetName(DateTime month) =>
    '${_monthShort[month.month - 1]} ${month.year}';

/// Amounts go into the file as numbers in pesos, not as text.
CellValue _money(int centavos) => DoubleCellValue(centavos / 100);
CellValue _text(String? value) => TextCellValue(value ?? '');
CellValue _count(int value) => IntCellValue(value);

String _methodLabel(PaymentMethod? m) => switch (m) {
  PaymentMethod.cash => 'Cash',
  PaymentMethod.gcash => 'GCash',
  null => '',
};

String _typeLabel(PaymentType type) => switch (type) {
  PaymentType.payout => 'Payout',
  PaymentType.advance => 'Advance',
  PaymentType.adjustment => 'Adjustment',
};

String _time(DateTime createdAt) {
  final t = createdAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

final _bold = CellStyle(bold: true);

/// Writes a sheet from the top down, one row at a time.
class _SheetWriter {
  _SheetWriter(this.sheet);

  final Sheet sheet;
  int _row = 0;

  void row(List<CellValue?> cells, {bool bold = false}) {
    for (var col = 0; col < cells.length; col++) {
      final value = cells[col];
      if (value == null) continue;
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: _row),
        value,
        cellStyle: bold ? _bold : null,
      );
    }
    _row++;
  }

  void blank() => _row++;

  /// A block: its title, the column headings, the rows, then a total row.
  /// With no rows it says "None" instead.
  void block(
    String title,
    List<String> headings,
    List<List<CellValue?>> rows, {
    List<CellValue?>? total,
  }) {
    row([_text(title)], bold: true);
    if (rows.isEmpty) {
      row([_text('None')]);
    } else {
      row([for (final h in headings) _text(h)], bold: true);
      rows.forEach(row);
      if (total != null) row(total, bold: true);
    }
    blank();
  }
}

/// Builds the workbook bytes: one sheet per month. Each month's sheet has a
/// summary, then Sales, Payouts and advances, Expenses and the per-staff
/// totals, one under the other. A file that covers more than one month
/// starts with a Summary sheet that has one line per month.
List<int> buildWorkbook(ExportData data) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final label = data.staffLabel;
  final labelPlural = '${label}s';
  String name(String id) => data.staffNames[id] ?? '';
  CellValue later(String businessDate, DateTime createdAt) =>
      _text(isAddedLater(businessDate, createdAt) ? 'Yes' : '');

  final sheetNames = <String>[];

  if (data.months.length > 1) {
    sheetNames.add(exportSummarySheet);
    final writer = _SheetWriter(excel[exportSummarySheet]);
    writer.row([
      _text('${data.range.startKey} to ${data.range.endKey}'),
    ], bold: true);
    writer.blank();
    writer.row([
      _text('Month'),
      _text('Clients'),
      _text('Sales'),
      _text("$labelPlural' share"),
      _text('Shop share'),
      _text('Expenses'),
      _text('Shop net'),
      _text('Payouts made'),
      _text('Advances given'),
    ], bold: true);
    var clients = 0;
    final sums = List<int>.filled(7, 0);
    for (final month in data.months) {
      final t = month.report.totals;
      final values = [
        t.sales,
        t.staffShare,
        t.shopShare,
        t.expenses,
        t.shopNet,
        month.report.payouts,
        month.report.advances,
      ];
      clients += t.clients;
      for (var i = 0; i < values.length; i++) {
        sums[i] += values[i];
      }
      writer.row([
        _text(monthSheetName(month.range.start)),
        _count(t.clients),
        for (final v in values) _money(v),
      ]);
    }
    writer.row([
      _text('Total'),
      _count(clients),
      for (final v in sums) _money(v),
    ], bold: true);
    for (var col = 0; col < 9; col++) {
      writer.sheet.setColumnWidth(col, 16);
    }
  }

  for (final month in data.months) {
    final sheetName = monthSheetName(month.range.start);
    sheetNames.add(sheetName);
    final writer = _SheetWriter(excel[sheetName]);
    final report = month.report;
    final totals = report.totals;
    final owed = month.balancesAtEnd.values
        .where((b) => b > 0)
        .fold(0, (sum, b) => sum + b);

    writer.row([
      _text(
        '${_monthLong[month.range.start.month - 1]} '
        '${month.range.start.year}',
      ),
    ], bold: true);
    writer.row([
      _text(
        month.range.isSingleDay
            ? month.range.startKey
            : '${month.range.startKey} to ${month.range.endKey}',
      ),
    ]);
    writer.blank();

    writer.row([_text('SUMMARY')], bold: true);
    for (final line in <List<CellValue>>[
      [_text('Clients'), _count(totals.clients)],
      [_text('Total sales'), _money(totals.sales)],
      [_text('Cash sales'), _money(totals.cashSales)],
      [_text('GCash sales'), _money(totals.gcashSales)],
      [_text('Tips'), _money(totals.tips)],
      [_text("$labelPlural' share"), _money(totals.staffShare)],
      [_text('Shop share'), _money(totals.shopShare)],
      [_text('Expenses'), _money(totals.expenses)],
      [_text('Shop net'), _money(totals.shopNet)],
      [_text('Payouts made'), _money(report.payouts)],
      [_text('Advances given'), _money(report.advances)],
      [_text('Total owed to ${labelPlural.toLowerCase()}'), _money(owed)],
    ]) {
      writer.row(line);
    }
    writer.blank();

    writer.block(
      'SALES',
      [
        'Date',
        'Time',
        label,
        'Service',
        'Price',
        '$label %',
        '$label share',
        'Shop share',
        'Tip',
        'Payment method',
        'Note',
        'Added later',
      ],
      [
        for (final s in month.sales)
          [
            _text(s.businessDate),
            _text(_time(s.createdAt)),
            _text(name(s.staffId)),
            _text(s.serviceName),
            _money(s.price),
            _count(s.staffPercent),
            _money(s.staffShare),
            _money(s.shopShare),
            _money(s.tip),
            _text(_methodLabel(s.paymentMethod)),
            _text(s.note),
            later(s.businessDate, s.createdAt),
          ],
      ],
      total: [
        _text('Total'),
        null,
        null,
        null,
        _money(totals.sales),
        null,
        _money(totals.staffShare),
        _money(totals.shopShare),
        _money(totals.tips),
      ],
    );

    writer.block(
      'PAYOUTS AND ADVANCES',
      [
        'Date',
        label,
        'Type',
        'Amount',
        'Payment method',
        'Note',
        'Added later',
      ],
      [
        for (final p in month.payments)
          [
            _text(p.businessDate),
            _text(name(p.staffId)),
            _text(_typeLabel(p.type)),
            _money(p.amount),
            _text(_methodLabel(p.paymentMethod)),
            _text(p.note),
            later(p.businessDate, p.createdAt),
          ],
      ],
      // Money handed over: payouts and advances. Adjustments are listed
      // above but are not money paid out.
      total: [
        _text('Total paid out'),
        null,
        null,
        _money(report.payouts + report.advances),
      ],
    );

    writer.block(
      'EXPENSES',
      ['Date', 'Category', 'Amount', 'Payment method', 'Note', 'Added later'],
      [
        for (final e in month.expenses)
          [
            _text(e.businessDate),
            _text(e.category),
            _money(e.amount),
            _text(_methodLabel(e.paymentMethod)),
            _text(e.note),
            later(e.businessDate, e.createdAt),
          ],
      ],
      total: [_text('Total'), null, _money(totals.expenses)],
    );

    final staffIds = {...report.byStaff.keys, ...month.balancesAtEnd.keys}
        .toList()
      ..sort((a, b) => name(a).compareTo(name(b)));
    writer.block(
      labelPlural.toUpperCase(),
      [
        label,
        'Clients',
        'Sales',
        'Earnings',
        'Tips',
        'Advances',
        'Payouts',
        'Balance at end',
      ],
      [
        for (final id in staffIds)
          [
            _text(name(id)),
            _count(report.forStaff(id).clients),
            _money(report.forStaff(id).sales),
            _money(report.forStaff(id).earnings),
            _money(report.forStaff(id).tips),
            _money(report.forStaff(id).advances),
            _money(report.forStaff(id).payouts),
            _money(month.balancesAtEnd[id] ?? 0),
          ],
      ],
    );

    writer.sheet.setColumnWidth(0, 22);
    for (var col = 1; col < 12; col++) {
      writer.sheet.setColumnWidth(col, 16);
    }
  }

  if (defaultSheet != null && !sheetNames.contains(defaultSheet)) {
    excel.setDefaultSheet(sheetNames.first);
    excel.delete(defaultSheet);
  }
  return excel.encode()!;
}

const _tabNames = {
  RecordsTab.sales: 'Sales',
  RecordsTab.payouts: 'Payouts',
  RecordsTab.expenses: 'Expenses',
};

/// `Barbershop_Records_Sales_YYYY-MM-DD_to_YYYY-MM-DD.xlsx`
String recordsFileName(RecordsFilter filter) =>
    'Barbershop_Records_${_tabNames[filter.tab]}_'
    '${filter.range.startKey}_to_${filter.range.endKey}.xlsx';

/// The Records table as one sheet, named after the tab: exactly the rows
/// given, in the order given. Pass the rows for [tab] only.
///
/// With [includeVoided] a "Voided" column is added, so sums made in Excel
/// can leave those rows out.
List<int> buildRecordsWorkbook({
  required RecordsTab tab,
  List<Sale> sales = const [],
  List<StaffPayment> payments = const [],
  List<Expense> expenses = const [],
  required Map<String, String> staffNames,
  required String staffLabel,
  required bool includeVoided,
}) {
  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  final sheetName = _tabNames[tab]!;
  final sheet = excel[sheetName];
  String name(String id) => staffNames[id] ?? '';
  CellValue yes(bool value) => _text(value ? 'Yes' : '');
  List<CellValue> tail(String businessDate, DateTime createdAt, bool voided) =>
      [
        yes(isAddedLater(businessDate, createdAt)),
        if (includeVoided) yes(voided),
      ];
  final tailHeader = [
    _text('Added later'),
    if (includeVoided) _text('Voided'),
  ];

  switch (tab) {
    case RecordsTab.sales:
      sheet.appendRow([
        _text('Date'),
        _text('Time'),
        _text(staffLabel),
        _text('Service'),
        _text('Price'),
        _text('$staffLabel %'),
        _text('$staffLabel share'),
        _text('Shop share'),
        _text('Tip'),
        _text('Payment method'),
        _text('Note'),
        ...tailHeader,
      ]);
      for (final s in sales) {
        sheet.appendRow([
          _text(s.businessDate),
          _text(_time(s.createdAt)),
          _text(name(s.staffId)),
          _text(s.serviceName),
          _money(s.price),
          _count(s.staffPercent),
          _money(s.staffShare),
          _money(s.shopShare),
          _money(s.tip),
          _text(_methodLabel(s.paymentMethod)),
          _text(s.note),
          ...tail(s.businessDate, s.createdAt, s.voided),
        ]);
      }
    case RecordsTab.payouts:
      sheet.appendRow([
        _text('Date'),
        _text(staffLabel),
        _text('Type'),
        _text('Amount'),
        _text('Payment method'),
        _text('Note'),
        ...tailHeader,
      ]);
      for (final p in payments) {
        sheet.appendRow([
          _text(p.businessDate),
          _text(name(p.staffId)),
          _text(_typeLabel(p.type)),
          _money(p.amount),
          _text(_methodLabel(p.paymentMethod)),
          _text(p.note),
          ...tail(p.businessDate, p.createdAt, p.voided),
        ]);
      }
    case RecordsTab.expenses:
      sheet.appendRow([
        _text('Date'),
        _text('Category'),
        _text('Amount'),
        _text('Payment method'),
        _text('Note'),
        ...tailHeader,
      ]);
      for (final e in expenses) {
        sheet.appendRow([
          _text(e.businessDate),
          _text(e.category),
          _money(e.amount),
          _text(_methodLabel(e.paymentMethod)),
          _text(e.note),
          ...tail(e.businessDate, e.createdAt, e.voided),
        ]);
      }
  }
  for (var col = 0; col < 13; col++) {
    sheet.setColumnWidth(col, 16);
  }
  if (defaultSheet != null && defaultSheet != sheetName) {
    excel.setDefaultSheet(sheetName);
    excel.delete(defaultSheet);
  }
  return excel.encode()!;
}
