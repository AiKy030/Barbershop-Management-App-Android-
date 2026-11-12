import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../data/demo_data.dart';
import '../../data/ledger_repositories.dart';
import '../../data/records_repository.dart';
import '../../data/repositories.dart';
import '../../data/sale_repository.dart';
import '../../domain/money.dart';
import '../../domain/records.dart';
import '../../domain/sale.dart';
import '../expenses/expenses_screen.dart';
import '../home_shell.dart';
import '../records/add_entries_screen.dart';
import '../records/edit_entry_sheet.dart';
import '../records/pick_day_screen.dart';
import '../records/records_screen.dart';
import '../reports/reports_screen.dart';
import '../staff/staff_sheets.dart';
import '../staff/staff_tab.dart';
import '../state/ledger.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../today/add_client_screen.dart';
import '../today/close_day_screen.dart';
import '../today/today_screen.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/sheet.dart';

/// Runs the guided tutorial, then remembers that it was seen.
Future<void> startTutorial(BuildContext context) async {
  final config = context.read<ShopConfig>();
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const TutorialScreen(),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  await config.setTutorialSeen();
}

/// First launch: offer the tutorial once.
Future<void> offerTutorial(BuildContext context) async {
  final config = context.read<ShopConfig>();
  final start = await showAppSheet<bool>(
    context,
    (_) => const ConfirmSheet(
      title: S.welcomeTitle,
      body: S.welcomeBody,
      confirmLabel: S.startTutorial,
    ),
  );
  await config.setTutorialSeen();
  if (start == true && context.mounted) await startTutorial(context);
}

/// Which element each step points at. See [TutorialAnchor].
const _targets = [
  'addClient',
  'clientGrids',
  'toast',
  'owedTile',
  'payButtons',
  'sheet',
  'sheet',
  'addExpense',
  'sheet',
  'closeDay',
  'closeLock',
  'export',
  'sheet',
  'recordsTable',
  'sheet',
  'calendar',
  'tallyGrid',
];

