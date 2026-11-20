import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../utils/uz_dates.dart';
import 'sheets.dart';

/// Kunlar oralig'i: bitta kun, istalgan oraliq yoki butun oy.
@immutable
class DateRange {
  DateRange(DateTime start, DateTime end)
      : start = startOfDay(start.isAfter(end) ? end : start),
        end = startOfDay(start.isAfter(end) ? start : end);

  factory DateRange.day(DateTime d) => DateRange(d, d);

  factory DateRange.today({DateTime? now}) =>
      DateRange.day(now ?? DateTime.now());

  /// Butun oy — kelajak kunlarsiz (joriy oy bo'lsa bugungacha).
  factory DateRange.month(DateTime month, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final first = DateTime(month.year, month.month);
    var last = DateTime(month.year, month.month + 1, 0);
    if (last.isAfter(today)) last = today;
    return DateRange(first, last.isBefore(first) ? first : last);
  }

  /// Kunning boshi.
  final DateTime start;

  /// Oxirgi kunning BOSHI (sana sifatida). Oraliq oxiri: [to].
  final DateTime end;

  DateTime get from => start;
  DateTime get to => endOfDay(end);

  int get days => end.difference(start).inDays + 1;

  bool get isSingleDay => isSameDay(start, end);

  bool isToday({DateTime? now}) =>
      isSingleDay && isSameDay(start, now ?? DateTime.now());

  /// Oyning 1-kunidan boshlanib, oy oxirigacha (yoki bugungacha) davom
  /// etadi.
  bool isWholeMonth({DateTime? now}) {
    if (start.day != 1 || start.month != end.month || start.year != end.year) {
      return false;
    }
    final today = startOfDay(now ?? DateTime.now());
    final monthEnd = DateTime(start.year, start.month + 1, 0);
    return isSameDay(end, monthEnd) ||
        (isSameDay(end, today) && monthEnd.isAfter(today));
  }

  bool contains(DateTime d) {
    final day = startOfDay(d);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// "Bugun", "Kecha", "12-noyabr", "Noyabr 2026", "3–12-noyabr",
  /// "28-oktabr — 3-noyabr".
  String label({DateTime? now}) {
    final today = now ?? DateTime.now();
    if (isSingleDay) {
      final rel = UzDates.relativeDay(start, now: today);
      return rel == 'Bugun' || rel == 'Kecha'
          ? '$rel · ${UzDates.date(start, now: today)}'
          : UzDates.date(start, now: today);
    }
    if (isWholeMonth(now: today)) return UzDates.monthYear(start);
    final sameYear = start.year == end.year;
    final suffix = end.year == today.year ? '' : ', ${end.year}';
    if (sameYear && start.month == end.month) {
      return '${start.day}–${UzDates.dayMonth(end)}$suffix';
    }
    final startLabel = sameYear
        ? UzDates.dayMonth(start)
        : '${UzDates.dayMonth(start)}, ${start.year}';
    return '$startLabel — ${UzDates.dayMonth(end)}$suffix';
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

/// Hisobot tepasidagi davr tugmasi: tanlangan davr nomi + kalendar.
/// "Bugun" dan boshqa davr tanlansa, yonida "Bugunga qaytish" chiqadi.
class RangeBar extends StatelessWidget {
  const RangeBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.now,
  });

  final DateRange value;
  final ValueChanged<DateRange> onChanged;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = now ?? DateTime.now();
    return Row(
      children: [
        Expanded(
          child: Material(
            color: context.colorSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md),
              side: BorderSide(color: context.colorBorder),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.md),
              onTap: () async {
                final picked = await showRangePicker(context,
                    initial: value, now: today);
                if (picked != null) onChanged(picked);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colorPrimarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          size: 20, color: context.colorPrimaryInk),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.label(now: today),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            value.isSingleDay
                                ? UzDates.weekdays[value.start.weekday - 1]
                                : '${value.days} kun',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.unfold_more_rounded,
                        color: context.colorTextTertiary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!value.isToday(now: today)) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: t('Bugunga qaytish'),
            onPressed: () => onChanged(DateRange.today(now: today)),
            icon: const Icon(Icons.today_rounded),
          ),
        ],
      ],
    );
  }
}

/// O'zbekcha kalendar: bitta kun, oraliq (ikki kun bosiladi) yoki butun
/// oy. Kelajak kunlarni tanlab bo'lmaydi.
Future<DateRange?> showRangePicker(
  BuildContext context, {
  required DateRange initial,
  DateTime? now,
}) =>
    showAppSheet<DateRange>(
      context,
      (_) => _RangePicker(initial: initial, now: now ?? DateTime.now()),
    );

class _RangePicker extends StatefulWidget {
  const _RangePicker({required this.initial, required this.now});

  final DateRange initial;
  final DateTime now;

  @override
  State<_RangePicker> createState() => _RangePickerState();
}

class _RangePickerState extends State<_RangePicker> {
  late DateTime _start = widget.initial.start;
  late DateTime _end = widget.initial.end;

  /// Birinchi kun bosilgan, ikkinchisi kutilmoqda.
  var _awaitingEnd = false;

