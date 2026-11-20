import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../utils/money.dart';
import '../utils/uz_dates.dart';
import 'surfaces.dart';

/// Kunlik summalar kalendari (chiqimlar, qarzlar): har bir kun katagida
/// o'sha kungi summa qisqa ko'rinishda ("180 ming", "1,5 mln"), rangi
/// summaga qarab to'qroq. Kun bosilsa — tanlanadi (yana bosilsa —
/// bekor bo'ladi).
class MoneyCalendar extends StatelessWidget {
  const MoneyCalendar({
    super.key,
    required this.month,
    required this.totals,
    required this.tone,
    required this.onMonthChanged,
    required this.onDaySelected,
    this.selected,
    this.counts = const {},
    this.now,
    this.canGoBack = true,
  });

  /// Ko'rsatilayotgan oy (1-kun).
  final DateTime month;

  /// Oy kuni (1..31) → summa.
  final Map<int, double> totals;

  /// Oy kuni → yozuvlar soni (izoh uchun).
  final Map<int, int> counts;
  final StageTone tone;
  final DateTime? selected;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime?> onDaySelected;
  final DateTime? now;
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = startOfDay(now ?? DateTime.now());
    final canNext = DateTime(month.year, month.month)
        .isBefore(DateTime(today.year, today.month));
    final total = totals.values.fold<double>(0, (s, v) => s + v);
    final max = totals.values.fold<double>(0, (m, v) => v > m ? v : m);

    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final rows = ((leading + daysInMonth) / 7).ceil();

    return AppCard(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: t('Oldingi oy'),
                onPressed: canGoBack
                    ? () => onMonthChanged(DateTime(month.year, month.month - 1))
                    : null,
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
                    Text(
                      total > 0 ? 'Jami: ${formatSom(total)}' : 'Yozuv yo\'q',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: total > 0 ? tone.ink(context) : null,
                        fontWeight: total > 0 ? FontWeight.w700 : null,
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: t('Keyingi oy'),
                onPressed: canNext
                    ? () => onMonthChanged(DateTime(month.year, month.month + 1))
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      UzDates.weekdaysShort[i],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: i >= 5
                            ? StageTone.danger.ink(context)
                            : context.colorTextSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _cell(
                      context,
                      r * 7 + c - leading + 1,
                      daysInMonth,
                      today,
                      max,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    int day,
    int daysInMonth,
    DateTime today,
    double max,
  ) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 58);
    final date = DateTime(month.year, month.month, day);
    final amount = totals[day] ?? 0;
    final future = date.isAfter(today);
    final isSelected = selected != null && isSameDay(selected!, date);
    final isToday = isSameDay(date, today);
    final theme = Theme.of(context);
    final strength = max <= 0 ? 0.0 : (amount / max).clamp(0.0, 1.0);

    final Color bg;
    if (isSelected) {
      bg = tone.fill;
    } else if (amount > 0) {
      bg = tone.fill.withValues(alpha: 0.10 + 0.30 * strength);
    } else {
      bg = Colors.transparent;
    }
    final fg = isSelected
        ? Colors.white
        : future
            ? context.colorTextTertiary.withValues(alpha: 0.5)
            : context.colorTextPrimary;
    final amountColor = isSelected ? Colors.white : tone.ink(context);
    final (value, unit) = _compact(amount);

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isToday && !isSelected
              ? BorderSide(color: tone.fill, width: 1.4)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: future
              ? null
              : () => onDaySelected(isSelected ? null : date),
          child: SizedBox(
            height: 54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontWeight:
                        isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
                if (amount > 0) ...[
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: amountColor,
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                  ),
                  if (unit.isNotEmpty)
                    Text(
                      unit,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 8.5,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: amountColor.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// (son, birlik): 180 000 → ("180", "ming"), 1 500 000 → ("1,5", "mln").
  static (String, String) _compact(double v) {
    if (v >= 1000000) {
      final m = v / 1000000;
      final s = m >= 10 ? '${m.round()}' : '${(m * 10).round() / 10}';
      return (s.replaceAll('.', ',').replaceAll(',0', ''), 'mln');
    }
    if (v >= 1000) return ('${(v / 1000).round()}', 'ming');
    return ('${v.round()}', '');
  }
}

/// Oylar tasmasi: har bir oyning jami summasi — bosilsa o'sha oy
/// kalendarda ochiladi.
class MonthTotalsStrip extends StatelessWidget {
  const MonthTotalsStrip({
    super.key,
    required this.months,
    required this.selected,
    required this.tone,
    required this.onSelected,
  });

  /// Oy (1-kun) → jami. Yangisi birinchi bo'lib chiziladi.
  final Map<DateTime, double> months;
  final DateTime selected;
  final StageTone tone;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keys = months.keys.toList()..sort((a, b) => b.compareTo(a));
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = keys[i];
          final on = m.year == selected.year && m.month == selected.month;
          final total = months[m] ?? 0;
          return Material(
            color: on ? tone.fill : context.colorSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              side: BorderSide(color: on ? tone.fill : context.colorBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () => onSelected(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.year == DateTime.now().year
                          ? UzDates.monthName(m.month)
                          : '${UzDates.monthsShort[m.month - 1]} ${m.year}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: on ? Colors.white70 : context.colorTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      formatSom(total),
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: on ? Colors.white : tone.ink(context),
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