/// The 17-step tutorial. It shows the real screens over an in-memory demo
/// shop, dims everything except one target, and explains it in a card.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _keys = {for (final id in _targets.toSet()) id: GlobalKey()};
  final _stackKey = GlobalKey();

  DemoShop? _demo;
  ShopConfig? _config;
  Ledger? _ledger;

  /// A sample sale for the Edit Entry step.
  Sale? _sampleSale;
  int _step = 0;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    _openDemo();
  }

  Future<void> _openDemo() async {
    final demo = await DemoShop.open();
    final config = ShopConfig(
      settingsRepo: SettingsRepository(demo.db),
      staffRepo: StaffRepository(demo.db),
      serviceRepo: ServiceRepository(demo.db),
      categoryRepo: ExpenseCategoryRepository(demo.db),
    );
    final ledger = Ledger(
      sales: SaleRepository(demo.db),
      payments: PaymentRepository(demo.db),
      expenses: ExpenseRepository(demo.db),
      closures: ClosureRepository(demo.db),
      records: RecordsRepository(demo.db),
    );
    await config.load();
    await ledger.load();
    final recent = await ledger.records.sales(
      RecordsFilter.lastSevenDays(RecordsTab.sales, DateTime.now()),
      limit: 1,
    );
    if (!mounted) {
      await demo.close();
      return;
    }
    setState(() {
      _demo = demo;
      _config = config;
      _ledger = ledger;
      _sampleSale = recent.firstOrNull;
    });
  }

  @override
  void dispose() {
    _demo?.close();
    super.dispose();
  }

  void _next() {
    if (_step == _targets.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _step++;
      _target = null;
    });
  }

  /// Finds where the current target is on screen, once it has been laid out.
  void _measure() {
    final box =
        _keys[_targets[_step]]!.currentContext?.findRenderObject()
            as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
    if (rect != _target) setState(() => _target = rect);
  }

  Widget _tab(int index, Widget screen) => AppScaffold(
    body: screen,
    bottomBar: AppTabBar(
      index: index,
      staffLabel: _config!.settings.staffLabel,
      onChanged: (_) {},
    ),
  );

  Widget _withSheet(Widget base, Widget sheet) => Stack(
    children: [
      Positioned.fill(child: base),
      Align(
        alignment: Alignment.bottomCenter,
        child: TutorialAnchor(
          id: 'sheet',
          child: KeyedSubtree(key: ValueKey('sheet$_step'), child: sheet),
        ),
      ),
    ],
  );

  Widget _scene(BuildContext context) {
    final marlon = _config!.staff.firstWhere(
      (s) => s.id == _demo!.featuredStaffId,
    );
    final today = _tab(0, const TodayScreen());
    final detail = _tab(1, StaffDetailView(staff: marlon));
    final expenses = _tab(2, const ExpensesScreen());
    final reports = _tab(3, const ReportsScreen());
    return switch (_step) {
      0 || 9 => today,
      3 => _tab(1, const StaffListView()),
      1 => const AddClientScreen(demo: true),
      2 => Stack(
        children: [
          Positioned.fill(child: today),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 68 + 16 + 52 + 9,
            child: TutorialAnchor(
              id: 'toast',
              child: ToastBar(
                message: S.saved('Jun', 'Haircut', formatPesos(15000)),
                actionLabel: S.undo,
              ),
            ),
          ),
        ],
      ),
      4 => detail,
      5 => _withSheet(detail, PayOutSheet(staff: marlon)),
      6 => _withSheet(detail, CashAdvanceSheet(staff: marlon)),
      7 => expenses,
      8 => _withSheet(expenses, const ExpenseSheet()),
      10 => const CloseDayScreen(),
      11 => reports,
      12 => _withSheet(reports, const _ShareMockSheet()),
      13 => const RecordsScreen(),
      14 =>
        _sampleSale == null
            ? const RecordsScreen()
            : _withSheet(
                const RecordsScreen(),
                EditEntrySheet(sale: _sampleSale!),
              ),
      15 => const PickDayScreen(),
      _ => AddEntriesScreen(
        day: DateTime.now().subtract(const Duration(days: 1)),
        demo: true,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_demo == null) return ColoredBox(color: colors.bgApp);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });

    final size = MediaQuery.sizeOf(context);
    final target = _target;
    // The card sits below a target in the top half, otherwise above it.
    // When the preferred side has no room it takes the other side, and for
    // a target that fills the screen it sits over the target's lower part.
    const cardRoom = 250.0;
    final roomBelow = target == null ? 0.0 : size.height - target.bottom;
    final roomAbove = target == null ? 0.0 : target.top;
    final prefersBelow = target != null && target.center.dy < size.height / 2;
    final below = prefersBelow
        ? roomBelow >= cardRoom || roomAbove < cardRoom
        : roomAbove < cardRoom && roomBelow >= cardRoom;
    final overTarget =
        target != null && roomBelow < cardRoom && roomAbove < cardRoom;

    return Material(
      color: colors.bgApp,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ShopConfig>.value(value: _config!),
          ChangeNotifierProvider<Ledger>.value(value: _ledger!),
          ChangeNotifierProvider<ShellNav>(create: (_) => ShellNav()),
        ],
        child: TutorialAnchors(
          keys: _keys,
          child: Stack(
            key: _stackKey,
            children: [
              // The demo screens are for looking at only.
              Positioned.fill(
                child: ExcludeFocus(
                  child: IgnorePointer(
                    child: Builder(
                      builder: (context) => KeyedSubtree(
                        key: ValueKey(_step),
                        child: _scene(context),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _SpotlightPainter(
                    target: target,
                    dim: colors.tutorialScrim,
                    outline: colors.accent,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: target != null && below && !overTarget
                    ? target.bottom + 18
                    : null,
                bottom: target == null
                    ? 120
                    : overTarget
                    ? 32
                    : (below ? null : size.height - target.top + 18),
                child: _TipCard(
                  step: _step,
                  onSkip: () => Navigator.of(context).pop(),
                  onNext: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dims the screen except for a rounded hole around the target, and draws
/// an accent outline around the hole.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.target,
    required this.dim,
    required this.outline,
  });

  final Rect? target;
  final Color dim;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final target = this.target;
    if (target == null) {
      canvas.drawRect(full, Paint()..color = dim);
      return;
    }
    final hole = RRect.fromRectAndRadius(
      target.inflate(6).intersect(full.deflate(3)),
      const Radius.circular(20),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(full)
        ..addRRect(hole),
      Paint()..color = dim,
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = outline,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.dim != dim || old.outline != outline;
}

/// Tutorial tip card. Figma component 8:1883.
class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.step,
    required this.onSkip,
    required this.onNext,
  });

  final int step;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (title, body) = S.tutorialSteps[step];
    final last = step == S.tutorialSteps.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.stepOf(step + 1, S.tutorialSteps.length).toUpperCase(),
            style: AppText.caption.copyWith(color: colors.accent),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: AppText.headline.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(body, style: AppText.body.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Pressable(
                onTap: onSkip,
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.5 : 1,
                  child: Container(
                    height: 48,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      S.skipTutorial,
                      style: AppText.subhead.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Pressable(
                onTap: onNext,
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.7 : 1,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      last ? S.done : S.next,
                      style: AppText.headline.copyWith(
                        color: colors.textOnAccent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A drawing of the share sheet for the last step. The real one is the
/// Android system share sheet. Figma: 6:988.
class _ShareMockSheet extends StatelessWidget {
  const _ShareMockSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final week = DateTime.now();
    final monday = DateTime(week.year, week.month, week.day - week.weekday + 1);
    String key(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final fileName =
        'Barbershop_${key(monday)}_to_'
        '${key(DateTime(monday.year, monday.month, monday.day + 6))}.xlsx';

    Widget app(Widget icon, String label) => Expanded(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.bgFill,
              shape: BoxShape.circle,
            ),
            child: icon,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            style: AppText.caption.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
    Widget letter(String l) =>
        Text(l, style: AppText.headline.copyWith(color: colors.textPrimary));

    return AppSheet(
      title: S.shareExcelFile,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.bgApp,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.footnote.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                S.excelFileSheets,
                style: AppText.footnote.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            app(
              Icon(LucideIcons.arrowDown, size: 22, color: colors.textPrimary),
              S.saveToPhone,
            ),
            app(letter('M'), S.messenger),
            app(letter('G'), S.gmail),
            app(letter('D'), S.drive),
          ],
        ),
      ],
    );
  }
}
