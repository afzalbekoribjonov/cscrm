/// Yozuvlarni OYLAR bo'yicha guruhlash — chiqimlar va qarzdorlar
/// ro'yxatlari uchun ("Noyabr 2026 · 5 ta · 1 250 000 so'm").
library;

class MonthGroup<T> {
  const MonthGroup({
    required this.month,
    required this.items,
    required this.total,
  });

  /// Oyning birinchi kuni.
  final DateTime month;

  /// Oy ichidagi yozuvlar — yangisi birinchi.
  final List<T> items;
  final double total;
}

/// [at] — yozuv sanasi (ms), [amount] — summasi. Natija: oylar kamayish
/// tartibida (eng yangi oy birinchi).
List<MonthGroup<T>> groupByMonth<T>(
  Iterable<T> items, {
  required int Function(T item) at,
  required double Function(T item) amount,
}) {
  final byMonth = <DateTime, List<T>>{};
  for (final item in items) {
    final d = DateTime.fromMillisecondsSinceEpoch(at(item));
    byMonth.putIfAbsent(DateTime(d.year, d.month), () => []).add(item);
  }
  final months = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final m in months)
      MonthGroup(
        month: m,
        items: byMonth[m]!..sort((a, b) => at(b).compareTo(at(a))),
        total: byMonth[m]!.fold<double>(0, (s, i) => s + amount(i)),
      ),
  ];
}