  late DateTime _month =
      DateTime(widget.initial.end.year, widget.initial.end.month);

  DateTime get _today => startOfDay(widget.now);
  DateTime get _first => DateTime(_today.year - 3);

  DateRange get _range => DateRange(_start, _end);

  void _pick(DateTime d) => setState(() {
        if (!_awaitingEnd) {
          _start = d;
          _end = d;
          _awaitingEnd = true;
        } else {
          if (d.isBefore(_start)) {
            _end = _start;
            _start = d;
          } else {
            _end = d;
          }
          _awaitingEnd = false;
        }
      });

  void _set(DateRange r) => setState(() {
        _start = r.start;
        _end = r.end;
        _awaitingEnd = false;
        _month = DateTime(r.end.year, r.end.month);
      });

  bool get _canPrev =>
      DateTime(_month.year, _month.month).isAfter(DateTime(_first.year, _first.month));
  bool get _canNext => DateTime(_month.year, _month.month)
      .isBefore(DateTime(_today.year, _today.month));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = _today;
    final weekStart = startOfWeek(today);
    final lastMonth = DateTime(today.year, today.month - 1);
    final quick = <(String, DateRange)>[
      ('Bugun', DateRange.day(today)),
      ('Kecha', DateRange.day(today.subtract(const Duration(days: 1)))),
      ('Shu hafta', DateRange(weekStart, today)),
      ('7 kun', DateRange(today.subtract(const Duration(days: 6)), today)),
      ('Shu oy', DateRange.month(today, now: today)),
      ('O\'tgan oy', DateRange.month(lastMonth, now: today)),
    ];
    final range = _range;

    return SheetFrame(
      title: 'Davrni tanlang',
      subtitle: _awaitingEnd
          ? 'Oraliq uchun ikkinchi kunni bosing'
          : 'Kun, oraliq yoki butun oy',
      actions: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  range.label(now: today),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  range.isSingleDay ? '1 kun' : '${range.days} kun',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
            onPressed: () => Navigator.of(context).pop(range),
            child: const Text('Tanlash'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (label, r) in quick)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: !_awaitingEnd && r == range,
                      onSelected: (_) => _set(r),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                tooltip: t('Oldingi oy'),
                onPressed: _canPrev
                    ? () => setState(() =>
                        _month = DateTime(_month.year, _month.month - 1))
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  UzDates.monthYear(_month),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t('Keyingi oy'),
                onPressed: _canNext
                    ? () => setState(() =>
                        _month = DateTime(_month.year, _month.month + 1))
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => _set(DateRange.month(_month, now: today)),
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text('Butun oy: ${UzDates.monthName(_month.month)}'),
            ),
          ),
          const SizedBox(height: 4),
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
          _RangeGrid(
            month: _month,
            range: range,
            today: today,
            first: _first,
            onPick: _pick,
          ),
        ],
      ),
    );
  }
}

class _RangeGrid extends StatelessWidget {
  const _RangeGrid({
    required this.month,
    required this.range,
    required this.today,
    required this.first,
    required this.onPick,
  });

  final DateTime month;
  final DateRange range;
  final DateTime today;
  final DateTime first;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = firstDay.weekday - 1;
    final rows = ((leading + daysInMonth) / 7).ceil();
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
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 44);
    final date = DateTime(month.year, month.month, day);
    final enabled = !date.isAfter(today) && !date.isBefore(first);
    final inRange = range.contains(date);
    final isStart = isSameDay(date, range.start);
    final isEnd = isSameDay(date, range.end);
    final edge = isStart || isEnd;
    final isToday = isSameDay(date, today);
    final theme = Theme.of(context);
    final primary = AppColors.primary;

    final Color fg;
    if (edge) {
      fg = Colors.white;
    } else if (!enabled) {
      fg = context.colorTextTertiary.withValues(alpha: 0.5);
    } else if (inRange) {
      fg = context.colorPrimaryInk;
    } else {
      fg = context.colorTextPrimary;
    }

    // Oraliq ichidagi kunlar — yaxlit tasma; boshlanish va tugash — doira.
    final band = inRange && !range.isSingleDay;
    final bandColor = primary.withValues(alpha: context.isDarkTheme ? 0.28 : 0.13);
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tasma ikki yarimdan: boshlanish kunida faqat o'ng yarmi,
          // tugash kunida faqat chap yarmi — doira chetidan uzilmaydi.
          if (band)
            Positioned.fill(
              top: 3,
              bottom: 3,
              child: Row(
                // `stretch` SHART: bolasiz ColoredBox bo'shliq cheklovida
                // 0 balandlikka tushib, tasma ko'rinmay qolardi.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: isStart ? Colors.transparent : bandColor,
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: isEnd ? Colors.transparent : bandColor,
                    ),
                  ),
                ],
              ),
            ),
          Material(
            color: edge ? primary : Colors.transparent,
            shape: CircleBorder(
              side: isToday && !edge
                  ? BorderSide(color: primary, width: 1.4)
                  : BorderSide.none,
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? () => onPick(date) : null,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Center(
                  child: Text(
                    '$day',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: fg,
                      fontWeight:
                          edge || isToday ? FontWeight.w700 : FontWeight.w500,
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
