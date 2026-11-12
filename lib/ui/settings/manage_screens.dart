import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../widgets/basics.dart';
import '../widgets/sheet.dart';
import 'settings_sheets.dart';

/// Shared layout for the three "manage" lists: back link, title, a card of
/// active rows, a card of archived rows, and an Add button at the bottom.
class _ManageScreen extends StatelessWidget {
  const _ManageScreen({
    required this.title,
    required this.emptyMessage,
    required this.activeRows,
    required this.archivedLabel,
    required this.archivedRows,
    required this.addLabel,
    required this.onAdd,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> activeRows;
  final String archivedLabel;
  final List<Widget> archivedRows;
  final String addLabel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  ScreenHeader(title: title, backLabel: S.settings),
                  const SizedBox(height: 16),
                  if (activeRows.isEmpty)
                    EmptyCard(message: emptyMessage)
                  else
                    Section(children: activeRows),
                  if (archivedRows.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Section(label: archivedLabel, children: archivedRows),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: PrimaryButton(label: addLabel, onTap: onAdd),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds rows for [items], marking the last one so it has no separator.
List<Widget> _rows<T>(List<T> items, Widget Function(T item, bool isLast) row) {
  return [
    for (var i = 0; i < items.length; i++) row(items[i], i == items.length - 1),
  ];
}

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.watch<ShopConfig>().services;

    Widget row(Service service, bool isLast) => AppRow(
      title: service.name,
      value: formatPesos(service.price),
      isLast: isLast,
      onTap: () =>
          showAppSheet<void>(context, (_) => ServiceSheet(service: service)),
    );

    return _ManageScreen(
      title: S.services,
      emptyMessage: S.noServices,
      activeRows: _rows(services.where((s) => s.active).toList(), row),
      archivedLabel: S.archived,
      archivedRows: _rows(services.where((s) => !s.active).toList(), row),
      addLabel: S.addService,
      onAdd: () => showAppSheet<void>(context, (_) => const ServiceSheet()),
    );
  }
}

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ShopConfig>();
    final label = config.settings.staffLabel;
    final defaultPercent = config.settings.defaultStaffPercent;

    Widget row(Staff staff, bool isLast) {
      final type = staff.type == StaffType.regular ? S.regular : S.reliever;
      final percent = S.percent(staff.effectivePercent(defaultPercent));
      return AppRow(
        avatarInitial: staff.name.characters.first.toUpperCase(),
        title: staff.name,
        subtitle: '$type · $percent',
        isLast: isLast,
        onTap: () =>
            showAppSheet<void>(context, (_) => StaffSheet(staff: staff)),
      );
    }

    return _ManageScreen(
      title: S.staffPlural(label),
      emptyMessage: S.noStaff(label),
      activeRows: _rows(config.staff.where((s) => s.active).toList(), row),
      archivedLabel: S.inactive,
      archivedRows: _rows(config.staff.where((s) => !s.active).toList(), row),
      addLabel: S.addStaff(label),
      onAdd: () => showAppSheet<void>(context, (_) => const StaffSheet()),
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ShopConfig>().categories;

    Widget row(ExpenseCategory category, bool isLast) => AppRow(
      title: category.name,
      isLast: isLast,
      onTap: () =>
          showAppSheet<void>(context, (_) => CategorySheet(category: category)),
    );

    return _ManageScreen(
      title: S.categories,
      emptyMessage: S.noCategories,
      activeRows: _rows(categories.where((c) => c.active).toList(), row),
      archivedLabel: S.archived,
      archivedRows: _rows(categories.where((c) => !c.active).toList(), row),
      addLabel: S.addCategory,
      onAdd: () => showAppSheet<void>(context, (_) => const CategorySheet()),
    );
  }
}
