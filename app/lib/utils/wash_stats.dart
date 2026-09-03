import '../models/item_status.dart';
import '../models/measure_unit.dart';
import '../models/order.dart';
import '../models/order_history_entry.dart';
import '../models/order_item.dart';
import 'date_utils.dart';

/// Bitta o'lchov birligi bo'yicha yuvilgan hajm.
class WashVolume {
  const WashVolume({
    required this.unit,
    required this.quantity,
    required this.itemCount,
  });

  final MeasureUnit unit;

  /// Jami miqdor (masalan 148.5 m²).
  final double quantity;

  /// Shu birlikda yuvilgan xizmatlar soni.
  final int itemCount;
}

/// Tanlangan davrdagi sex ish hajmi.
class WashStats {
  const WashStats({required this.volumes, required this.totalItems});

  /// Birlik bo'yicha jamlangan hajm - faqat noldan katta bo'lganlari.
  final List<WashVolume> volumes;

  /// Jami yuvilgan xizmat (birlik) soni.
  final int totalItems;

  bool get isEmpty => volumes.isEmpty;
}

/// Tanlangan davrda YUVILGAN xizmatlar hajmini hisoblaydi.
///
/// Muhim: buyurtma yaratilgan sana bilan yuvilgan sana har xil bo'lishi
/// mumkin, shu sabab hisob buyurtmaning `createdAt`iga emas, tarixdagi
/// "Yuvilmoqda → Qadoqlashda" o'tish vaqtiga qarab olib boriladi - bu
/// aynan yuvish ishi tugagan lahza.
///
/// Qayta yuvilgan xizmat har safar qayta hisoblanadi (ikki marta yuvilgan
/// gilam ikki marta), chunki bu ko'rsatkich sexning haqiqiy ish hajmini
/// bildiradi.
/// [history] — davr ichidagi tarix yozuvlari.
///
/// Ilgari tarix buyurtma ichida edi va bu funksiya uni `order.history`
/// dan olardi. Endi tarix alohida tugunda (ro'yxat so'roviga tushmasligi
/// uchun), shuning uchun chaqiruvchi uni alohida so'rab beradi.
WashStats washStatsForRange(
  List<Order> orders,
  List<OrderHistoryEntry> history,
  DateTime start,
  DateTime end,
) {
  final byUnit = <MeasureUnit, ({double quantity, int count})>{};
  var totalItems = 0;

  // Buyurtmani ID bo'yicha tez topish uchun.
  final ordersById = <int, Order>{for (final o in orders) o.id: o};

  for (final entry in history) {
    if (entry.type != 'item_status_changed') continue;
    if (entry.toStatus != ItemStatus.qadoqlashda.key) continue;
    if (!isWithinRange(entry.at, start, end)) continue;

    final order = ordersById[entry.orderId];
    if (order == null || order.items.isEmpty) continue;

    final itemsByKey = <String, OrderItem>{
      for (final item in order.items) item.key: item,
    };

    final item = _resolveItem(itemsByKey, order.items, entry);
    if (item == null) continue;
    final unit = item.unit;
    if (unit == null || item.quantity <= 0) continue;

    final current = byUnit[unit];
    byUnit[unit] = (
      quantity: (current?.quantity ?? 0) + item.quantity,
      count: (current?.count ?? 0) + 1,
    );
    totalItems++;
  }

  // Birliklar doim bir xil tartibda chiqishi uchun enum tartibida.
  final volumes = <WashVolume>[];
  for (final unit in MeasureUnit.values) {
    final value = byUnit[unit];
    if (value == null || value.quantity <= 0) continue;
    volumes.add(WashVolume(
      unit: unit,
      quantity: value.quantity,
      itemCount: value.count,
    ));
  }

  return WashStats(volumes: volumes, totalItems: totalItems);
}

/// Tarix yozuvidan xizmatni topadi. Yangi yozuvlarda `itemKey` bor, eski
/// yozuvlarda esa faqat mahsulot nomi - shu sabab zaxira yo'l ham bor.
OrderItem? _resolveItem(
  Map<String, OrderItem> byKey,
  List<OrderItem> items,
  OrderHistoryEntry entry,
) {
  final key = entry.itemKey;
  if (key != null) return byKey[key];
  final name = entry.itemProductName;
  if (name == null) return null;
  for (final item in items) {
    if (item.productName == name) return item;
  }
  return null;
}

/// Raqamni birlik belgisi bilan chiroyli ko'rsatadi: "148.5 m²".
String formatVolume(double value, MeasureUnit unit) {
  final rounded = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$rounded ${unit.short}';
}
