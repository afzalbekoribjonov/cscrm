import 'package:flutter/material.dart';
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

/// Haqiqiy kalendar (oy ko'rinishi) + Kunlik/Haftalik/Oylik davr tanlovi.
/// Tanlangan kun va davr o'zgarganda [onRangeChanged] chaqiriladi.
class PeriodCalendar extends StatefulWidget {
  const PeriodCalendar({super.key, required this.onRangeChanged});

  final void Function(DateTime start, DateTime end) onRangeChanged;

  @override
  State<PeriodCalendar> createState() => _PeriodCalendarState();
}

class _PeriodCalendarState extends State<PeriodCalendar> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  // "Kunlik" standart bo'lsa, bugun buyurtma bo'lmagan taqdirda statistika
  // bo'sh ko'rinib, "ishlamayapti" degan taassurot qoldiradi - shu sabab
  // "Oylik" standart qilindi.
  StatsPeriod _period = StatsPeriod.oylik;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() {
    final (start, end) = periodRange(_selectedDay, _period);
    widget.onRangeChanged(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TableCalendar(
              firstDay: DateTime(now.year - 1),
              lastDay: DateTime(now.year + 1),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              onDaySelected: (selected, focused) {
                setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                });
                _emit();
              },
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
          ),
        ),
        const SizedBox(height: 14),
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
                  onTap: () {
                    setState(() => _period = p);
                    _emit();
                  },
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
      ],
    );
  }
}
