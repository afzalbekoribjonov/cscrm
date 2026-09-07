import 'package:cscrm/models/order.dart';
import 'package:cscrm/utils/wash_section_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Order order({
  int id = 1,
  List<Map<String, Object?>> items = const [],
}) =>
    Order.fromMap('$id', {
      'id': id,
      'customerName': 'Mijoz',
      'status': 'yuvishda',
      'createdAt': 1000,
      'createdBy': 'x',
      if (items.isNotEmpty)
        'items': {
          for (var i = 0; i < items.length; i++) 'k$i': items[i],
        },
    });

Map<String, Object?> item({
  required String status,
  String product = 'Gilam',
  double quantity = 0,
  String? unit,
}) =>
    {
      'productName': product,
      'status': status,
      'quantity': quantity,
      if (unit != null) 'unit': unit,
    };

void main() {
  test('bo\'sh ro\'yxatda hammasi nol', () {
    final s = washSectionStats(const []);
    expect(s.isEmpty, isTrue);
    expect(s.orderCount, 0);
    expect(s.washingItems, 0);
  });

  test('yuvilayotgan xizmatlar sanaladi', () {
    final s = washSectionStats([
      order(items: [
        item(status: 'yuvilmoqda', quantity: 5, unit: 'm2'),
        item(status: 'yuvilmoqda', quantity: 3, unit: 'm2'),
      ]),
    ]);

    expect(s.orderCount, 1);
    expect(s.washingItems, 2);
  });

  test('qadoqlash va tayyor bosqichlari sanalmaydi', () {
    // Ular boshqa bo'limga tegishli — bu yerda sanalsa, yuvish
    // bo'limidagi ish hajmi oshirib ko'rsatilardi.
    final s = washSectionStats([
      order(items: [
        item(status: 'yuvilmoqda', quantity: 5, unit: 'm2'),
        item(status: 'qadoqlashda', quantity: 5, unit: 'm2'),
        item(status: 'tayyor', quantity: 5, unit: 'm2'),
      ]),
    ]);

    expect(s.washingItems, 1);
  });

  test('qayta yuvish alohida sanaladi', () {
    final s = washSectionStats([
      order(items: [
        item(status: 'qayta_yuvildi', quantity: 4, unit: 'm2'),
        item(status: 'yuvilmoqda', quantity: 4, unit: 'm2'),
      ]),
    ]);

    expect(s.rewashItems, 1);
    expect(s.washingItems, 1);
  });

  test('o\'lchanmagan mahsulotlar sanaladi', () {
    final s = washSectionStats([
      order(items: [
        item(status: 'yuvilmoqda'), // o'lchov yo'q
        item(status: 'yuvilmoqda', quantity: 12, unit: 'm2'),
      ]),
    ]);

    expect(s.unmeasuredItems, 1);
  });

  test('qadoqlashdagi o\'lchanmagan xizmat sanalmaydi', () {
    // O'lchov faqat yuviladigan xizmatlar uchun muhim.
    final s = washSectionStats([
      order(items: [item(status: 'qadoqlashda')]),
    ]);

    expect(s.unmeasuredItems, 0);
  });

  test('xizmatsiz buyurtma alohida sanaladi', () {
    final s = washSectionStats([
      order(id: 1),
      order(id: 2, items: [item(status: 'yuvilmoqda', quantity: 2, unit: 'kg')]),
    ]);

    expect(s.ordersWithoutItems, 1);
    expect(s.orderCount, 2);
    expect(s.washingItems, 1);
  });
}
