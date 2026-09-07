import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../theme/app_colors.dart';
import '../utils/date_utils.dart';

enum StatsPeriod { kunlik, haftalik, oylik }

const _periodLabels = {
  StatsPeriod.kunlik: 'Kunlik',
  StatsPeriod.haftalik: 'Haftalik',
  StatsPeriod.oylik: 'Oylik',
};

(DateTime, DateTime) periodRange(DateTime day, StatsPeriod period) {
  switch (period) {
    case StatsPeriod.kunlik:
      return (startOfDay(day), endOfDay(day));
    case StatsPeriod.haftalik:
      return (startOfWeek(day), endOfWeek(day));
    case StatsPeriod.oylik:
      return (startOfMonth(day), endOfMonth(day));
  }
}

final _dayFormat = DateFormat('dd.MM.yyyy');
final _monthFormat = DateFormat('MM.yyyy');

/// Tanlangan davr: qaysi kun va qanday oraliq.
///
/// Bu qiymat EKRAN holatida saqlanadi, tanlagich vidjetining ichida
/// emas. Sabab: tanlagich ro'yxat ichida turadi va ekrandan chiqib
/// ketganda Flutter uni yo'q qiladi. Holat vidjet ichida bo'lsa,
/// foydalanuvchi pastga aylantirib qaytganda tanlovi o'z-o'zidan
/// boshlang'ich qiymatga qaytib qolardi.
@immutable
class PeriodSelection {
  const PeriodSelection({required this.day, required this.period});

  /// Standart: BUGUN, kunlik. Ekran ochilganda aynan shu ko'rsatiladi.
  PeriodSelection.today()
      : day = DateTime.now(),
        period = StatsPeriod.kunlik;

  final DateTime day;
  final StatsPeriod period;

  (DateTime, DateTime) get range => periodRange(day, period);

  PeriodSelection copyWith({DateTime? day, StatsPeriod? period}) =>
      PeriodSelection(day: day ?? this.day, period: period ?? this.period);

  /// Tanlangan davrning odam o'qiy oladigan nomi.
  String get label {
    switch (period) {
      case StatsPeriod.kunlik:
        return isSameDay(day, DateTime.now())
            ? 'Bugun · ${_dayFormat.format(day)}'
            : _dayFormat.format(day);
      case StatsPeriod.haftalik:
        final (start, end) = range;
        return '${_dayFormat.format(start)} — ${_dayFormat.format(end)}';
      case StatsPeriod.oylik:
        return _monthFormat.format(day);
    }
  }

  /// Bugundan boshqa kun tanlanganmi — "tozalash" tugmasi shunga qarab
  /// ko'rsatiladi.
  bool get isToday =>
      period == StatsPeriod.kunlik && isSameDay(day, DateTime.now());
}

/// Ixcham davr tanlagich: Kunlik / Haftalik / Oylik + kalendar tugmasi.
///
/// Kalendar ATAYLAB ekranga joylashtirilmagan — u ro'yxatning yarmini
/// egallab, statistikani pastga surib yuborardi. Endi tugma bosilganda
/// modal oyna bo'lib ochiladi.
///
/// Vidjet holatsiz: tanlov [value] orqali kiradi, o'zgarishi esa
/// [onChanged] orqali chiqadi.
class PeriodBar extends StatelessWidget {
  const PeriodBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PeriodSelection value;
  final ValueChanged<PeriodSelection> onChanged;

  Future<void> _openCalendar(BuildContext context) async {
    final picked = await showPeriodCalendarDialog(
      context: context,
      initial: value,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.colorSurfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: StatsPeriod.values.map((p) {
              final selected = value.period == p;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value.copyWith(period: p)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          selected ? context.colorSurface : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      _periodLabels[p]!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected
                            ? AppColors.primary
                            : context.colorTextSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openCalendar(context),
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: Text(
                  value.label,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            // Tanlov BUGUNGA qaytarilmaguncha o'zgarmaydi - shu tugma
            // uni qaytaradi.
            if (!value.isToday) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Bugunga qaytish',
                onPressed: () => onChanged(PeriodSelection.today()),
                icon: const Icon(Icons.restart_alt_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: context.colorSurfaceMuted,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Kalendarni modal oyna sifatida ochadi.
///
/// Natija: tanlangan davr, yoki bekor qilinsa `null`.
Future<PeriodSelection?> showPeriodCalendarDialog({
  required BuildContext context,
  required PeriodSelection initial,
}) {
  return showDialog<PeriodSelection>(
    context: context,
    builder: (_) => _PeriodCalendarDialog(initial: initial),
  );
}

class _PeriodCalendarDialog extends StatefulWidget {
  const _PeriodCalendarDialog({required this.initial});

  final PeriodSelection initial;

  @override
  State<_PeriodCalendarDialog> createState() => _PeriodCalendarDialogState();
}

class _PeriodCalendarDialogState extends State<_PeriodCalendarDialog> {
  late DateTime _selectedDay = widget.initial.day;
  late DateTime _focusedDay = widget.initial.day;
  late StatsPeriod _period = widget.initial.period;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Davrni tanlang',
                      style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                TableCalendar(
                  firstDay: DateTime(now.year - 2),
                  lastDay: DateTime(now.year + 1),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                  onDaySelected: (selected, focused) => setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  }),
                  onPageChanged: (focused) => _focusedDay = focused,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: 'Oy'},
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: StatsPeriod.values.map((p) {
                      final selected = _period == p;
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _period = p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? context.colorSurface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              _periodLabels[p]!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected
                                    ? AppColors.primary
                                    : context.colorTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(
                        PeriodSelection.today(),
                      ),
                      child: const Text('Bugun'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Bekor'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        PeriodSelection(day: _selectedDay, period: _period),
                      ),
                      child: const Text('Tanlash'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
