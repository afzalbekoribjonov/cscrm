import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../utils/uz_dates.dart';
import 'sheets.dart';

/// Tez tanlash tugmasi: "Ertaga", "3 kundan keyin".
class QuickDay {
  const QuickDay(this.label, this.daysFromToday);
  final String label;
  final int daysFromToday;
}

const defaultQuickDays = [
  QuickDay('Bugun', 0),
  QuickDay('Ertaga', 1),
  QuickDay('2 kun', 2),
  QuickDay('3 kun', 3),
  QuickDay('1 hafta', 7),
];

/// O'zbekcha kalendar (pastdan chiqadi).
///
/// Tizimning sana tanlagichi o'rniga: unda qo'lda kiritish rejimi
/// "mm/dd/yyyy" (Amerika) formatini so'raydi va kirill yozuviga
/// moslashmaydi. Bu yerda hammasi ilovaning o'zida: oy va kun nomlari
/// o'zbekcha, tez tanlash tugmalari bor, kun bitta bosish bilan tanlanadi.
Future<DateTime?> showUzDatePicker(
  BuildContext context, {
  required String title,
  DateTime? initial,
  DateTime? first,
  DateTime? last,
  List<QuickDay> quickDays = defaultQuickDays,
  String confirmLabel = 'Tanlash',
}) {
  final today = startOfDay(DateTime.now());
  return showAppSheet<DateTime>(
    context,
    (_) => _UzDatePicker(
      title: title,
      initial: initial == null ? null : startOfDay(initial),
      first: first == null ? DateTime(today.year - 3) : startOfDay(first),
      last: last == null ? DateTime(today.year + 2, 12, 31) : startOfDay(last),
      quickDays: quickDays,
      confirmLabel: confirmLabel,
    ),
  );
}

class _UzDatePicker extends StatefulWidget {
  const _UzDatePicker({
    required this.title,
    required this.initial,
    required this.first,
    required this.last,
    required this.quickDays,
    required this.confirmLabel,
  });

  final String title;
  final DateTime? initial;
  final DateTime first;
  final DateTime last;
  final List<QuickDay> quickDays;
  final String confirmLabel;

  @override
  State<_UzDatePicker> createState() => _UzDatePickerState();
}

class _UzDatePickerState extends State<_UzDatePicker> {
  late DateTime? _selected = widget.initial;
  late DateTime _month = DateTime(
    (widget.initial ?? _clampedToday).year,
    (widget.initial ?? _clampedToday).month,
  );

  DateTime get _clampedToday {
    final today = startOfDay(DateTime.now());
    if (today.isBefore(widget.first)) return widget.first;
    if (today.isAfter(widget.last)) return widget.last;
    return today;
  }

  bool _allowed(DateTime d) =>
      !d.isBefore(widget.first) && !d.isAfter(widget.last);

  bool get _canPrev =>
      DateTime(_month.year, _month.month).isAfter(
          DateTime(widget.first.year, widget.first.month));

  bool get _canNext => DateTime(_month.year, _month.month)
      .isBefore(DateTime(widget.last.year, widget.last.month));

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  void _pick(DateTime d) => setState(() {
        _selected = d;
        _month = DateTime(d.year, d.month);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = startOfDay(DateTime.now());
    final quick = widget.quickDays
        .map((q) => (q, today.add(Duration(days: q.daysFromToday))))
        .where((e) => _allowed(e.$2))
        .toList();

    return SheetFrame(
      title: widget.title,
      subtitle: _selected == null
          ? 'Kunni tanlang'
          : '${UzDates.weekdays[_selected!.weekday - 1]}, '
              '${UzDates.date(_selected!)}',
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Bekor qilish'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _selected == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
              child: Text(widget.confirmLabel),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quick.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (q, day) in quick)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(q.label),
                        selected: _selected != null && isSameDay(_selected!, day),
                        onSelected: (_) => _pick(day),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  UzDates.monthYear(_month),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: t('Oldingi oy'),
                onPressed: _canPrev ? () => _shiftMonth(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: t('Keyingi oy'),
                onPressed: _canNext ? () => _shiftMonth(1) : null,
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
                      style: theme.textTheme.labelMedium?.copyWith(
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
          const SizedBox(height: 6),
          _MonthGrid(
            month: _month,
            selected: _selected,
            today: today,
            allowed: _allowed,
            onPick: _pick,
          ),
        ],
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.allowed,
    required this.onPick,
  });

  final DateTime month;
  final DateTime? selected;
  final DateTime today;
  final bool Function(DateTime) allowed;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // dushanbadan boshlanadi
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(context, r * 7 + c - leading + 1, daysInMonth)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 46);
    final date = DateTime(month.year, month.month, day);
    final enabled = allowed(date);
    final isSelected = selected != null && isSameDay(selected!, date);
    final isToday = isSameDay(today, date);
    final theme = Theme.of(context);

    final Color fg;
    if (isSelected) {
      fg = Colors.white;
    } else if (!enabled) {
      fg = context.colorTextTertiary.withValues(alpha: 0.6);
    } else {
      fg = context.colorTextPrimary;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1.1,
        child: Material(
          color: isSelected ? AppColors.primary : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isToday && !isSelected
                ? const BorderSide(color: AppColors.primary, width: 1.4)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? () => onPick(date) : null,
            child: Center(
              child: Text(
                '$day',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: fg,
                  fontWeight:
                      isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
