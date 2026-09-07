import 'package:cscrm/models/order.dart';
import 'package:cscrm/utils/delivery_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yetgazma bo'limi FAQAT xodimlar ro'yxati bo'ylab yurardi. Boshqaruvchi
/// esa xodim yozuvi emas — u yetkazgan buyurtmalar hech qayerda
/// ko'rinmasdi va jami raqam dastavchiklar yig'indisiga to'g'ri kelmasdi.

Order order({
  required int id,
  required String deliveredBy,
  required String deliveredByName,
  int deliveredAt = 5000,
}) =>
    Order.fromMap('$id', {
      'id': id,
      'customerName': 'Mijoz',
      'status': 'yetgazildi',
      'createdAt': 1000,
      'createdBy': 'kimdir',
      'deliveredAt': deliveredAt,
      'deliveredBy': deliveredBy,
      'deliveredByName': deliveredByName,
    });

void main() {
  test('boshqaruvchi yetkazgani ham ro\'yxatga tushadi', () {
    final orders = [
      order(id: 1, deliveredBy: 'uid-admin', deliveredByName: 'Afzalbek'),
    ];

    final list = deliveryPerformers(
      orders: orders,
      statsById: {'uid-admin': const DeliveryStats(deliveredCount: 1)},
      employeeNames: const {'xodim-1': 'Alisher'},
    );

    expect(list, hasLength(2), reason: 'xodim + boshqaruvchi');

    final admin = list.firstWhere((p) => p.id == 'uid-admin');
    expect(admin.name, 'Afzalbek', reason: 'ism buyurtma belgisidan olinadi');
    expect(admin.isEmployee, isFalse);
    expect(admin.stats.deliveredCount, 1);
  });

  test('ism topilmasa umumiy nom qo\'yiladi', () {
    final list = deliveryPerformers(
      orders: const [],
      statsById: {'uid-x': const DeliveryStats(deliveredCount: 2)},
      employeeNames: const {},
    );

    expect(list.single.name, 'Boshqaruvchi');
  });

  test('ish qilmagan vakolatli xodim ro\'yxatda qoladi', () {
    // "Bugun hech kim yetkazmadi" ham ma'lumot — xodim yo'qolib
    // qolmasligi kerak.
    final list = deliveryPerformers(
      orders: const [],
      statsById: const {},
      employeeNames: const {'xodim-1': 'Alisher'},
    );

    expect(list, hasLength(1));
    expect(list.single.stats.deliveredCount, 0);
    expect(list.single.isEmployee, isTrue);
  });

  test('ro\'yxatdan tashqaridagi ish qilmagan bo\'lsa qo\'shilmaydi', () {
    final list = deliveryPerformers(
      orders: const [],
      statsById: const {},
      employeeNames: const {'xodim-1': 'Alisher'},
    );

    expect(list.where((p) => !p.isEmployee), isEmpty);
  });

  test('ko\'p yetkazgan tepada turadi', () {
    final list = deliveryPerformers(
      orders: const [],
      statsById: {
        'a': const DeliveryStats(deliveredCount: 1),
        'b': const DeliveryStats(deliveredCount: 5),
      },
      employeeNames: const {'a': 'Aziz', 'b': 'Bobur'},
    );

    expect(list.first.id, 'b');
  });

  test('jami yetkazmalar dastavchilar yig\'indisiga teng', () {
    // Aynan shu tenglik buzilgan edi: boshqaruvchi tushib qolardi.
    final statsById = {
      'xodim-1': const DeliveryStats(deliveredCount: 3),
      'uid-admin': const DeliveryStats(deliveredCount: 2),
    };

    final list = deliveryPerformers(
      orders: const [],
      statsById: statsById,
      employeeNames: const {'xodim-1': 'Alisher'},
    );

    final sum = list.fold<int>(0, (a, p) => a + p.stats.deliveredCount);
    expect(sum, 5);
  });
}
