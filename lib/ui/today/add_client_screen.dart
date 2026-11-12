import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_database.dart' show newId;
import '../../domain/models.dart';
import '../../domain/money.dart';
import '../../domain/sale.dart';
import '../../domain/split.dart';
import '../state/shop_config.dart';
import '../state/ledger.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import '../widgets/day_guard.dart';
import '../widgets/sheet.dart';
import 'add_client_sheets.dart';

/// Full-screen Add Client. Three taps: staff, service, Save.
/// Figma: 3:118 (light), 6:1508 (dark). Pops with the saved [Sale].
class AddClientScreen extends StatefulWidget {
  const AddClientScreen({super.key, this.demo = false});

  /// The tutorial shows this screen with the first staff member and service
  /// already chosen.
  final bool demo;

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  Staff? _staff;
  Service? _service;

  /// Set when "Other" is chosen instead of a listed service.
  String? _otherName;

  /// Centavos. Starts as the service price; can be changed for this sale.
  int? _price;
  int _tip = 0;
  bool _tipHeld = false;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _saving = false;

  /// Null means today. Set to put a forgotten client on an earlier day.
  DateTime? _date;

  Future<void> _pickDate() async {
    final picked = await pickEntryDate(context, _date);
    if (picked != null) setState(() => _date = picked.date);
  }

  @override
  void initState() {
    super.initState();
    if (!widget.demo) return;
    final config = context.read<ShopConfig>();
    _staff = config.staff.where((s) => s.active).firstOrNull;
    _service = config.services.where((s) => s.active).firstOrNull;
    _price = _service?.price;
  }

  bool get _hasService => _service != null || _otherName != null;

  void _pickService(Service service) => setState(() {
    _service = service;
    _otherName = null;
    _price = service.price;
  });

  Future<void> _pickOther() async {
    final result = await showAppSheet<(String, int)>(
      context,
      (_) => OtherServiceSheet(
        initialName: _otherName,
        initialPrice: _otherName == null ? null : _price,
      ),
    );
    if (result == null) return;
    setState(() {
      _service = null;
      _otherName = result.$1;
      _price = result.$2;
    });
  }

  Future<void> _editPrice() async {
    final price = await showAppSheet<int>(
      context,
      (_) => AmountSheet(title: S.price, initial: _price),
    );
    if (price != null) setState(() => _price = price);
  }

  Future<void> _editTip() async {
    final result = await showAppSheet<(int, bool)>(
      context,
      (_) => TipSheet(
        initial: _tip,
        // Until a tip is typed, assume it is paid the same way as the sale.
        initialHeld: _tip > 0 ? _tipHeld : _payment == PaymentMethod.gcash,
      ),
    );
    if (result == null) return;
    setState(() {
      _tip = result.$1;
      _tipHeld = result.$2;
    });
  }

  Future<void> _save(int staffPercent) async {
    if (_saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final sale = Sale.record(
      id: newId(),
      now: now,
      forDate: _date,
      staffId: _staff!.id,
      staffPercent: staffPercent,
      serviceId: _service?.id,
      serviceName: _service?.name ?? _otherName!,
      price: _price!,
      tip: _tip,
      tipHeld: _tipHeld,
      paymentMethod: _payment,
    );
    final ledger = context.read<Ledger>();
    final saved = await saveIntoDay(
      context,
      _date ?? now,
      () => ledger.addSale(sale),
    );
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop(sale);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final config = context.watch<ShopConfig>();
    final label = config.settings.staffLabel;
    final defaultPercent = config.settings.defaultStaffPercent;
    final staff = config.staff.where((s) => s.active).toList();
    final services = config.services.where((s) => s.active).toList();

    final price = _price;
    final percent = _staff?.effectivePercent(defaultPercent);
    final ready = _staff != null && _hasService && price != null && price > 0;
    final split = ready
        ? splitSale(price: price, staffPercent: percent!)
        : null;

    return AppScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _Nav(onCancel: () => Navigator.of(context).pop()),
                  const SizedBox(height: 8),
                  TutorialAnchor(
                    id: 'clientGrids',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Label(label),
                        if (staff.isEmpty)
                          EmptyCard(message: S.noStaffToday(label))
                        else
                          TileGrid(
                            tiles: [
                              for (final s in staff)
                                OptionTile(
                                  title: s.name,
                                  subtitle: s.type == StaffType.reliever
                                      ? S.relieverTile(
                                          s.effectivePercent(defaultPercent),
                                        )
                                      : S.percent(
                                          s.effectivePercent(defaultPercent),
                                        ),
                                  selected: _staff?.id == s.id,
                                  onTap: () => setState(() => _staff = s),
                                ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        const _Label(S.service),
                        TileGrid(
                          tiles: [
                            for (final s in services)
                              OptionTile(
                                title: s.name,
                                subtitle: formatPesos(s.price),
                                selected: _service?.id == s.id,
                                onTap: () => _pickService(s),
                              ),
                            OptionTile(
                              title: _otherName ?? S.other,
                              subtitle: _otherName == null
                                  ? S.customPrice
                                  : S.other,
                              selected: _otherName != null,
                              onTap: _pickOther,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Section(
                    label: S.details,
                    children: [
                      AppRow(
                        title: S.price,
                        value: price == null ? '' : formatPesos(price),
                        valueColor: colors.textPrimary,
                        onTap: _hasService ? _editPrice : null,
                      ),
                      AppRow(
                        title: S.tip,
                        value: _tip == 0
                            ? formatPesos(0)
                            : '${formatPesos(_tip)} ${_tipHeld ? S.gcash : S.cash}',
                        valueColor: _tip == 0 ? null : colors.textPrimary,
                        onTap: _editTip,
                      ),
                      AppRow(
                        title: S.date,
                        value: entryDateLabel(_date),
                        valueColor: _date == null ? null : colors.textPrimary,
                        isLast: true,
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _Label(S.payment),
                  SegmentedControl<PaymentMethod>(
                    options: const {
                      PaymentMethod.cash: S.cash,
                      PaymentMethod.gcash: S.gcash,
                    },
                    selected: _payment,
                    onChanged: (method) => setState(() => _payment = method),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    split == null
                        ? S.pickFirst(label)
                        : S.splitPreview(
                            label,
                            formatPesos(split.staffShare),
                            formatPesos(split.shopShare),
                          ),
                    textAlign: TextAlign.center,
                    style: AppText.subhead.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: !ready
                        ? S.save
                        : _date == null
                        ? S.saveAmount(formatPesos(price))
                        : S.saveAmountFor(
                            formatPesos(price),
                            S.monthDay(_date!),
                          ),
                    onTap: ready && !_saving ? () => _save(percent!) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Pressable(
                onTap: onCancel,
                builder: (context, pressed) => Opacity(
                  opacity: pressed ? 0.5 : 1,
                  child: Container(
                    height: 48,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 4, right: 16),
                    child: Text(
                      S.cancel,
                      style: AppText.body.copyWith(color: colors.accent),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            S.addClient,
            style: AppText.headline.copyWith(color: colors.textPrimary),
          ),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppText.caption.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}
