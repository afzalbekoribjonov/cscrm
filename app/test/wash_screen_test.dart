import 'package:cscrm/l10n/script.dart';
import 'package:cscrm/models/app_user.dart';
import 'package:cscrm/models/item_status.dart';
import 'package:cscrm/models/measure_unit.dart';
import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_item.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/models/staff_access.dart';
import 'package:cscrm/screens/orders/widgets/order_item_tile.dart';
import 'package:cscrm/screens/wash/wash_screen.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:cscrm/utils/order_sections.dart';
import 'package:cscrm/utils/wash_sort.dart';
import 'package:cscrm/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item(
  String key,
  ItemStatus status, {
  MeasureUnit? unit,
  double qty = 0,
}) =>
    OrderItem(
      key: key,
      itemId: 'x/$key',
      productId: 'p',
      productName: 'Gilam',
      hajm: unit == null ? '' : '$qty',
      price: unit == null ? 0 : qty * 10000,
      createdBy: '',
      status: status,
      comments: const [],
      unit: unit,
      quantity: qty,
    );

Order _order(
  int id,
  List<OrderItem> items, {
  int createdAt = 0,
  int? deadline,
  double total = 0,
}) =>
    Order(
      id: id,
      customerName: 'Mijoz $id',
      customerPhone: '998901234567',
      address: '',
      deadline: deadline,
      deliveryType: DeliveryType.oziKeldi,
      status: OrderStatus.yuvishda,
      createdBy: '',
      createdByName: '',
      createdAt: createdAt,
      items: items,
      totalPrice: total,
      comments: const [],
    );

/// Yuvish bo'limi tepasi: o'lchanmaganlar (qizil), jami hajm va
/// saralash (foydalanuvchi so'rovi, 2026-11-20).
void main() {
  group('saralash', () {
    final a = _order(1, [_item('1', ItemStatus.navbatda)],
        createdAt: 300, deadline: 5000, total: 100);
    final b = _order(2, [_item('1', ItemStatus.qaytaYuvildi)],
        createdAt: 200, deadline: 9000, total: 300);
    final c = _order(3, [_item('1', ItemStatus.yuvilmoqda)],
        createdAt: 100, total: 200);
    final d = _order(4, [_item('1', ItemStatus.navbatda)],
        createdAt: 400, deadline: 1000, total: 50);

    test('topshirish kuni: qayta yuvish tepada, keyin muddat, muddatsiz oxirida', () {
      expect(sortWashOrders([a, b, c, d], WashSort.deadline).map((o) => o.id),
          [2, 4, 1, 3]);
    });

    test('sana: eng eskisi birinchi', () {
      expect(sortWashOrders([a, b, c, d], WashSort.date).map((o) => o.id),
          [3, 2, 1, 4]);
    });

    test('qimmat va arzon', () {
      expect(sortWashOrders([a, b, c, d], WashSort.expensive).map((o) => o.id),
          [2, 3, 1, 4]);
      expect(sortWashOrders([a, b, c, d], WashSort.cheap).map((o) => o.id),
          [4, 1, 3, 2]);
    });

    test("kiruvchi ro'yxat o'zgarmaydi", () {
      final list = [a, b, c, d];
      sortWashOrders(list, WashSort.cheap);
      expect(list.map((o) => o.id), [1, 2, 3, 4]);
    });
  });

  test("jami hajm: faqat yuvish bosqichidagi o'lchanganlar", () {
    final v = washVolume([
      _order(1, [
        _item('1', ItemStatus.navbatda, unit: MeasureUnit.m2, qty: 6),
        _item('2', ItemStatus.yuvilmoqda, unit: MeasureUnit.m2, qty: 4.5),
        _item('3', ItemStatus.qadoqlashda, unit: MeasureUnit.m2, qty: 100),
        _item('4', ItemStatus.navbatda),
        _item('5', ItemStatus.qaytaYuvildi, unit: MeasureUnit.kichik, qty: 1),
      ]),
    ]);
    expect(v.of(MeasureUnit.m2), 10.5);
    expect(v.of(MeasureUnit.kichik), 1);
  });

  group('Yuvish sahifasi', () {
    final orders = [
      _order(10, [
        _item('1', ItemStatus.navbatda),
        _item('2', ItemStatus.navbatda, unit: MeasureUnit.m2, qty: 12),
      ], total: 500000),
      _order(11, [
        _item('1', ItemStatus.yuvilmoqda, unit: MeasureUnit.katta, qty: 1),
      ], total: 90000),
    ];
    final sections = OrderSections.from(orders);
    const user = AppUser(id: 'e1', name: 'Ali', access: StaffAccess.admin());

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: WashScreen(sections: sections, user: user),
      ));
    }

    testWidgets('tepada qizil "N ta" va aniq so\'zli hajm', (tester) async {
      await pump(tester);
      expect(find.text('1 ta'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('m²'), findsOneWidget);
      expect(find.text('katta'), findsOneWidget);
      // Eski katta qizil banner yo'q.
      expect(find.text(t('1 ta xizmat o\'lchanmagan')), findsNothing);
    });

    testWidgets('saralash tugmalari bitta qatorda', (tester) async {
      await pump(tester);
      for (final s in WashSort.values) {
        expect(find.text(s.label), findsOneWidget);
      }
    });

    testWidgets('"Arzon" bosilganda arzon buyurtma birinchi', (tester) async {
      await pump(tester);
      List<int> ids() => tester
          .widgetList<OrderCard>(find.byType(OrderCard))
          .map((c) => c.order.id)
          .toList();
      expect(ids().first, 10);
      await tester.tap(find.text('Arzon'));
      await tester.pump();
      expect(ids().first, 11);
    });
  });

  group('xizmat kartasi', () {
    Future<void> pumpTile(WidgetTester tester, ItemStatus status) =>
        tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: OrderItemTile(
              item: _item('1', status),
              permissions: const ItemPermissions(
                wash: true,
                measure: false,
                measureBeforeWash: true,
                measureBeforePackaging: true,
              ),
              onWash: () {},
              onAdvance: (_) {},
              onRewash: () {},
              onMeasure: () {},
              onDelete: () {},
              onComments: () {},
              onHistory: () {},
            ),
          ),
        ));

    testWidgets("\"o'lchang\" degan doimiy yozuv yo'q", (tester) async {
      await pumpTile(tester, ItemStatus.navbatda);
      expect(find.textContaining('Yuvishdan oldin'), findsNothing);
      await pumpTile(tester, ItemStatus.yuvilmoqda);
      expect(find.textContaining(t('o\'tkazishdan oldin')), findsNothing);
    });

    testWidgets("o'lchanmagan xizmatda tugma bosilsa — tushuntirish", (tester) async {
      await pumpTile(tester, ItemStatus.navbatda);
      await tester.tap(find.text('Yuvish'));
      await tester.pump();
      expect(find.text(t('Bu xizmat avval o\'lchanishi kerak.')), findsOneWidget);
    });
  });
}
