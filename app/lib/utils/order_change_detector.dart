import '../models/order.dart';

/// Buyurtmalar ro'yxatidagi o'zgarishni aniqlaydi va ovozli signal
/// chalish kerakligini hal qiladi.
///
/// Uchta muammoni hal qiladi (eski `_notifyIfChanged` da uchalasi ham bor edi):
///
///  1. **O'z harakatiga ovoz chiqmaydi.** Ilgari xodim tugma bossa,
///     o'zining o'zgarishidan ovoz eshitardi. Endi o'zgarishni kim
///     qilgani tarixdan tekshiriladi.
///  2. **Birinchi yuklanishda jim.** Ilova ochilganda butun ro'yxat
///     "yangi" bo'lib ko'rinadi — bu o'zgarish emas.
///  3. **Arzon taqqoslash.** Ilgari butun ro'yxatdan bitta ulkan matn
///     yasalardi. Endi har bir buyurtma uchun qisqa iz saqlanadi.
///
/// Sinf holatga ega, lekin Firebase'ga bog'liq emas — shuning uchun
/// to'g'ridan-to'g'ri test qilinadi.
class OrderChangeDetector {
  OrderChangeDetector({required this.currentActorId});

  /// Joriy foydalanuvchi (xodim ID yoki egа UID) — tarixda "kim qildi"
  /// deb yoziladigan qiymat bilan bir xil bo'lishi shart.
  final String currentActorId;

  Map<int, String>? _previous;

  /// Oqim yangilanganda chaqiriladi.
  ///
  /// `true` — BOSHQA odam qilgan o'zgarish bor, ovoz chalinadi.
  bool shouldNotify(List<Order> orders) {
    final current = <int, String>{
      for (final order in orders) order.id: _signatureOf(order),
    };

    final previous = _previous;
    _previous = current;

    // Birinchi yuklanish — hamma narsa "yangi" ko'rinadi, lekin bu
    // o'zgarish emas.
    if (previous == null) return false;

    for (final entry in current.entries) {
      if (previous[entry.key] == entry.value) continue;

      // Shu buyurtma o'zgargan (yoki yangi qo'shilgan).
      final order = _findById(orders, entry.key);
      if (order == null) continue;
      if (_lastActorOf(order) != currentActorId) return true;
    }

    // Buyurtma o'chirilgani uchun ovoz chalmaymiz — o'chirish odatda
    // ataylab qilinadi va tegishli ekranda allaqachon ko'rinadi.
    return false;
  }

  /// Oqim qayta ulanganda chaqiriladi — keyingi kelgan ro'yxat "birinchi"
  /// deb hisoblanadi va bir yo'la ovoz chalinmaydi.
  void reset() => _previous = null;

  Order? _findById(List<Order> orders, int id) {
    for (final order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Buyurtmaning e'tibor talab qiladigan holati.
  ///
  /// Faqat xodimga ko'rinadigan o'zgarishlar kiritiladi — masalan
  /// `totalPrice` yoki mijoz manzili o'zgarsa ovoz chalinmaydi.
  String _signatureOf(Order order) {
    final items = order.items.map((i) => i.status.key).join(',');
    return '${order.status.key}|$items|${order.comments.length}';
  }

  /// Buyurtmaga oxirgi marta kim tegingani.
  ///
  /// Buyurtmaning O'ZIDAGI `lastActionBy` maydonidan o'qiladi. Ilgari
  /// buning uchun butun tarix yuklanardi — endi tarix alohida tugunda va
  /// ro'yxat so'roviga tushmaydi.
  String? _lastActorOf(Order order) =>
      order.lastActionBy.isEmpty ? null : order.lastActionBy;
}
