bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(int millis) =>
    isSameDay(DateTime.fromMillisecondsSinceEpoch(millis), DateTime.now());

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime endOfDay(DateTime d) =>
    DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Hafta Dushanba kunidan boshlanadi (ISO-8601, DateTime.weekday: 1=Dush).
DateTime startOfWeek(DateTime d) =>
    startOfDay(d.subtract(Duration(days: d.weekday - 1)));

DateTime endOfWeek(DateTime d) =>
    endOfDay(startOfWeek(d).add(const Duration(days: 6)));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

DateTime endOfMonth(DateTime d) => endOfDay(DateTime(d.year, d.month + 1, 0));

bool isWithinRange(int millis, DateTime start, DateTime end) {
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  return !date.isBefore(start) && !date.isAfter(end);
}
