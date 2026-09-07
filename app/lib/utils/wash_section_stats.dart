import '../models/item_status.dart';
import '../models/order.dart';

/// "Yuvish" bo'limi tepasidagi ko'rsatkichlar.
///
/// Ro'yxatning o'zi buyurtmalarni ko'rsatadi, lekin sexdagi odamga
/// kerakli savollar boshqacha: qancha ish bor, nimadan boshlash kerak,
/// nima to'sib turibdi. Shu sabab ro'yxat ustida qisqa xulosa turadi.
///
/// Sof hisob: vidjetdan ajratilgan, test bilan qoplangan.
class WashSectionStats {
  const WashSectionStats({
    required this.orderCount,
    required this.washingItems,
    required this.rewashItems,
    required this.unmeasuredItems,
    required this.ordersWithoutItems,
  });

  static const empty = WashSectionStats(
    orderCount: 0,
    washingItems: 0,
    rewashItems: 0,
    unmeasuredItems: 0,
    ordersWithoutItems: 0,
  );

  /// Bo'limdagi buyurtmalar soni.
  final int orderCount;

  /// Ayni paytda yuvilayotgan xizmatlar.
  final int washingItems;

  /// Qayta yuvishga qaytarilgan xizmatlar — bu QAYTA ish, ya'ni
  /// e'tiborni birinchi shu tortishi kerak.
  final int rewashItems;

  /// O'lchami hali kiritilmagan xizmatlar. Ular o'lchanmaguncha narx
  /// ham, hajm hisoboti ham to'liq bo'lmaydi.
  final int unmeasuredItems;

  /// Xizmati umuman qo'shilmagan buyurtmalar.
  final int ordersWithoutItems;

  bool get isEmpty => orderCount == 0;
}

WashSectionStats washSectionStats(List<Order> orders) {
  var washing = 0;
  var rewash = 0;
  var unmeasured = 0;
  var withoutItems = 0;

  for (final order in orders) {
    if (order.items.isEmpty) {
      withoutItems++;
      continue;
    }
    for (final item in order.items) {
      switch (item.status) {
        case ItemStatus.yuvilmoqda:
          washing++;
        case ItemStatus.qaytaYuvildi:
          rewash++;
        case ItemStatus.qadoqlashda:
        case ItemStatus.tayyor:
          // Bu bosqichlar boshqa bo'limlarga tegishli - bu yerda
          // sanalmaydi, aks holda raqam ish hajmini oshirib ko'rsatardi.
          continue;
      }
      // O'lchov faqat SHU bo'limdagi (yuviladigan) xizmatlar uchun
      // muhim - qadoqlashga o'tgani allaqachon o'lchangan bo'ladi.
      //
      // "O'lchangan" deganda RAQAMLI o'lchov tushuniladi, `isMeasured`
      // dagidek matn maydoni emas. Sabab: hajm hisoboti aynan raqamga
      // qaraydi. Matn bor-u raqam yo'q bo'lsa, xizmat hisobotga
      // tushmaydi - va bu ko'rsatkich buni ko'rsatishi kerak, aks holda
      // "o'lchangan" deb turgan narsa hisobotda yo'qolib qolardi.
      if (item.unit == null || item.quantity <= 0) unmeasured++;
    }
  }

  return WashSectionStats(
    orderCount: orders.length,
    washingItems: washing,
    rewashItems: rewash,
    unmeasuredItems: unmeasured,
    ordersWithoutItems: withoutItems,
  );
}
