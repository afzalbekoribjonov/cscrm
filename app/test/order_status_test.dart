import 'package:cscrm/models/order_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Buyurtma bosqichlari.
///
/// [OrderStatus.isClosed] — kichik getter, lekin u BIZNES QOIDASINI
/// ifodalaydi: yetgazilgan buyurtmaga endi tegilmaydi. Unga tayanib
/// xizmat qo'shish, narx o'zgartirish va o'chirish tugmalari
/// yashiriladi.
///
/// Yangi bosqich qo'shilganda uni ham "yopiq" deb belgilash kerak
/// bo'lishi mumkin — sinov shuni eslatadi.
void main() {
  test('faqat "Yetgazildi" yopiq hisoblanadi', () {
    expect(OrderStatus.yetgazildi.isClosed, isTrue);

    for (final status in OrderStatus.values) {
      if (status == OrderStatus.yetgazildi) continue;
      expect(
        status.isClosed,
        isFalse,
        reason: '${status.key} hali tugamagan ish',
      );
    }
  });

  test('sexdagi bosqichlar yopiq emas', () {
    expect(OrderStatus.yuvishda.isInWorkshop, isTrue);
    expect(OrderStatus.yuvishda.isClosed, isFalse);
  });

  test('bosqichlar soni kutilganidek', () {
    // Yangi bosqich qo'shilsa bu sinov yiqiladi va yuqoridagi
    // qoidalarni qayta ko'rib chiqishni eslatadi.
    expect(OrderStatus.values, hasLength(5));
  });
}
