import '../models/item_status.dart';
import '../models/measure_unit.dart';
import '../models/order.dart';
import '../models/order_history_entry.dart';
import '../models/order_item.dart';
import 'date_utils.dart';

/// Sexda bajarilgan bitta ish: qaysi xizmat, qaysi buyurtmadan, qachon.
///
/// Ko'rsatkich yonidagi "ko'z" tugmasi shu ro'yxatni ochadi — raqam
/// qayerdan chiqqanini tekshirib bo'lsin. Buyurtma raqami ataylab
/// saqlanadi: "148 m² yuvilgan" degan raqamdan ko'ra "3 ta buyurtma:
/// №12, №15, №19" ancha foydali.
class WorkItem {
  const WorkItem({
    required this.orderId,
    required this.customerName,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.at,
  });

  final int orderId;
  final String customerName;
  final String productName;
  final double quantity;
  final MeasureUnit unit;

  /// Ish tugagan lahza (ms).
  final int at;
}

/// Bitta o'lchov birligi bo'yicha hajm.
class WashVolume {
  const WashVolume({
    required this.unit,
    required this.quantity,
    required this.itemCount,
    required this.items,
  });

  final MeasureUnit unit;

  /// Jami miqdor (masalan 148.5 m²).
  final double quantity;

  /// Shu birlikdagi xizmatlar soni.
  final int itemCount;

  /// Shu raqam qaysi ishlardan yig'ilgani — tekshirish uchun.
  final List<WorkItem> items;
}

/// Tanlangan davrdagi sex ish hajmi.
class WashStats {
  const WashStats({required this.volumes, required this.totalItems});

  /// Birlik bo'yicha jamlangan hajm - faqat noldan katta bo'lganlari.
  final List<WashVolume> volumes;

  /// Jami xizmat (birlik) soni.
  final int totalItems;

  bool get isEmpty => volumes.isEmpty;

  /// Barcha birliklardagi ishlar, eng yangisi birinchi.
  List<WorkItem> get allItems {
    final all = [for (final v in volumes) ...v.items];
    all.sort((a, b) => b.at.compareTo(a.at));
    return all;
  }
}

/// Xizmatlar berilgan HOLATGA o'tgan hajmni hisoblaydi.
///
/// Hisob buyurtmaning `createdAt`iga emas, tarixdagi holat o'tish
/// vaqtiga qarab olib boriladi — buyurtma yaratilgan sana bilan ish
/// bajarilgan sana har xil bo'lishi mumkin.
///
/// Qayta yuvilgan xizmat har safar qayta hisoblanadi (ikki marta
/// yuvilgan gilam ikki marta), chunki bu ko'rsatkich sexning haqiqiy
/// ish hajmini bildiradi.
///
/// [history] — davr ichidagi tarix yozuvlari. Tarix alohida tugunda
/// (ro'yxat so'roviga tushmasligi uchun), shuning uchun chaqiruvchi uni
/// alohida so'rab beradi.
WashStats itemVolumeStats(
  List<Order> orders,
  List<OrderHistoryEntry> history,
  DateTime start,
  DateTime end, {
  required ItemStatus toStatus,
}) {
  final byUnit = <MeasureUnit, List<WorkItem>>{};
  var totalItems = 0;

  // Buyurtmani ID bo'yicha tez topish uchun.
  final ordersById = <int, Order>{for (final o in orders) o.id: o};

  for (final entry in history) {
    if (entry.type != 'item_status_changed') continue;
    if (entry.toStatus != toStatus.key) continue;
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

    (byUnit[unit] ??= []).add(WorkItem(
      orderId: order.id,
      customerName: order.customerName,
      productName: item.productName,
      quantity: item.quantity,
      unit: unit,
      at: entry.at,
    ));
    totalItems++;
  }

  // Birliklar doim bir xil tartibda chiqishi uchun enum tartibida.
  final volumes = <WashVolume>[];
  for (final unit in MeasureUnit.values) {
    final items = byUnit[unit];
    if (items == null || items.isEmpty) continue;
    final quantity = items.fold<double>(0, (sum, i) => sum + i.quantity);
    if (quantity <= 0) continue;
    items.sort((a, b) => b.at.compareTo(a.at));
    volumes.add(WashVolume(
      unit: unit,
      quantity: quantity,
      itemCount: items.length,
      items: items,
    ));
  }

  return WashStats(volumes: volumes, totalItems: totalItems);
}

/// YUVISH tugagan hajm — xizmat "Qadoqlashda" holatiga o'tgan lahza.
WashStats washStatsForRange(
  List<Order> orders,
  List<OrderHistoryEntry> history,
  DateTime start,
  DateTime end,
) =>
    itemVolumeStats(orders, history, start, end,
        toStatus: ItemStatus.qadoqlashda);

/// QADOQLASH tugagan hajm — xizmat "Tayyor" holatiga o'tgan lahza.
///
/// Yuvilgan hajmdan alohida: bir kunda yuvilgan narsa ertasiga
/// qadoqlanishi mumkin, ya'ni ikki raqam teng bo'lishi shart emas.
WashStats packagedStatsForRange(
  List<Order> orders,
  List<OrderHistoryEntry> history,
  DateTime start,
  DateTime end,
) =>
    itemVolumeStats(orders, history, start, end, toStatus: ItemStatus.tayyor);

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
