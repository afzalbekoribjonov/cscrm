import '../models/item_status.dart';
import '../models/measure_unit.dart';
import '../models/order.dart';
import '../models/order_history_entry.dart';
import '../models/order_status.dart';
import 'date_utils.dart';
import 'delivery_stats.dart';
import 'income_stats.dart';

/// Hajm yig'indisi: birlik bo'yicha ("12 m² · 3 dona · 4 kg").
class Volume {
  Volume();

  final Map<MeasureUnit, double> byUnit = {};
  var items = 0;

  void add(MeasureUnit? unit, double? quantity) {
    items++;
    if (unit == null || quantity == null || quantity <= 0) return;
    // "Kichik"/"Katta" — dona sifatida sanaladi.
    final u = unit == MeasureUnit.kichik || unit == MeasureUnit.katta
        ? MeasureUnit.dona
        : unit;
    byUnit[u] = (byUnit[u] ?? 0) + quantity;
  }

  double get squareMeters => byUnit[MeasureUnit.m2] ?? 0;
  bool get isEmpty => items == 0;

  /// "12,5 m² · 3 dona" — bo'sh bo'lsa "N ta".
  String label() {
    final parts = <String>[
      for (final u in const [
        MeasureUnit.m2,
        MeasureUnit.metr,
        MeasureUnit.kg,
        MeasureUnit.dona,
      ])
        if ((byUnit[u] ?? 0) > 0) '${formatQuantity(byUnit[u]!)} ${u.short}',
    ];
    return parts.isEmpty ? '$items ta' : parts.join(' · ');
  }
}

