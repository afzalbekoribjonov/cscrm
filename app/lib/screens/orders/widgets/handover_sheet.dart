import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../../l10n/text.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../ui/sheets.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/delivery_stats.dart';
import '../../../utils/money.dart';
import '../../../widgets/payment_dialog.dart';
import '../../../widgets/stage_visuals.dart';

/// Bo'lib topshirish natijasi.
class HandoverResult {
  const HandoverResult({
    required this.items,
    required this.amount,
    required this.method,
  });

  final List<OrderItem> items;

  /// Shu topshirishda olingan pul (0 — keyin to'laydi).
  final double amount;
  final String method;
}

/// BO'LIB TOPSHIRISH oynasi: tayyor xizmatlardan qaysilari hozir
/// berilishini tanlash va (ixtiyoriy) ular uchun to'lov olish.
///
/// Hali sexda turgan xizmatlar ro'yxatda ko'rinadi, lekin tanlab
/// bo'lmaydi — ular tayyor bo'lgach odatdagidek topshiriladi.
class HandoverSheet extends StatefulWidget {
  const HandoverSheet({super.key, required this.order});

  final Order order;

  @override
  State<HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends State<HandoverSheet> {
  late final List<OrderItem> _ready = widget.order.readyToHandItems;
  late final List<OrderItem> _waiting = widget.order.items
      .where((i) => !i.isHanded && !i.isReadyToHand)
      .toList();
  late final Set<String> _selected = {for (final i in _ready) i.key};

  final _amountCtrl = TextEditingController();
  String _method = cashPaymentLabel;
  var _payNow = true;
  var _amountEdited = false;

  double get _selectedSum => _ready
      .where((i) => _selected.contains(i.key))
      .fold<double>(0, (s, i) => s + i.price);

  /// Buyurtma bo'yicha hali to'lanmagan qism — undan ortiq olinmaydi.
  double get _open => widget.order.remainingDue;

  double get _suggested {
    final s = _selectedSum;
    return s > _open ? _open : s;
  }

  @override
  void initState() {
    super.initState();
    _syncAmount();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _syncAmount() {
    if (_amountEdited) return;
    final s = _suggested;
    _amountCtrl.text = s > 0 ? formatMoney(s) : '';
  }

  void _toggle(OrderItem item) => setState(() {
        if (!_selected.remove(item.key)) _selected.add(item.key);
        _syncAmount();
      });

  void _submit() {
    final items = _ready.where((i) => _selected.contains(i.key)).toList();
    if (items.isEmpty) return;
    final amount = _payNow ? parseMoney(_amountCtrl.text) : 0.0;
    Navigator.of(context).pop(HandoverResult(
      items: items,
      amount: amount > _open ? _open : amount,
      method: _method,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = _selected.length;

    return SheetFrame(
      title: 'Bo\'lib topshirish',
      subtitle: 'Tayyor xizmatlarni hozir berish, qolganini keyin',
      actions: FilledButton.icon(
        onPressed: count == 0 ? null : _submit,
        icon: const Icon(Icons.call_split_rounded),
        label: Text(count == 0 ? 'Xizmatni tanlang' : '$count ta xizmatni topshirish'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tayyor xizmatlar', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _ready.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: context.colorBorder),
                  CheckboxListTile(
                    value: _selected.contains(_ready[i].key),
                    onChanged: (_) => _toggle(_ready[i]),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_ready[i].productName),
                    subtitle: Text(
                      [
                        if (_ready[i].hajm.isNotEmpty) _ready[i].hajm,
                        if (_ready[i].price > 0) formatSom(_ready[i].price),
                      ].join(' · '),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_waiting.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Hali sexda (keyin topshiriladi)',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in _waiting)
                  TonePill(
                    label: '${item.productName} · '
                        '${ItemStage.of(item).visual.label.toLowerCase()}',
                    tone: ItemStage.of(item).visual.tone,
                    icon: ItemStage.of(item).visual.icon,
                    dense: true,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _payNow,
            onChanged: (v) => setState(() => _payNow = v),
            title: const Text('To\'lov olindi'),
            subtitle: Text(_payNow
                ? 'Topshirilgan xizmatlar uchun pul hozir olinadi'
                : 'Mijoz hammasini oxirida to\'laydi'),
          ),
          if (_payNow) ...[
            const SizedBox(height: 8),
            PaymentMethodPicker(
              value: _method,
              onChanged: (m) => setState(() => _method = m),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                const MoneyInputFormatter(),
              ],
              onChanged: (_) => _amountEdited = true,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontFeatures: AppFonts.tabular),
              decoration: InputDecoration(
                labelText: t('Olingan summa'),
                suffixText: t('so\'m'),
                helperText: t('Buyurtma bo\'yicha to\'lanmagan: ${formatSom(_open)}'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Qolgan xizmatlar tayyor bo\'lgach buyurtma "Tayyor" bo\'limiga '
            'o\'tadi va odatdagidek topshiriladi.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
