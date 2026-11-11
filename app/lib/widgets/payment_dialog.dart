import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../ui/sheets.dart';
import '../ui/surfaces.dart';
import '../utils/delivery_stats.dart';
import '../utils/money.dart';

/// Topshirish natijasi.
class PaymentResult {
  const PaymentResult({
    required this.method,
    required this.amount,
    required this.shortfallIsDiscount,
  });

  /// "Naqd pul" yoki "Karta" — hisobotlar shu matnga tayanadi.
  final String method;
  final double amount;

  /// To'liq olinmagan qism: `true` — kechirildi (skidka), `false` — qarz.
  final bool shortfallIsDiscount;
}

/// To'lov usuli tanlovi — ilova bo'ylab bir xil.
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: cashPaymentLabel,
          icon: Icon(Icons.payments_outlined),
          label: Text('Naqd pul'),
        ),
        ButtonSegment(
          value: cardPaymentLabel,
          icon: Icon(Icons.credit_card_rounded),
          label: Text('Karta'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Buyurtmani mijozga TOPSHIRISH oynasi.
///
/// Bo'lib topshirishda oldindan olingan pul alohida ko'rsatiladi va
/// mijozdan faqat QOLGAN qism so'raladi. Kam olinsa — farq qarz yoki
/// skidka sifatida yoziladi (qaysi biri ruxsat etilgan bo'lsa).
class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    super.key,
    required this.orderTotal,
    required this.allowDiscount,
    this.prepaid = 0,
    this.allowDebt = true,
  });

  /// Buyurtmaning to'liq narxi.
  final double orderTotal;

  /// Oldindan (bo'lib topshirishda) olingan pul.
  final double prepaid;

  /// "Skidka berish" vakolati.
  final bool allowDiscount;

  /// "Ilova qonuniyatlari": qarzga topshirishga ruxsat.
  final bool allowDebt;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

enum _Shortfall { debt, discount }

class _PaymentDialogState extends State<PaymentDialog> {
  String _method = cashPaymentLabel;
  final _amountCtrl = TextEditingController();
  late _Shortfall _shortfallKind =
      widget.allowDebt ? _Shortfall.debt : _Shortfall.discount;
  String? _error;

  /// Narx ma'lum emas (xizmatlar o'lchanmagan) — summa erkin kiritiladi.
  bool get _knownTotal => widget.orderTotal > 0;

  double get _due {
    final d = widget.orderTotal - widget.prepaid;
    return d > 0 ? d : 0;
  }

  double get _entered => parseMoney(_amountCtrl.text);

  double get _shortfall {
    if (!_knownTotal) return 0;
    final diff = _due - _entered;
    return diff > 0 ? diff : 0;
  }

  bool get _canLeaveShortfall => widget.allowDebt || widget.allowDiscount;

  @override
  void initState() {
    super.initState();
    // Odatda to'liq summa olinadi — maydon oldindan to'ldiriladi.
    if (_knownTotal && _due > 0) _amountCtrl.text = formatMoney(_due);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = _entered;
    if (_knownTotal && amount > _due) {
      setState(() => _error = 'Summa qolgan to\'lovdan ko\'p bo\'lmasin');
      return;
    }
    if (!_knownTotal && amount <= 0) {
      setState(() => _error = 'Olingan summani kiriting');
      return;
    }
    if (_shortfall > 0 && !_canLeaveShortfall) {
      setState(() => _error = 'To\'liq summani oling — qarzga topshirish '
          'qoidalarda o\'chirilgan');
      return;
    }
    // Vakolat SHU YERDA ham qayta tekshiriladi — faqat tugmani
    // yashirish yetarli emas.
    final isDiscount = _shortfall > 0 &&
        (_shortfallKind == _Shortfall.discount || !widget.allowDebt) &&
        widget.allowDiscount;

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

    return SheetFrame(
      title: 'Topshirish',
      subtitle: 'Mijozdan olingan to\'lovni kiriting',
      actions: FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.task_alt_rounded),
        label: const Text('Topshirildi'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_knownTotal)
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              color: context.colorSurfaceMuted,
              borderColor: Colors.transparent,
              child: Column(
                children: [
                  InfoRow(label: 'Buyurtma narxi', value: formatSom(widget.orderTotal)),
                  if (widget.prepaid > 0)
                    InfoRow(
                      label: 'Oldindan to\'langan',
                      value: '− ${formatSom(widget.prepaid)}',
                      valueColor: StageTone.success.ink(context),
                    ),
                  const Divider(height: 12),
                  InfoRow(
                    label: 'Olinishi kerak',
                    value: formatSom(_due),
                    emphasize: true,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          PaymentMethodPicker(
            value: _method,
            onChanged: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              const MoneyInputFormatter(),
            ],
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: AppFonts.tabular,
            ),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: t('Olingan summa'),
              suffixText: t('so\'m'),
              errorText: _error == null ? null : t(_error!),
            ),
          ),
          if (shortfall > 0) ...[
            const SizedBox(height: 14),
            Text(
              '${formatSom(shortfall)} olinmadi. Bu summa:',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_canLeaveShortfall)
              SegmentedButton<_Shortfall>(
                showSelectedIcon: false,
                segments: [
                  if (widget.allowDebt)
                    const ButtonSegment(
                      value: _Shortfall.debt,
                      icon: Icon(Icons.request_quote_outlined),
                      label: Text('Qarzga'),
                    ),
                  if (widget.allowDiscount)
                    const ButtonSegment(
                      value: _Shortfall.discount,
                      icon: Icon(Icons.percent_rounded),
                      label: Text('Skidka'),
                    ),
                ],
                selected: {
                  widget.allowDebt ? _shortfallKind : _Shortfall.discount,
                },
                onSelectionChanged: (s) =>
                    setState(() => _shortfallKind = s.first),
              )
            else
              Text(
                'Qarzga topshirish o\'chirilgan — to\'liq summani oling.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: StageTone.danger.ink(context)),
              ),
            const SizedBox(height: 6),
            Text(
              _shortfallKind == _Shortfall.discount && widget.allowDiscount ||
                      !widget.allowDebt
                  ? 'Skidka — mijozdan boshqa olinmaydi.'
                  : 'Qarz — mijoz keyinroq to\'laydi, "Qarzdorlar"ga tushadi.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