/// "12", "12,5" — ortiqcha nolsiz.
String formatQuantity(double v) {
  final rounded = (v * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.toInt().toString();
  return rounded.toStringAsFixed(1).replaceAll('.', ',');
}

/// Xodimning bir davrdagi ishi.
class EmployeeWork {
  EmployeeWork(this.id, this.name);

  final String id;
  String name;

  /// Yuvib qadoqlashga bergan xizmatlari.
  final washed = Volume();

  /// Qadoqlagan (tayyor qilgan) xizmatlari.
  final packaged = Volume();

  /// "Yuvish" tugmasini bosgan — yuvishni boshlagan xizmatlari.
  var washStarted = 0;

  /// Qayta yuvishga qaytargan.
  var rewashed = 0;

  /// Qabul qilgan (yaratgan) buyurtmalari.
  var created = 0;

  /// Mijozdan olib kelgani.
  var pickedUp = 0;

  /// Mijozga topshirgani.
  var delivered = 0;

  /// Bo'lib topshirishlar soni.
  var partial = 0;

  /// Olgan puli (naqd va karta alohida).
  var cash = 0.0;
  var card = 0.0;

  final log = <OrderHistoryEntry>[];

  double get collected => cash + card;

  /// Tartiblash uchun "ish hajmi".
  double get score =>
      washed.items * 2 +
      packaged.items * 2 +
      washed.squareMeters / 4 +
      created +
      pickedUp * 2 +
      delivered * 2 +
      partial;

  bool get isEmpty => score == 0 && collected == 0 && washStarted == 0;
}

/// Davr tarixidan har bir xodimning ishini hisoblaydi.
///
/// Xizmat hajmi tarix yozuvining o'zidan olinadi (yangi yozuvlar uni
/// saqlaydi). Eski yozuvlarda hajm yo'q — o'shalar uchun [ordersById]
/// dagi buyurtmadan qidiriladi (bo'lmasa faqat soni sanaladi).
///
/// [delivered] — davrda topshirilgan buyurtmalar: pul AYNAN buyurtmadan
/// olinadi (tarixdagi summa emas), hisobot bilan bir xil chiqishi uchun.
List<EmployeeWork> teamWork({
  required List<OrderHistoryEntry> history,
  required List<Order> delivered,
  required DateTime start,
  required DateTime end,
  Map<int, Order> ordersById = const {},
  Map<String, String> names = const {},
}) {
  final byId = <String, EmployeeWork>{};
  EmployeeWork of(String id, String name) {
    final w = byId.putIfAbsent(id, () => EmployeeWork(id, names[id] ?? name));
    if (w.name.isEmpty || w.name == 'Admin') w.name = names[id] ?? name;
    return w;
  }

  for (final h in history) {
    if (h.byEmployeeId.isEmpty || !isWithinRange(h.at, start, end)) continue;
    final w = of(h.byEmployeeId, h.byName);
    var counted = true;
    switch (h.type) {
      case 'order_created':
        w.created++;
      case 'partial_delivery':
        w.partial++;
        final amount = h.amount ?? 0;
        if (amount > 0) {
          if (h.method == cashPaymentLabel) {
            w.cash += amount;
          } else {
            w.card += amount;
          }
        }
      case 'debt_settled':
        final amount = h.amount ?? 0;
        if (amount > 0) {
          if (h.method == cashPaymentLabel) {
            w.cash += amount;
          } else {
            w.card += amount;
          }
        }
      case 'status_changed':
        if (h.fromStatus == OrderStatus.olibKelish.key &&
            h.toStatus == OrderStatus.yuvishda.key) {
          w.pickedUp++;
        } else {
          counted = false;
        }
      case 'item_status_changed':
        var unit = h.unit;
        var quantity = h.quantity;
        if (unit == null || quantity == null) {
          final order = ordersById[h.orderId];
          final key = h.itemKey;
          for (final item in order?.items ?? const []) {
            if (key != null ? item.key == key : item.productName == h.itemProductName) {
              unit = item.unit;
              quantity = item.quantity;
              break;
            }
          }
        }
        if (h.toStatus == ItemStatus.qadoqlashda.key) {
          w.washed.add(unit, quantity);
        } else if (h.toStatus == ItemStatus.tayyor.key) {
          w.packaged.add(unit, quantity);
        } else if (h.toStatus == ItemStatus.yuvilmoqda.key) {
          w.washStarted++;
        } else if (h.toStatus == ItemStatus.qaytaYuvildi.key) {
          w.rewashed++;
        } else {
          counted = false;
        }
      default:
        counted = false;
    }
    if (counted) w.log.add(h);
  }

  // Topshirish va olingan pul — buyurtmaning o'zidan.
  for (final o in delivered) {
    final d = o.delivered;
    if (d == null || !isWithinRange(d.at, start, end)) continue;
    final w = of(d.employeeId, d.name);
    w.delivered++;
    final paid = o.paidAtDelivery;
    if (paid > 0) {
      if (o.paymentMethod == cashPaymentLabel) {
        w.cash += paid;
      } else {
        w.card += paid;
      }
    }
  }

  final result = byId.values.where((w) => !w.isEmpty).toList()
    ..sort((a, b) => b.score.compareTo(a.score));
  for (final w in result) {
    w.log.sort((a, b) => b.at.compareTo(a.at));
  }
  return result;
}

/// Bir kunning xulosasi (bosh sahifa va kunlik hisobot uchun).
class DaySummary {
  const DaySummary({
    required this.day,
    required this.income,
    required this.washed,
    required this.packaged,
    required this.rewashed,
    required this.created,
    required this.pickedUp,
    required this.delivered,
  });

  final DateTime day;
  final IncomeStats income;
  final Volume washed;
  final Volume packaged;
  final int rewashed;
  final int created;
  final int pickedUp;
  final int delivered;
}

DaySummary summarizeDay({
  required DateTime day,
  required List<Order> orders,
  required List<OrderHistoryEntry> history,
  Map<int, Order> ordersById = const {},
}) {
  final start = startOfDay(day);
  final end = endOfDay(day);
  final team = teamWork(
    history: history,
    delivered: orders,
    start: start,
    end: end,
    ordersById: ordersById,
  );
  final washed = Volume();
  final packaged = Volume();
  var rewashed = 0;
  var created = 0;
  var pickedUp = 0;
  var delivered = 0;
  for (final w in team) {
    washed.items += w.washed.items;
    packaged.items += w.packaged.items;
    w.washed.byUnit.forEach((u, q) => washed.byUnit[u] = (washed.byUnit[u] ?? 0) + q);
    w.packaged.byUnit
        .forEach((u, q) => packaged.byUnit[u] = (packaged.byUnit[u] ?? 0) + q);
    rewashed += w.rewashed;
    created += w.created;
    pickedUp += w.pickedUp;
    delivered += w.delivered;
  }
  return DaySummary(
    day: start,
    income: incomeForRange(orders, history, start, end),
    washed: washed,
    packaged: packaged,
    rewashed: rewashed,
    created: created,
    pickedUp: pickedUp,
    delivered: delivered,
  );
}
