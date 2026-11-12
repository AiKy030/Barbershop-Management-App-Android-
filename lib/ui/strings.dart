/// Every on-screen string lives here so Tagalog or Taglish can be added later.
abstract final class S {
  // Tabs
  static const today = 'Today';
  static const expenses = 'Expenses';
  static const reports = 'Reports';
  static const settings = 'Settings';

  /// Plural of the staff label, for example "Barbers".
  static String staffPlural(String label) => '${label}s';

  // Common
  static const save = 'Save';
  static const done = 'Done';
  static const name = 'Name';
  static const comingLater = 'This screen comes in a later update.';
  static const notReadyYet = 'Not ready yet. Coming in a later update.';

  // Today
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
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

  /// For example "Wednesday, Nov 11".
  static String dayHeader(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
  static const closeDay = 'Close Day';
  static const shopNet = 'Shop net';
  static String cashAndGcash(String cash, String gcash) =>
      '$cash cash  ·  $gcash GCash';
  static const clients = 'Clients';
  static const sales = 'Sales';
  static const shopShare = 'Shop share';
  static const tipsToday = 'Tips today';
  static String staffToday(String label) => '${staffPlural(label)} today';
  static String clientCount(int count) =>
      count == 1 ? '1 client' : '$count clients';
  static String relieverPercent(int percent) => 'Reliever $percent%';
  static const addClient = 'Add Client';
  static String noStaffToday(String label) =>
      'Add your ${staffPlural(label).toLowerCase()} in Settings first.';
  static String saved(String staff, String service, String price) =>
      'Saved  ·  $staff  ·  $service $price';
  static String savedFor(String day, String staff, String price) =>
      'Saved for $day  ·  $staff  ·  $price';
  static String savedForDay(String day) => 'Saved for $day';
  static const undo = 'Undo';
  static const todayClosedHint = 'Today is closed. New entries need your PIN.';
  static const setPinFirstTitle = 'Set a PIN first';
  static const setPinFirstBody =
      'That day is closed. You need a PIN to change a closed day.';
  static const setPin = 'Set PIN';
  static String enterPinToChange(String day) => 'Enter PIN to change $day';
  static const enterPinToReopenToday = 'Enter PIN to reopen today';
  static const tooManyTries = 'Too many tries. Wait 30 seconds.';

  // Add Client
  static const cancel = 'Cancel';
  static const service = 'Service';
  static const details = 'Details';
  static const payment = 'Payment';
  static const price = 'Price';
  static const tip = 'Tip';
  static const cash = 'Cash';
  static const gcash = 'GCash';
  static const other = 'Other';
  static const customPrice = 'Custom price';
  static const otherService = 'Other service';
  static const otherNameHint = 'Beard trim';
  static String relieverTile(int percent) => 'Reliever · $percent%';
  static String splitPreview(String label, String staff, String shop) =>
      '$label gets $staff  ·  Shop gets $shop';
  static String pickFirst(String label) =>
      'Tap a ${label.toLowerCase()} and a service';
  static String saveAmount(String price) => 'Save  ·  $price';
  static String saveAmountFor(String price, String day) =>
      'Save  ·  $price  ·  $day';
  static const noServicesToAdd = 'Add your services in Settings first.';
  static const tipPaidHow = 'How was the tip paid?';
  static String tipCashNote(String label) =>
      'A cash tip goes straight to the ${label.toLowerCase()}.';
  static String tipGcashNote(String label) =>
      'The shop holds a GCash tip. It is added to what the '
      '${label.toLowerCase()} is owed.';

  // Dates
  static const _weekdayShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _monthLong = [
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

  /// "Wed"
  static String weekdayShort(DateTime d) => _weekdayShort[d.weekday - 1];

  /// "Nov 11"
  static String monthDay(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  /// "Wed, Nov 11"
  static String shortDay(DateTime d) => '${weekdayShort(d)}, ${monthDay(d)}';

  /// "November 2026"
  static String monthYear(DateTime d) => '${_monthLong[d.month - 1]} ${d.year}';

  /// "Nov 9 – 15" or "Oct 30 – Nov 5"
  static String dayRange(DateTime start, DateTime end) =>
      start.month == end.month
      ? '${monthDay(start)} – ${end.day}'
      : '${monthDay(start)} – ${monthDay(end)}';

  /// "2:05 PM", in the phone's local time.
  static String time(DateTime moment) {
    final t = moment.toLocal();
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  // Staff tab
  static String totalOwedTo(String label) =>
      'Total owed to ${staffPlural(label).toLowerCase()}';
  static String balanceSummary(int owed, int owing, String label) {
    final one = label.toLowerCase();
    final many = staffPlural(label).toLowerCase();
    if (owed == 0 && owing == 0) return 'Nothing owed right now';
    final parts = <String>[
      if (owed == 1) '1 $one has a balance',
      if (owed > 1) '$owed $many have a balance',
      if (owing == 1) '1 owes the shop',
      if (owing > 1) '$owing owe the shop',
    ];
    return parts.join('  ·  ');
  }

  static const active = 'Active';
  static String typeAndPercent(String type, int percent) => '$type · $percent%';
  static const balance = 'Balance';
  static String shopOwes(String name) => 'The shop owes $name';
  static String owesShop(String name) => '$name owes the shop';
  static const nothingOwed = 'Nothing owed';
  static const payOut = 'Pay Out';
  static const cashAdvance = 'Cash Advance';
  static const thisWeek = 'This week';
  static const earnings = 'Earnings';
  static const payout = 'Payout';
  static const cashAdvanceEntry = 'Cash advance';
  static const gcashTips = 'GCash tips';
  static const adjustment = 'Adjustment';
  static const carriedOver = 'Carried over';
  static const fromLastWeek = 'From last week';
  static const noEntriesThisWeek = 'Nothing recorded this week yet.';
  static String payOutTo(String name) => 'Pay Out to $name';
  static const fullBalance = 'Full balance';
  static const half = 'Half';
  static const otherAmount = 'Other amount';
  static const balanceAfter = 'Balance after';
  static const confirmPayout = 'Confirm Payout';
  static String cashAdvanceFor(String name) => 'Cash Advance for $name';
  static const reasonOptional = 'Reason (optional)';
  static const confirmCashAdvance = 'Confirm Cash Advance';
  static const voidPayout = 'Void Payout';
  static const voidAdvance = 'Void Cash Advance';
  static const voidAdjustment = 'Void Adjustment';
  static const voidSale = 'Void';
  static const voided = 'Voided';
  static String salesOn(String day) => 'Sales on $day';
  static const amount = 'Amount';
  static const paidBy = 'Paid by';
  static const reason = 'Reason';
  static const date = 'Date';

  // Expenses
  static const thisMonth = 'This month';
  static String expenseCount(int n) => n == 1 ? '1 expense' : '$n expenses';
  static String todayAmount(String amount) => '$amount today';
  static const earlier = 'Earlier';
  static const addExpense = 'Add Expense';
  static const editExpense = 'Edit Expense';
  static const noteOptional = 'Note (optional)';
  static const saveExpense = 'Save Expense';
  static const voidExpense = 'Void Expense';
  static const noExpenses = 'No expenses this month.';

  // Close Day
  static String staffShare(String label) => "${staffPlural(label)}' share";
  static const cashDrawer = 'Cash drawer';
  static const cashSales = 'Cash sales';
  static const paidOutInCash = 'Paid out in cash';
  static const paidOutDetail = 'Payouts, advances, expenses';
  static const shouldBeInDrawer = 'Should be in drawer';
  static const cashCounted = 'Cash counted';
  static const tapToCount = 'Tap to type what you counted';
  static const matches = 'Matches';
  static String shortBy(String amount) => 'Short by $amount';
  static String overBy(String amount) => 'Over by $amount';
  static const closeNote =
      'Closing locks today’s entries. You can reopen the day later.';
  static const closeDayAndLock = 'Close Day and Lock';
  static const reopenDay = 'Reopen Day';
  static const dayClosed = 'Day closed';
  static const reopenQuestion = 'Reopen today?';
  static const reopenNote =
      'Entries can be added and changed again until you close the day.';
  static const dayClosedSaved = 'Day closed and locked';
  static const dayReopened = 'Day reopened';
  static const backupReminderTitle = 'Time to back up';
  static const backupReminderBody =
      'Your last backup was more than 7 days ago. A backup keeps your '
      'records safe if the phone is lost or broken.';
  static const notNow = 'Not now';

  // Reports
  static const day = 'Day';
  static const week = 'Week';
  static const month = 'Month';
  static String byStaff(String label) => 'By ${label.toLowerCase()}';
  static const exportToExcel = 'Export to Excel';

  // Records
  static const records = 'Records';
  static const search = 'Search';
  static String searchHint(String label) =>
      '$label, service or amount';
  static const payouts = 'Payouts';
  static const advance = 'Advance';
  static const paid = 'Paid';
  static const note = 'Note';
  static const type = 'Type';
  static const category = 'Category';
  static const total = 'Total';
  static const dates = 'Dates';
  static const last7Days = 'Last 7 days';
  static const last30Days = 'Last 30 days';
  static const showVoided = 'Show voided';
  static const allCategories = 'All categories';
  static String allStaff(String label) =>
      'All ${staffPlural(label).toLowerCase()}';
  static String staffShareOf(String label) => '$label share';
  static String rowCount(int n) => n == 1 ? '1 row' : '$n rows';
  static const noRecords = 'No entries for these filters.';
  static const addPastEntry = 'Add Past Entry';
  // Past entries
  static const weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  static const legendHasEntries = 'Has entries';
  static const legendToday = 'Ring = today';
  static const legendFuture = 'Faded = not yet';
  static const noEntriesYet = 'No entries yet';
  static const nothingRecorded = 'Nothing was recorded on this day';
  static String clientsRecorded(int n) =>
      n == 1 ? '1 client recorded' : '$n clients recorded';
  static String salesSoFar(String amount) => '$amount in sales so far';
  static const noClientsRecorded = 'No clients recorded';
  static String otherEntries(int n) =>
      n == 1 ? '1 other entry on this day' : '$n other entries on this day';
  static const dayStatus = 'Day status';
  static const statusOpen = 'Open';
  static const statusClosed = 'Closed';
  static const statusOpenNote = 'Open. You can add entries';
  static const statusClosedNote = 'Closed. Adding needs your PIN';
  static String addEntriesTo(String day) => 'Add Entries to $day';
  static String viewRecordsFor(String day) => 'View Records for $day';
  static const back = 'Back';
  static const pastDayTitle = 'You are adding to a past day';
  static String pastDayBody(String day) =>
      'Everything here is saved to $day, not today.';
  static const todayNoticeTitle = 'You are adding to today';
  static const todayNoticeBody = 'Everything here is saved to today.';
  static const tabClients = 'Clients';
  static const tabExpense = 'Expense';
  static const tabPayout = 'Payout';
  static const tabAdvance = 'Advance';
  static const howManyClients = 'How many clients each';
  static String addedToBalance(String label) =>
      'Added to each ${label.toLowerCase()}’s balance';
  static const savedAsCash =
      'Saved as cash at today’s prices. Change any entry later in Records.';
  static String saveClientsTo(int n, String day) =>
      n == 1 ? 'Save 1 Client to $day' : 'Save $n Clients to $day';
  static String saveExpenseTo(String day) => 'Save Expense to $day';
  static String savePayoutTo(String day) => 'Save Payout to $day';
  static String saveAdvanceTo(String day) => 'Save Advance to $day';
  static String savedClientsFor(int n, String day) =>
      n == 1 ? 'Saved 1 client for $day' : 'Saved $n clients for $day';
  static const noServicesYet = 'Add your services in Settings first.';
  static String pickStaffFirst(String label) =>
      'Tap a ${label.toLowerCase()} first.';

  static const editEntry = 'Edit Entry';
  static const saveChanges = 'Save Changes';
  static const voidThisEntry = 'Void This Entry';
  static const restoreEntry = 'Restore Entry';
  static const entryUpdated = 'Entry updated';
  static const entryVoided = 'Entry voided';
  static const entryRestored = 'Entry restored';
  static const entryWasVoided =
      'This entry was voided. It is kept but not counted.';
  static const otherServiceOption = 'Other…';
  static const legendAddedLater = 'Added later for a past day';
  static const legendVoided = 'Crossed out = voided';
  static const swipeForMore = 'Swipe the table sideways to see more.';
  static String shopNetFor(String range) => 'Shop net  ·  $range';
  static const from = 'From';
  static const to = 'To';
  static const export = 'Export';
  static const exportFailed = 'Could not make the file. Try again.';
  static const exportNote =
      'Makes one Excel file with a sheet for each month. Each sheet has '
      'that month’s sales, payouts and expenses.';
  static const noSales = 'No sales in this period.';

  // Backup and restore
  static String lastBackup(int daysAgo) => switch (daysAgo) {
    0 => 'Last backup today',
    1 => 'Last backup yesterday',
    _ => 'Last backup $daysAgo days ago',
  };
  static const backupFailed = 'Could not make the backup. Try again.';
  static const restoreTitle = 'Restore from this file?';
  static const restoreBody =
      'This replaces everything on this phone with the records in the '
      'backup file. This cannot be undone.';
  static const notABackup = 'That file is not a Barbershop backup.';
  static const restored = 'Backup restored';

  // PIN lock
  static const on = 'On';
  static const enterPin = 'Enter PIN';
  static const newPin = 'Type a new 4-digit PIN';
  static const confirmPin = 'Type the PIN again';
  static const pinMismatch = 'The PINs did not match. Try again.';
  static const wrongPin = 'Wrong PIN. Try again.';
  static const pinTurnedOn = 'PIN is set';
  static const pinTurnedOff = 'PIN removed';
  static const pinCurrent = 'Type your PIN to remove it';
  static const pinToChangeLock = 'Type your PIN';
  static const askPinOnOpen = 'Ask for PIN when opening the app';
  static const pinSubtitle = 'Needed to change a closed day';
  static const englishOnly = 'English only for now.';

  // Tutorial
  static String stepOf(int step, int total) => 'Step $step of $total';
  static const skipTutorial = 'Skip tutorial';
  static const next = 'Next';
  static const welcomeTitle = 'Welcome';
  static const welcomeBody =
      'Want a quick tour? It takes two minutes, uses sample data, and never '
      'touches your own records.';
  static const startTutorial = 'Start Tutorial';
  static const shareExcelFile = 'Share Excel File';
  static const excelFileSheets = 'Excel file  ·  one sheet per month';
  static const saveToPhone = 'Save to phone';
  static const messenger = 'Messenger';
  static const gmail = 'Gmail';
  static const drive = 'Drive';

  /// Title and body for each tutorial step, in order. Wording from SPEC.md.
  static const tutorialSteps = <(String, String)>[
    (
      'Add a client',
      'Tap Add Client every time a barber finishes a customer. This is the '
          'button you will use the most.',
    ),
    (
      'Three taps',
      'Tap the barber, tap the service, then tap Save at the bottom. The app '
          'divides the money by itself.',
    ),
    (
      'Sale saved',
      'The sale is recorded and the totals update by themselves. Tap Undo '
          'within a few seconds if it was a mistake.',
    ),
    (
      'Money owed to barbers',
      'This is money you are holding for the barbers. It is not the shop’s '
          'money to spend.',
    ),
    (
      'Paying a barber',
      'Open a barber, then tap Pay Out when you give him money, or Cash '
          'Advance when he borrows. No more paper notes.',
    ),
    (
      'What Pay Out does',
      'Choose the amount, all or part of his balance, and how you are '
          'paying. Tap Confirm Payout and his balance goes down.',
    ),
    (
      'What Cash Advance does',
      'Type the amount, and a reason if you like. Tap Confirm Cash Advance '
          'and it is deducted from his balance automatically.',
    ),
    (
      'Shop expenses',
      'Tap Add Expense for rent, electricity or supplies. Expenses never '
          'reduce the barbers’ pay.',
    ),
    (
      'What Add Expense does',
      'Type the amount, pick the category, and choose Cash or GCash. Tap '
          'Save Expense and the shop net goes down.',
    ),
    (
      'End of the day',
      'Tap Close Day to see the final summary, check the cash drawer, and '
          'lock the day.',
    ),
    (
      'What Close Day does',
      'Check the summary and the cash drawer above. Tap Close Day and Lock '
          'so today’s entries cannot be changed by accident.',
    ),
    (
      'Excel file',
      'Tap Export to Excel to save the file on the phone or send it by '
          'Messenger, Gmail or Drive.',
    ),
    (
      'What Export does',
      'The Excel file is ready. Tap Save to phone to keep it, or tap an app '
          'to send it.',
    ),
    (
      'All your records',
      'Every entry in one table, like a simple Excel sheet. Tap a row to '
          'correct it or void it.',
    ),
    (
      'Fixing a mistake',
      'Tap any line to correct it, then tap Save Changes. The totals and '
          'the barber’s balance are recomputed by themselves.',
    ),
    (
      'A day you forgot',
      'Choose the past day you want to add entries to. A blue dot means '
          'that day already has entries.',
    ),
    (
      'Copying from a notebook',
      'Tap a box and type how many customers that barber served for that '
          'service. These entries get a blue dot in Records.',
    ),
  ];

  // Settings sections
  static const sectionShop = 'Shop';
  static const sectionManage = 'Manage';
  static const sectionBackup = 'Backup';
  static const sectionApp = 'App';

  // Shop
  static const shopName = 'Shop name';
  static const defaultSplit = 'Default split';
  static String splitSubtitle(String staffLabel) => '$staffLabel / Shop';
  static String splitValue(int staff, int shop) => '$staff / $shop';
  static String staffGets(String staffLabel) => '$staffLabel gets';
  static const shopGets = 'Shop gets';
  static String percent(int value) => '$value%';
  static const splitHelp = 'Past sales keep the split they were saved with.';

  // Services
  static const servicesAndPrices = 'Services and prices';
  static const services = 'Services';
  static const addService = 'Add Service';
  static const editService = 'Edit Service';
  static String priceLabel(String pesoSign) => 'Price ($pesoSign)';
  static const noServices = 'No services yet. Tap Add Service to make one.';
  static const archive = 'Archive';
  static const restore = 'Restore';
  static const archived = 'Archived';
  static const serviceNameHint = 'Haircut';

  // Staff
  static String addStaff(String label) => 'Add $label';
  static String editStaff(String label) => 'Edit $label';
  static String noStaff(String label) =>
      'No ${staffPlural(label).toLowerCase()} yet. Tap Add $label to make one.';
  static const regular = 'Regular';
  static const reliever = 'Reliever';
  static const ownPercent = 'Own percent';
  static String defaultPercentHint(int value) => 'Default $value%';
  static const ownPercentHelp = 'Leave blank to use the default split.';
  static const markInactive = 'Mark Inactive';
  static const markActive = 'Mark Active';
  static const inactive = 'Inactive';
  static const staffNameHint = 'Jun';

  // Expense categories
  static const expenseCategories = 'Expense categories';
  static const categories = 'Categories';
  static const addCategory = 'Add Category';
  static const editCategory = 'Edit Category';
  static const noCategories =
      'No categories yet. Tap Add Category to make one.';
  static const categoryNameHint = 'Rent';

  // Backup
  static const backUpNow = 'Back up now';
  static const neverBackedUp = 'Never backed up';
  static const restoreFromFile = 'Restore from file';

  // App
  static const tutorial = 'Tutorial';
  static const start = 'Start';
  static const appearance = 'Appearance';
  static const appearanceSystem = 'System';
  static const appearanceLight = 'Light';
  static const appearanceDark = 'Dark';
  static const language = 'Language';
  static const english = 'English';
  static const pinLock = 'PIN';
  static const off = 'Off';
}
