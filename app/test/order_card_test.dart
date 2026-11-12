import 'package:cscrm/models/app_user.dart';
import 'package:cscrm/models/item_status.dart';
import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_item.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/models/staff_access.dart';
import 'package:cscrm/models/work_section.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:cscrm/widgets/order_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item(String key, String name, ItemStatus status) => OrderItem(
      key: key,
      itemId: '1/$key',
      productId: 'p',
      productName: name,
      hajm: '',
      price: 0,
      createdBy: '',
      status: status,
      comments: const [],
    );

/// Ro'yxatdagi buyurtma kartasi xizmatlarni NOMI bilan emas, faqat
/// belgi va SON bilan ko'rsatadi — kartalar bir xil balandlikda bo'lishi
/// uchun (foydalanuvchi so'rovi, 2026-11-12).
void main() {
  final order = Order(
    id: 77,
    customerName: 'Nodira',
    customerPhone: '998901234567',
    address: 'Chilonzor',
    deadline: null,
    deliveryType: DeliveryType.oziKeldi,
    status: OrderStatus.yuvishda,
    createdBy: '',
    createdByName: '',
    createdAt: 0,
    items: [
      _item('1', 'Gilam', ItemStatus.navbatda),
      _item('2', 'Gilam', ItemStatus.navbatda),
      _item('3', 'Palos', ItemStatus.qadoqlashda),
    ],
    totalPrice: 0,
    comments: const [],
  );

  Future<void> pump(WidgetTester tester, WorkSection? section) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: OrderCard(
            order: order,
            section: section,
            user: const AppUser(id: 'u', name: 'U', access: StaffAccess.admin()),
          ),
        ),
      ));

  for (final section in [WorkSection.yuvish, WorkSection.qadoqlash, null]) {
    testWidgets('xizmat nomlari kartada chiqmaydi (${section?.key ?? 'umumiy'})',
        (tester) async {
      await pump(tester, section);
      expect(find.text('Gilam'), findsNothing);
      expect(find.text('Palos'), findsNothing);
      // Navbatda — 2 ta, qadoqlashda — 1 ta.
      expect(find.text('2'), findsWidgets);
      expect(find.text('1'), findsWidgets);
    });
  }

  testWidgets('Yuvishda o\'lchanmaganlar soni alohida belgi bilan',
      (tester) async {
    await pump(tester, WorkSection.yuvish);
    // Navbatdagi 2 ta xizmat o'lchanmagan.
    expect(find.byIcon(Icons.straighten_rounded), findsOneWidget);
  });

  testWidgets('boshqa bo\'limda o\'lchanmagan belgisi yo\'q', (tester) async {
    await pump(tester, WorkSection.qadoqlash);
    expect(find.byIcon(Icons.straighten_rounded), findsNothing);
  });
}
