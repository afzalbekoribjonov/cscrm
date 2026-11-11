import 'package:cscrm/models/business_policies.dart';
import 'package:cscrm/models/item_status.dart';
import 'package:cscrm/models/measure_unit.dart';
import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_item.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/utils/order_sections.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item(
  String key,
  ItemStatus status, {
  bool measured = true,
  int? handedAt,
}) =>
    OrderItem(
      key: key,
      itemId: '1/$key',
      productId: 'p',
      productName: 'Gilam',
      hajm: measured ? '2×3 m (6 m²)' : '',
      price: measured ? 60000 : 0,
      createdBy: 'e1',
      status: status,
      comments: const [],
      unit: measured ? MeasureUnit.m2 : null,
      quantity: measured ? 6 : 0,
      handedAt: handedAt,
    );

Order _order(
  int id,
  OrderStatus status,
  List<OrderItem> items, {
  int? readyAt,
}) =>
    Order(
      id: id,
      customerName: 'Mijoz $id',
      customerPhone: '998901234567',
      address: '',
      deadline: null,
      deliveryType: DeliveryType.oziKeldi,
      status: status,
      createdBy: 'e1',
      createdByName: 'Sardor',
      createdAt: 1,
      items: items,
      totalPrice: 0,
      comments: const [],
      ready: readyAt == null
          ? null
          : ActorStamp(at: readyAt, employeeId: 'e1', name: 'Sardor'),
    );

void main() {
  final now = DateTime(2026, 11, 20, 12);
  int daysAgo(int d) => now.subtract(Duration(days: d)).millisecondsSinceEpoch;

  group('buyurtma joyi', () {
    test('kamida bitta xizmat tayyor — Deyarli tayyor', () {
      final o = _order(1, OrderStatus.yuvishda, [
        _item('1', ItemStatus.tayyor),
        _item('2', ItemStatus.yuvilmoqda),
        _item('3', ItemStatus.qadoqlashda),
        _item('4', ItemStatus.navbatda),
      ]);
      expect(placeOf(o, BusinessPolicies.defaults, now), OrderPlace.almostReady);
    });

    test('hech biri tayyor emas — sexda', () {
      final o = _order(1, OrderStatus.yuvishda, [
        _item('1', ItemStatus.yuvilmoqda),
        _item('2', ItemStatus.qadoqlashda),
      ]);
      expect(placeOf(o, BusinessPolicies.defaults, now), OrderPlace.workshop);
    });

    test('tayyor xizmat topshirilgan, qolgani sexda — Deyarli tayyor EMAS', () {
      final o = _order(1, OrderStatus.yuvishda, [
        _item('1', ItemStatus.tayyor, handedAt: daysAgo(1)),
        _item('2', ItemStatus.yuvilmoqda),
      ]);
      expect(placeOf(o, BusinessPolicies.defaults, now), OrderPlace.workshop);
    });

    test('hammasi tayyor — 15 kun ichida Tayyor, keyin Omborda', () {
      final fresh = _order(1, OrderStatus.yetgazishgaTayyor,
          [_item('1', ItemStatus.tayyor)],
          readyAt: daysAgo(14));
      final old = _order(2, OrderStatus.yetgazishgaTayyor,
          [_item('1', ItemStatus.tayyor)],
          readyAt: daysAgo(15));
      expect(placeOf(fresh, BusinessPolicies.defaults, now), OrderPlace.ready);
      expect(placeOf(old, BusinessPolicies.defaults, now), OrderPlace.warehouse);
    });

    test('omborxona o\'chirilgan bo\'lsa hech qachon Omborda emas', () {
      final old = _order(2, OrderStatus.yetgazishgaTayyor,
          [_item('1', ItemStatus.tayyor)],
          readyAt: daysAgo(60));
      const off = BusinessPolicies(warehouseEnabled: false);
      expect(placeOf(old, off, now), OrderPlace.ready);
    });

    test('kunlar soni qoidadan olinadi', () {
      final o = _order(2, OrderStatus.yetgazishgaTayyor,
          [_item('1', ItemStatus.tayyor)],
          readyAt: daysAgo(5));
      expect(placeOf(o, const BusinessPolicies(warehouseDays: 5), now),
          OrderPlace.warehouse);
      expect(placeOf(o, const BusinessPolicies(warehouseDays: 6), now),
          OrderPlace.ready);
    });
  });

  group('bo\'limlar', () {
    test('har bir buyurtma o\'z bo\'limlarida', () {
      final orders = [
        _order(1, OrderStatus.olibKelish, [_item('1', ItemStatus.navbatda)]),
        _order(2, OrderStatus.yuvishda, [
          _item('1', ItemStatus.tayyor),
          _item('2', ItemStatus.qadoqlashda),
        ]),
        _order(3, OrderStatus.yuvishda, [
          _item('1', ItemStatus.navbatda, measured: false),
          _item('2', ItemStatus.yuvilmoqda),
        ]),
        _order(4, OrderStatus.yetgazishgaTayyor, [_item('1', ItemStatus.tayyor)],
            readyAt: daysAgo(1)),
        _order(5, OrderStatus.yetgazishgaTayyor, [_item('1', ItemStatus.tayyor)],
            readyAt: daysAgo(30)),
      ];
      final s = OrderSections.from(orders, now: now);

      expect(s.pickup.map((o) => o.id), [1]);
      expect(s.almostReady.map((o) => o.id), [2]);
      expect(s.packaging.map((o) => o.id), [2]);
      expect(s.wash.map((o) => o.id), [3],
          reason: 'olib kelinayotgan buyurtma sexda emas');
      expect(s.readyForDelivery.map((o) => o.id), [4]);
      expect(s.warehouse.map((o) => o.id), [5]);
      expect(s.unmeasured.map((r) => '${r.order.id}/${r.item.key}'), ['3/1']);
      expect(s.deliveryBadgeCount, 3);
    });

    test('xizmati yo\'q sexdagi buyurtma Yuvishda ko\'rinadi', () {
      final s = OrderSections.from(
        [_order(1, OrderStatus.yuvishda, const [])],
        now: now,
      );
      expect(s.wash.length, 1);
    });

    test('qayta yuvishga qaytgan xizmat Yuvishda', () {
      final s = OrderSections.from([
        _order(1, OrderStatus.yuvishda, [_item('1', ItemStatus.qaytaYuvildi)]),
      ], now: now);
      expect(s.wash.length, 1);
    });
  });

  group('buyurtma modeli', () {
    test('raqam № bilan', () {
      expect(_order(125, OrderStatus.yuvishda, const []).code, '№ 125');
    });

    test('oldindan to\'langan qismdan keyingi qoldiq', () {
      final o = Order(
        id: 1,
        customerName: '',
        customerPhone: '',
        address: '',
        deadline: null,
        deliveryType: DeliveryType.oziKeldi,
        status: OrderStatus.yuvishda,
        createdBy: '',
        createdByName: '',
        createdAt: 0,
        items: const [],
        totalPrice: 200000,
        comments: const [],
        prepaidAmount: 80000,
      );
      expect(o.remainingDue, 120000);
    });

    test('noma\'lum xizmat holati — Navbatda (xavfsiz tomon)', () {
      expect(ItemStatus.fromKey('kelajakdagi_holat'), ItemStatus.navbatda);
      expect(ItemStatus.fromKey('yuvilmoqda'), ItemStatus.yuvilmoqda);
    });
  });
}
