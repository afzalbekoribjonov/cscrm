import '../models/employee.dart';
import '../models/payroll.dart';
import 'date_utils.dart';
import 'money.dart';

/// Kunlar bo'yicha yozuvlardan har bir xodimning JAMI ishi.
///
/// [from]/[to] berilsa — faqat shu oraliqdagi kunlar.
Map<String, WorkTally> tallyByEmployee(
  Map<String, Map<String, WorkTally>> days, {
  DateTime? from,
  DateTime? to,
}) {
  final fromKey = from == null ? null : dayKey(from);
  final toKey = to == null ? null : dayKey(to);
  final out = <String, WorkTally>{};
  for (final day in days.entries) {
    if (fromKey != null && day.key.compareTo(fromKey) < 0) continue;
    if (toKey != null && day.key.compareTo(toKey) > 0) continue;
    for (final e in day.value.entries) {
      out.putIfAbsent(e.key, () => WorkTally(name: e.value.name)).addAll(e.value);
    }
  }
  return out;
}

/// Qat'iy oylikning [from]–[to] kunlariga to'g'ri keladigan qismi.
///
/// Har bir kun o'z oyining 1/kunlar_soni ulushini oladi: noyabrning
/// bir kuni — oylikning 1/30, fevralniki — 1/28. Kelajakdagi kunlar
/// ([today] dan keyin) hisoblanmaydi — hali ishlanmagan.
double fixedShare(
  double monthly,
  DateTime from,
  DateTime to, {
  DateTime? today,
}) {
  if (monthly <= 0) return 0;
  final limit = startOfDay(today ?? DateTime.now());
  var day = startOfDay(from);
  final last = startOfDay(to).isAfter(limit) ? limit : startOfDay(to);
  var total = 0.0;
  var guard = 0;
  while (!day.isAfter(last) && guard++ < 3700) {
    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
    total += monthly / daysInMonth;
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return total.roundToDouble();
}

/// Davr uchun maosh xarajati — hisobotdagi "Maosh".
class SalaryCost {
  const SalaryCost({required this.fixed, required this.piece});

  final double fixed;
  final double piece;

  double get total => fixed + piece;
}

/// Davr uchun maosh xarajati: qat'iy oylikning shu kunlarga to'g'ri
/// keladigan ulushi + shu kunlarda bajarilgan ishbayi.
///
/// Faqat maoshi SOZLANGAN va FAOL xodimlar hisoblanadi.
SalaryCost salaryCost({
  required DateTime from,
  required DateTime to,
  required Map<String, StaffPay> staff,
  required Map<String, Map<String, WorkTally>> days,
  required List<Employee> employees,
  DateTime? today,
}) {
  final active = {for (final e in employees) if (e.active) e.id};
  final tallies = tallyByEmployee(days, from: from, to: to);
  var fixed = 0.0;
  var piece = 0.0;
  for (final entry in staff.entries) {
    if (!active.contains(entry.key)) continue;
    final pay = entry.value;
    fixed += fixedShare(pay.fixedMonthly, from, to, today: today);
    piece += tallies[entry.key]?.piecePay(pay.activePieces) ?? 0;
  }
  return SalaryCost(fixed: fixed, piece: piece);
}

/// Oy bo'yicha har bir xodimning hisob-kitobi (Maosh sahifasi).
///
/// Ro'yxatda: barcha FAOL xodimlar + o'chirilgan/bloklangan bo'lsa ham
/// shu oyda ishi yoki to'lovi bor xodimlar (hisob yo'qolmasin).
List<MonthPayroll> monthPayroll({
  required List<Employee> employees,
  required Map<String, StaffPay> staff,
  required Map<String, WorkTally> work,
  required List<PayrollPayment> payments,
}) {
  final byId = {for (final e in employees) e.id: e};
  final ids = <String>{
    for (final e in employees)
      if (e.active) e.id,
    for (final e in work.entries)
      if (byId.containsKey(e.key) && !e.value.isEmpty) e.key,
    for (final p in payments)
      if (byId.containsKey(p.employeeId)) p.employeeId,
  };
  final list = [
    for (final id in ids)
      MonthPayroll(
        employeeId: id,
        name: byId[id]?.fullName ?? work[id]?.name ?? '',
        pay: staff[id],
        work: work[id] ?? WorkTally(),
        payments: payments.where((p) => p.employeeId == id).toList(),
      ),
  ]..sort((a, b) {
      final c = b.accrued.compareTo(a.accrued);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return list;
}

/// Bugungi ishbayi bo'yicha reyting (bosh sahifa): xodimlar, eng ko'p
/// ishlagan birinchi. Maoshi sozlanmagan xodimda — barcha ish turlari.
List<({String id, String name, WorkTally work, double earned})> todayRanking({
  required Map<String, WorkTally> today,
  required List<Employee> employees,
  required Map<String, StaffPay>? staff,
}) {
  final byId = {for (final e in employees) e.id: e};
  final list = [
    for (final e in today.entries)
      if (byId.containsKey(e.key) && !e.value.isEmpty)
        (
          id: e.key,
          name: byId[e.key]!.fullName,
          work: e.value,
          earned: () {
            final pay = staff?[e.key];
            if (pay == null) return e.value.allPiecePay;
            return e.value.piecePay(pay.activePieces);
          }(),
        ),
  ]..sort((a, b) {
      final c = b.earned.compareTo(a.earned);
      if (c != 0) return c;
      return (b.work.washN + b.work.packN + b.work.deliverN + b.work.createN)
          .compareTo(a.work.washN + a.work.packN + a.work.deliverN + a.work.createN);
    });
  return list;
}

/// Xodimning bir kunlik/oylik ishining qisqa qatorlari:
/// "Yuvdi: 124 m² · 41 m · 4 kichik".
List<({String label, String value})> workLines(WorkTally w) => [
      if (w.washN > 0)
        (label: 'Yuvdi', value: w.wash.label(empty: '${w.washN} ta xizmat')),
      if (w.packN > 0)
        (
          label: 'Qadoqladi',
          value: w.pack.label(empty: '${w.packN} ta xizmat'),
        ),
      if (w.deliverN > 0)
        (
          label: 'Topshirdi',
          value: w.deliverSum > 0
              ? '${w.deliverN} marta · ${formatSom(w.deliverSum)}'
              : '${w.deliverN} marta',
        ),
      if (w.createN > 0) (label: 'Qabul qildi', value: '${w.createN} ta buyurtma'),
      if (w.dispatchN > 0)
        (label: 'Buyurtmasi topshirildi', value: '${w.dispatchN} ta'),
      if (w.rewashN > 0) (label: 'Qayta yuvishga qaytdi', value: '${w.rewashN} ta'),
    ];
