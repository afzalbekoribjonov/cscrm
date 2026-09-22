import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_order.dart';

/// Yuborilmagan buyurtmalar navbati — QURILMADA saqlanadi.
///
/// Xotirada emas, diskda: ilova yopilib qayta ochilsa ham navbat
/// joyida qolishi kerak. Aks holda internetsiz yozilgan buyurtma
/// ilova yopilishi bilan yo'qolardi — bu esa ma'lumot yo'qotish
/// degani.
///
/// Tartib SAQLANADI: buyurtmalar yaratilish vaqti bo'yicha, eng
/// eskisidan boshlab yuboriladi. Shu tufayli raqamlar ham shu
/// tartibda beriladi.
class PendingOrderStore {
  /// Konstruktor OCHIQ: sinovda har bir holat uchun toza navbat
  /// kerak. Yagona nusxa (`instance`) esa ilovaning o'zi uchun —
  /// navbat butun ilovada bitta bo'lishi shart.
  PendingOrderStore();

  static final PendingOrderStore instance = PendingOrderStore();

  static const _key = 'pending_orders';

  /// Navbat o'zgarganda xabar beradi — ekranlar shunga obuna bo'ladi.
  final ValueNotifier<List<PendingOrder>> orders = ValueNotifier(const []);

  var _loaded = false;

  /// Diskdagi navbatni xotiraga o'qiydi. Bir marta chaqirilsa yetarli.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    orders.value = await _read();
  }

  Future<List<PendingOrder>> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      final parsed = <PendingOrder>[];
      for (final item in raw) {
        try {
          parsed.add(PendingOrder.decode(item));
        } catch (e) {
          // Bitta buzuq yozuv butun navbatni to'xtatmasligi kerak:
          // qolganlari baribir yuborilishi lozim.
          debugPrint('Navbatdagi yozuvni o\'qib bo\'lmadi: $e');
        }
      }
      parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return parsed;
    } catch (e) {
      debugPrint('Navbatni o\'qib bo\'lmadi: $e');
      return const [];
    }
  }

  Future<void> _write(List<PendingOrder> list) async {
    orders.value = List.unmodifiable(list);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, list.map((o) => o.encode()).toList());
  }

  /// Navbatga qo'shadi va saqlangan yozuvni qaytaradi.
  Future<PendingOrder> add(PendingOrder order) async {
    await load();
    await _write([...orders.value, order]);
    return order;
  }

  /// Serverdan olingan raqamni yozib qo'yadi.
  ///
  /// Buyurtmani yozishdan OLDIN chaqiriladi — sababi
  /// [PendingOrder.assignedOrderId] izohida.
  Future<void> assignOrderId(String localId, int orderId) async {
    await load();
    await _write([
      for (final o in orders.value)
        if (o.localId == localId) o.withOrderId(orderId) else o,
    ]);
  }

  /// Yuborilgan yozuvni navbatdan olib tashlaydi.
  Future<void> remove(String localId) async {
    await load();
    await _write([
      for (final o in orders.value)
        if (o.localId != localId) o,
    ]);
  }

  /// Chiqishda: navbat keyingi foydalanuvchiga o'tib ketmasin.
  Future<void> clear() async {
    _loaded = true;
    await _write(const []);
  }

  /// Yangi mahalliy kalit.
  ///
  /// Vaqt + tasodifiy qism: bir soniyada bir nechta buyurtma
  /// yaratilsa ham kalitlar to'qnashmaydi.
  static String newLocalId() {
    final random = Random();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${random.nextInt(1 << 32).toRadixString(16)}';
  }
}
