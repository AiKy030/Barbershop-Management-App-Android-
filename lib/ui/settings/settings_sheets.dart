import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../../domain/money.dart';
import '../state/shop_config.dart';
import '../strings.dart';
import '../widgets/basics.dart';
import '../widgets/sheet.dart';

final _digitsOnly = [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(3),
];

final _pesoInput = [
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
  LengthLimitingTextInputFormatter(10),
];

const _gap = SizedBox(height: 12);
const _gapBeforeButton = SizedBox(height: 20);

class ShopNameSheet extends StatefulWidget {
  const ShopNameSheet({super.key});

  @override
  State<ShopNameSheet> createState() => _ShopNameSheetState();
}

class _ShopNameSheetState extends State<ShopNameSheet> {
  late final _name = TextEditingController(
    text: context.read<ShopConfig>().settings.shopName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return AppSheet(
      title: S.shopName,
      children: [
        SheetField(
          label: S.name,
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        _gapBeforeButton,
        PrimaryButton(
          label: S.save,
          onTap: name.isEmpty
              ? null
              : () async {
                  await context.read<ShopConfig>().setShopName(name);
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

class DefaultSplitSheet extends StatefulWidget {
  const DefaultSplitSheet({super.key});

  @override
  State<DefaultSplitSheet> createState() => _DefaultSplitSheetState();
}

class _DefaultSplitSheetState extends State<DefaultSplitSheet> {
  late final _percent = TextEditingController(
    text: '${context.read<ShopConfig>().settings.defaultStaffPercent}',
  );

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffLabel = context.read<ShopConfig>().settings.staffLabel;
    final percent = parsePercent(_percent.text);
    return AppSheet(
      title: S.defaultSplit,
      children: [
        SheetField(
          label: S.staffGets(staffLabel),
          controller: _percent,
          suffix: '%',
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          onChanged: (_) => setState(() {}),
        ),
        _gap,
        SheetValue(
          label: S.shopGets,
          value: percent == null ? '' : S.percent(100 - percent),
        ),
        _gap,
        const SheetNote(S.splitHelp),
        _gapBeforeButton,
        PrimaryButton(
          label: S.save,
          onTap: percent == null
              ? null
              : () async {
                  await context.read<ShopConfig>().setDefaultStaffPercent(
                    percent,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
      ],
    );
  }
}

class AppearanceSheet extends StatelessWidget {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ShopConfig>();
    return AppSheet(
      title: S.appearance,
      children: [
        SegmentedControl<AppearanceMode>(
          options: const {
            AppearanceMode.system: S.appearanceSystem,
            AppearanceMode.light: S.appearanceLight,
            AppearanceMode.dark: S.appearanceDark,
          },
          selected: config.settings.appearance,
          onChanged: config.setAppearance,
        ),
        _gapBeforeButton,
        PrimaryButton(label: S.done, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// Add a service, or edit one when [service] is given.
class ServiceSheet extends StatefulWidget {
  const ServiceSheet({super.key, this.service});

  final Service? service;

  @override
  State<ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<ServiceSheet> {
  late final _name = TextEditingController(text: widget.service?.name);
  late final _price = TextEditingController(
    text: widget.service == null ? '' : pesosInputText(widget.service!.price),
  );

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final config = context.read<ShopConfig>();
    final name = _name.text.trim();
    final price = parsePesos(_price.text);
    final valid = name.isNotEmpty && price != null && price > 0;
    return AppSheet(
      title: service == null ? S.addService : S.editService,
      children: [
        SheetField(
          label: S.name,
          controller: _name,
          hint: S.serviceNameHint,
          autofocus: service == null,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        _gap,
        SheetField(
          label: S.priceLabel(pesoSign),
          controller: _price,
          hint: '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: _pesoInput,
          onChanged: (_) => setState(() {}),
        ),
        _gapBeforeButton,
        PrimaryButton(
          label: S.save,
          onTap: !valid
              ? null
              : () async {
                  await config.saveService(
                    id: service?.id,
                    name: name,
                    price: price,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
        if (service != null) ...[
          _gap,
          SecondaryButton(
            label: service.active ? S.archive : S.restore,
            onTap: () async {
              await config.setServiceActive(service.id, !service.active);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

/// Add a staff member, or edit one when [staff] is given.
class StaffSheet extends StatefulWidget {
  const StaffSheet({super.key, this.staff});

  final Staff? staff;

  @override
  State<StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends State<StaffSheet> {
  late final _name = TextEditingController(text: widget.staff?.name);
  late final _percent = TextEditingController(
    text: widget.staff?.percentOverride?.toString(),
  );
  late StaffType _type = widget.staff?.type ?? StaffType.regular;

  @override
  void dispose() {
    _name.dispose();
    _percent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final config = context.read<ShopConfig>();
    final label = config.settings.staffLabel;
    final name = _name.text.trim();
    final percentText = _percent.text.trim();
    final percent = parsePercent(percentText);
    final valid = name.isNotEmpty && (percentText.isEmpty || percent != null);
    return AppSheet(
      title: staff == null ? S.addStaff(label) : S.editStaff(label),
      children: [
        SheetField(
          label: S.name,
          controller: _name,
          hint: S.staffNameHint,
          autofocus: staff == null,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        _gap,
        SegmentedControl<StaffType>(
          options: const {
            StaffType.regular: S.regular,
            StaffType.reliever: S.reliever,
          },
          selected: _type,
          onChanged: (type) => setState(() => _type = type),
        ),
        _gap,
        SheetField(
          label: S.ownPercent,
          controller: _percent,
          hint: S.defaultPercentHint(config.settings.defaultStaffPercent),
          suffix: percentText.isEmpty ? null : '%',
          keyboardType: TextInputType.number,
          inputFormatters: _digitsOnly,
          onChanged: (_) => setState(() {}),
        ),
        _gap,
        const SheetNote(S.ownPercentHelp),
        _gapBeforeButton,
        PrimaryButton(
          label: S.save,
          onTap: !valid
              ? null
              : () async {
                  await config.saveStaff(
                    id: staff?.id,
                    name: name,
                    type: _type,
                    percentOverride: percent,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
        if (staff != null) ...[
          _gap,
          SecondaryButton(
            label: staff.active ? S.markInactive : S.markActive,
            onTap: () async {
              await config.setStaffActive(staff.id, !staff.active);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}

/// Add an expense category, or edit one when [category] is given.
class CategorySheet extends StatefulWidget {
  const CategorySheet({super.key, this.category});

  final ExpenseCategory? category;

  @override
  State<CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<CategorySheet> {
  late final _name = TextEditingController(text: widget.category?.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final config = context.read<ShopConfig>();
    final name = _name.text.trim();
    return AppSheet(
      title: category == null ? S.addCategory : S.editCategory,
      children: [
        SheetField(
          label: S.name,
          controller: _name,
          hint: S.categoryNameHint,
          autofocus: category == null,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
        ),
        _gapBeforeButton,
        PrimaryButton(
          label: S.save,
          onTap: name.isEmpty
              ? null
              : () async {
                  await config.saveCategory(id: category?.id, name: name);
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
        if (category != null) ...[
          _gap,
          SecondaryButton(
            label: category.active ? S.archive : S.restore,
            onTap: () async {
              await config.setCategoryActive(category.id, !category.active);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }
}
