import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'expenses/expenses_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import 'staff/staff_tab.dart';
import 'state/ledger.dart';
import 'state/shop_config.dart';
import 'strings.dart';
import 'theme/app_colors.dart';
import 'theme/app_text.dart';
import 'today/today_screen.dart';
import 'tutorial/tutorial_screen.dart';
import 'widgets/basics.dart';

/// The five tabs: Today, staff, Expenses, Reports, Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Offer the tutorial once, on first launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !context.read<ShopConfig>().settings.tutorialSeen) {
        offerTutorial(context);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app refreshes the totals, so a new day shows up.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<Ledger>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<ShellNav>();
    final staffLabel = context.select<ShopConfig, String>(
      (config) => config.settings.staffLabel,
    );
    final onStaffPage =
        nav.tab == ShellNav.staffTab && nav.staffDetailId != null;
    return PopScope(
      // The phone's back button leaves a staff page before leaving the app.
      canPop: !onStaffPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.closeStaff();
      },
      child: AppScaffold(
        body: IndexedStack(
          index: nav.tab,
          children: const [
            TodayScreen(),
            StaffTab(),
            ExpensesScreen(),
            ReportsScreen(),
            SettingsScreen(),
          ],
        ),
        bottomBar: AppTabBar(
          index: nav.tab,
          staffLabel: staffLabel,
          onChanged: nav.selectTab,
        ),
      ),
    );
  }
}

/// Bottom tab bar. Figma component 1:188.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.index,
    required this.staffLabel,
    required this.onChanged,
  });

  final int index;
  final String staffLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tabs = [
      (LucideIcons.house, S.today),
      (LucideIcons.users, S.staffPlural(staffLabel)),
      (LucideIcons.creditCard, S.expenses),
      (LucideIcons.chartNoAxesColumn, S.reports),
      (LucideIcons.slidersHorizontal, S.settings),
    ];
    return Container(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        border: Border(top: BorderSide(color: colors.separator)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 67,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: Pressable(
                    onTap: () => onChanged(i),
                    builder: (context, pressed) {
                      final active = i == index;
                      return Opacity(
                        opacity: pressed ? 0.5 : 1,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                tabs[i].$1,
                                size: 24,
                                color: active
                                    ? colors.accent
                                    : colors.tabInactive,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tabs[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption.copyWith(
                                  color: active
                                      ? colors.accent
                                      : colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
