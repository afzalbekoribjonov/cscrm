import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/payroll.dart';
import '../../services/payroll_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/money.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/stream_error_view.dart';

/// Maosh ma'lumoti o'qilmadi. Baza qoidalari hali yangilanmagan bo'lsa —
/// texnik xato emas, oddiy tushuntirish.
class PayrollUnavailable extends StatelessWidget {
  const PayrollUnavailable({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e is PayrollException && e.unavailable) {
      return const EmptyState(
        icon: Icons.hourglass_top_rounded,
        tone: StageTone.info,
        title: 'Maosh bo\'limi tez orada ishlaydi',
        message: 'Tizim yangilanmoqda. Birozdan keyin qayta oching.',
      );
    }
    return StreamErrorView(error: e, onRetry: onRetry);
  }
}

/// Kichik izoh qatori (ikonka + matn).
class InfoNote extends StatelessWidget {
  const InfoNote({
    super.key,
    required this.icon,
    required this.text,
    this.tone = StageTone.info,
  });

  final IconData icon;
  final String text;
  final StageTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: tone.soft(context),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone.ink(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tone.ink(context), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pul kiritish maydoni: "1 500" + "so'm".
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: (_) => onChanged?.call(),
      keyboardType: TextInputType.number,
      inputFormatters: const [MoneyInputFormatter(maxDigits: 10)],
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontFeatures: AppFonts.tabular,
      ),
      decoration: InputDecoration(
        isDense: true,
        labelText: t(label),
        hintText: '0',
        suffixText: t('so\'m'),
      ),
    );
  }
}

/// ‹ Noyabr 2026 › — oy tanlagich. Kelajak oyga o'tib bo'lmaydi.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onChanged,
    this.now,
  });

  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();
    final canNext = DateTime(month.year, month.month)
        .isBefore(DateTime(today.year, today.month));
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            tooltip: t('Oldingi oy'),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  UzDates.monthYear(month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                if (month.year == today.year && month.month == today.month)
                  Text('Joriy oy', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: t('Keyingi oy'),
            onPressed: canNext
                ? () => onChanged(DateTime(month.year, month.month + 1))
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Maosh turi belgisi.
class SalaryTypePill extends StatelessWidget {
  const SalaryTypePill({super.key, required this.pay});

  final StaffPay? pay;

  @override
  Widget build(BuildContext context) {
    final p = pay;
    if (p == null) {
      return const TonePill(
          label: 'Sozlanmagan', tone: StageTone.warning, dense: true);
    }
    final tone = switch (p.type) {
      SalaryType.piece => StageTone.washing,
      SalaryType.fixed => StageTone.packaging,
      SalaryType.mixed => StageTone.brand,
    };
    return TonePill(label: p.type.label, tone: tone, dense: true);
  }
}

/// Hisob qatori: chapda nom (va izoh), o'ngda summa. Summa hech qachon
/// kesilmaydi — nom ikki qatorga tushadi.
class AmountLine extends StatelessWidget {
  const AmountLine({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
    this.negative = false,
    this.strong = false,
    this.color,
  });

  final String label;
  final String? caption;
  final double amount;

  /// Ayiriladigan summa ("−9 000 so'm").
  final bool negative;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = negative && amount > 0
        ? '−${formatSom(amount)}'
        : formatSom(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: strong
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium,
                ),
                if (caption != null && caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(caption!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: (strong
                    ? theme.textTheme.titleMedium
                    : theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700))
                ?.copyWith(
              color: color ??
                  (negative && amount > 0
                      ? StageTone.danger.ink(context)
                      : null),
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ],
      ),
    );
  }
}
