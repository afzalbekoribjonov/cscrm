import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'item_measurement_form.dart' show fmtSom;

/// To'liq olinmagan summa nima deb yozilishi.
enum ShortfallKind {
  /// Mijoz keyin to'laydi - buyurtma "Qarzdorlar" ro'yxatiga tushadi.
  debt,

  /// Kechirildi - hech qachon olinmaydi.
  discount,
}

class PaymentResult {
  const PaymentResult({
    required this.method,
    required this.amount,
    required this.shortfallIsDiscount,
  });

  final String method;

  /// Mijozdan olingan summa.
  final double amount;

  /// Yetmagan qismni kechirishmi (`true`) yoki qarz deb yozishmi (`false`).
  ///
  /// Summaning O'ZI bu yerda hisoblanmaydi - uni server, o'zidagi joriy
  /// narxdan kelib chiqib belgilaydi. Sabab: oyna ochiq turganda sexdagi
  /// xodim buyurtmaga yangi xizmat qo'shishi mumkin, va oynadagi eski
  /// narxdan hisoblansa farq yo'qolib ketardi.
  final bool shortfallIsDiscount;
}

/// Yetgazma bo'limida "Yetgazildi" bosilganda ochiladigan to'lov oynasi.
///
/// Kam summa kiritilsa farq avtomatik "skidka" deb yozilmaydi - dastavchik
/// uni aniq tanlaydi: **Qarz** (mijoz keyin to'laydi) yoki **Skidka**
/// (kechirildi). Skidka tanlash faqat tegishli vakolat bo'lganda ochiq.
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.orderTotal,
    required this.allowDiscount,
  });

  /// Buyurtmaning umumiy narxi. 0 bo'lsa (xizmatlar hali o'lchanmagan)
  /// farqni hisoblashning ma'nosi yo'q - summa erkin kiritiladi.
  final double orderTotal;

  /// "Skidka berish" vakolati. Yo'q bo'lsa farq faqat qarz bo'la oladi.
  final bool allowDiscount;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  String _method = 'Naqd pul';
  final _amountCtrl = TextEditingController();
  ShortfallKind _shortfallKind = ShortfallKind.debt;
  String? _error;

  bool get _knownTotal => widget.orderTotal > 0;

  double get _entered =>
      double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;

  /// To'lanmagan qism. Ortiqcha to'lansa 0 bo'ladi.
  double get _shortfall {
    if (!_knownTotal) return 0;
    final diff = widget.orderTotal - _entered;
    return diff > 0 ? diff : 0;
  }

  @override
  void initState() {
    super.initState();
    // Odatda to'liq summa olinadi - shu sabab maydon oldindan to'ldiriladi
    // va dastavchik faqat kam olgan holatda o'zgartiradi.
    if (_knownTotal) {
      _amountCtrl.text = widget.orderTotal.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = _entered;
    if (amount <= 0) {
      setState(() => _error = 'Summani to\'g\'ri kiriting');
      return;
    }
    if (_knownTotal && amount > widget.orderTotal) {
      setState(() => _error = 'Summa buyurtma narxidan ko\'p bo\'lmasin');
      return;
    }
    // Vakolat SHU YERDA ham qayta tekshiriladi. Ilgari faqat ko'rinish
    // darajasida ("skidka" tugmasi ko'rsatilmasligi bilan) himoyalangan
    // edi - bu yetarli emas.
    final isDiscount =
        widget.allowDiscount && _shortfallKind == ShortfallKind.discount;

    Navigator.of(context).pop(PaymentResult(
      method: _method,
      amount: amount,
      shortfallIsDiscount: isDiscount,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortfall = _shortfall;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('To\'lov', style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Yopish',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            if (_knownTotal) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Buyurtma narxi', style: theme.textTheme.bodyMedium),
                  Text(
                    fmtSom(widget.orderTotal),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Naqd pul',
                  label: Text('Naqd pul'),
                  icon: Icon(Icons.payments_outlined),
                ),
                ButtonSegment(
                  value: 'Karta',
                  label: Text('Karta'),
                  icon: Icon(Icons.credit_card_rounded),
                ),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                labelText: 'Qabul qilingan summa',
                suffixText: 'so\'m',
              ),
            ),
            if (shortfall > 0) ...[
              const SizedBox(height: 16),
              _ShortfallSection(
                shortfall: shortfall,
                kind: _shortfallKind,
                allowDiscount: widget.allowDiscount,
                onChanged: (k) => setState(() => _shortfallKind = k),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: _submit, child: const Text('Topshirildi')),
          ],
        ),
      ),
    );
  }
}

/// Kam olingan summa uchun "Qarz / Skidka" tanlovi.
class _ShortfallSection extends StatelessWidget {
  const _ShortfallSection({
    required this.shortfall,
    required this.kind,
    required this.allowDiscount,
    required this.onChanged,
  });

  final double shortfall;
  final ShortfallKind kind;
  final bool allowDiscount;
  final ValueChanged<ShortfallKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('To\'lanmagan farq', style: theme.textTheme.bodyMedium),
              Text(
                fmtSom(shortfall),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _KindOption(
            selected: kind == ShortfallKind.debt,
            icon: Icons.schedule_rounded,
            color: AppColors.danger,
            title: 'Qarz',
            subtitle: 'Mijoz keyin to\'laydi, qarzdorlarga tushadi',
            onTap: () => onChanged(ShortfallKind.debt),
          ),
          const SizedBox(height: 8),
          _KindOption(
            selected: kind == ShortfallKind.discount,
            icon: Icons.percent_rounded,
            color: AppColors.success,
            title: 'Skidka',
            subtitle: allowDiscount
                ? 'Kechiriladi, boshqa olinmaydi'
                : 'Bu vakolat sizga berilmagan',
            enabled: allowDiscount,
            onTap: () => onChanged(ShortfallKind.discount),
          ),
        ],
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = selected && enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: context.colorSurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: active ? color : context.colorBorder,
              width: active ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                active
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 19,
                color: active ? color : context.colorTextSecondary,
              ),
              const SizedBox(width: 10),
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
