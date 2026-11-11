// Ekran rasmlari uchun NAMUNAVIY ma'lumot — bazaga ulanmaydi.
//
// Har bir bosqichdagi buyurtma bor: olib kelish, navbatda, yuvilmoqda,
// qadoqlashda, deyarli tayyor (bo'lib topshirilgani bilan), tayyor,
// omborda va bugun topshirilgan.

import 'package:cscrm/models/employee.dart';
import 'package:cscrm/models/expense.dart';
import 'package:cscrm/models/item_status.dart';
import 'package:cscrm/models/measure_unit.dart';
import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_history_entry.dart';
import 'package:cscrm/models/order_item.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/models/work_section.dart';
import 'package:cscrm/screens/dashboard/dashboard_sources.dart';

final sampleNow = DateTime.now();
int _ago({int days = 0, int hours = 0, int minutes = 0}) => sampleNow
    .subtract(Duration(days: days, hours: hours, minutes: minutes))
    .millisecondsSinceEpoch;
int _ahead(int days) => DateTime(sampleNow.year, sampleNow.month, sampleNow.day)
    .add(Duration(days: days))
    .millisecondsSinceEpoch;

OrderItem _item(
  int order,
  int n,
  String name,
  ItemStatus status, {
  double m2 = 0,
  int? handedAt,
  int? washStartedAt,
  String? rewash,
}) {
  final measured = m2 > 0;
  return OrderItem(
    key: '$n',
    itemId: '$order/$n',
    productId: 'p$n',
    productName: name,
    hajm: measured ? '${m2.toStringAsFixed(m2 % 1 == 0 ? 0 : 1)} m²' : '',
    price: measured ? m2 * 12000 : 0,
    createdBy: 'e1',
    status: status,
    comments: const [],
    unit: measured ? MeasureUnit.m2 : null,
    quantity: m2,
    handedAt: handedAt,
    handedByName: handedAt == null ? '' : 'Sardor',
    washStartedAt: washStartedAt,
    rewashReason: rewash,
  );
}

Order _order(
  int id,
  String name,
  String address,
  OrderStatus status,
  List<OrderItem> items, {
  int? deadline,
  int? readyAt,
  int? deliveredAt,
  double prepaid = 0,
  int? createdAt,
  bool gps = false,
}) {
  final total = items.fold<double>(0, (s, i) => s + i.price);
  return Order(
    id: id,
    customerName: name,
    customerPhone: '99890${(1234567 + id * 7919) % 10000000}'.padRight(12, '0'),
    address: address,
    deadline: deadline,
    deliveryType: DeliveryType.olibKelish,
    status: status,
    createdBy: 'e1',
    createdByName: 'Malika',
    createdAt: createdAt ?? _ago(days: 2, hours: id % 7),
    items: items,
    totalPrice: total,
    comments: const [],
    ready: readyAt == null
        ? null
        : ActorStamp(at: readyAt, employeeId: 'e2', name: 'Jasur'),
    delivered: deliveredAt == null
        ? null
        : ActorStamp(at: deliveredAt, employeeId: 'e3', name: 'Sardor'),
    paymentMethod: deliveredAt == null ? null : 'Naqd pul',
    paymentAmount: deliveredAt == null ? null : total,
    deliveryPaidAmount: deliveredAt == null ? null : total,
    prepaidAmount: prepaid,
    pickupLat: gps ? 40.38 : null,
    pickupLng: gps ? 71.78 : null,
  );
}

final sampleOrders = <Order>[
  _order(1281, 'Nodira opa', 'Beshariq, Ishonch ko\'chasi 12', OrderStatus.olibKelish,
      [_item(1281, 1, 'Gilam', ItemStatus.navbatda)],
      deadline: _ahead(3), createdAt: _ago(hours: 2)),
  _order(1282, 'Sardor Aliyev', 'Chilonzor 9-kvartal, 14-uy', OrderStatus.yuvishda, [
    _item(1282, 1, 'Gilam', ItemStatus.navbatda, m2: 6),
    _item(1282, 2, 'Palos', ItemStatus.navbatda),
    _item(1282, 3, 'Adyol', ItemStatus.yuvilmoqda, m2: 3.5, washStartedAt: _ago(minutes: 42)),
  ], deadline: _ahead(1), createdAt: _ago(hours: 5)),
  _order(1283, 'Malika Karimova', 'Yunusobod 4-mavze', OrderStatus.yuvishda, [
    _item(1283, 1, 'Gilam', ItemStatus.tayyor, m2: 8),
    _item(1283, 2, 'Gilam', ItemStatus.tayyor, m2: 6, handedAt: _ago(hours: 20)),
    _item(1283, 3, 'Ko\'rpa', ItemStatus.qadoqlashda, m2: 2.4),
    _item(1283, 4, 'Parda', ItemStatus.yuvilmoqda, washStartedAt: _ago(hours: 1, minutes: 10)),
  ], deadline: _ahead(0), prepaid: 72000, gps: true),
  _order(1284, 'Otabek', 'Farg\'ona, Mustaqillik 5', OrderStatus.yuvishda, [
    _item(1284, 1, 'Gilam', ItemStatus.qaytaYuvildi, m2: 12, rewash: 'Dog\' ketmagan'),
    _item(1284, 2, 'Gilam', ItemStatus.qadoqlashda, m2: 9),
  ], deadline: _ahead(-2)),
  _order(1285, 'Dilnoza', 'Marg\'ilon, Bozor yonida', OrderStatus.yetgazishgaTayyor, [
    _item(1285, 1, 'Gilam', ItemStatus.tayyor, m2: 10),
    _item(1285, 2, 'Palos', ItemStatus.tayyor, m2: 4),
  ], deadline: _ahead(2), readyAt: _ago(days: 1), gps: true),
  _order(1286, 'Shahnoza', 'Qo\'qon, Navoiy 8', OrderStatus.yetgazishgaTayyor, [
    _item(1286, 1, 'Gilam', ItemStatus.tayyor, m2: 15),
  ], readyAt: _ago(days: 19)),
  _order(1270, 'Jamshid', 'Toshloq', OrderStatus.yetgazildi, [
    _item(1270, 1, 'Gilam', ItemStatus.tayyor, m2: 7, handedAt: _ago(hours: 3)),
  ], deliveredAt: _ago(hours: 3)),
];

final sampleEmployees = [
  for (final (id, first, last) in const [
    ('e1', 'Malika', 'Yusupova'),
    ('e2', 'Jasur', 'Toshmatov'),
    ('e3', 'Sardor', 'Aliyev'),
  ])
    Employee(
      id: id,
      firstName: first,
      lastName: last,
      phone: '99890000000$id',
      active: true,
      createdAt: 0,
      createdBy: 'owner',
      sections: WorkSection.values.toSet(),
    ),
];

OrderHistoryEntry _h(String key, int order, String type, String by, String name,
        int at,
        {String? from, String? to, double? q, double? amount, String? method}) =>
    OrderHistoryEntry(
      key: key,
      orderId: order,
      type: type,
      byEmployeeId: by,
      byName: name,
      at: at,
      fromStatus: from,
      toStatus: to,
      itemProductName: 'Gilam',
      itemKey: '1',
      quantity: q,
      unit: q == null ? null : MeasureUnit.m2,
      amount: amount,
      method: method,
    );

final sampleHistory = <OrderHistoryEntry>[
  for (var i = 0; i < 6; i++)
    _h('w$i', 1283, 'item_status_changed', 'e2', 'Jasur Toshmatov',
        _ago(hours: i + 1),
        from: 'yuvilmoqda', to: 'qadoqlashda', q: 6.0 + i),
  for (var i = 0; i < 4; i++)
    _h('p$i', 1285, 'item_status_changed', 'e1', 'Malika Yusupova',
        _ago(hours: i, minutes: 30),
        from: 'qadoqlashda', to: 'tayyor', q: 5.0 + i),
  _h('c1', 1282, 'order_created', 'e1', 'Malika Yusupova', _ago(hours: 5)),
  _h('c2', 1281, 'order_created', 'e1', 'Malika Yusupova', _ago(hours: 2)),
  _h('u1', 1283, 'status_changed', 'e3', 'Sardor Aliyev', _ago(hours: 4),
      from: 'olib_kelish', to: 'yuvishda'),
  _h('pd', 1283, 'partial_delivery', 'e3', 'Sardor Aliyev', _ago(hours: 2),
      amount: 72000, method: 'Karta'),
];

final sampleExpenses = <Expense>[
  Expense(
    id: 'x1',
    title: 'Kimyo vositalari',
    amount: 180000,
    spentAt: _ago(hours: 3),
    note: '',
    createdBy: 'owner',
    createdByName: 'Boshqaruvchi',
    createdAt: _ago(hours: 3),
  ),
];

class SampleDashboardSources implements DashboardSources {
  @override
  Stream<List<OrderHistoryEntry>> history(DateTime from, DateTime to) =>
      Stream.value(sampleHistory);

  @override
  Stream<List<Order>> delivered(DateTime from, DateTime to) => Stream.value(
      sampleOrders.where((o) => o.status == OrderStatus.yetgazildi).toList());

  @override
  Stream<List<Expense>> expenses(DateTime from, DateTime to) =>
      Stream.value(sampleExpenses);

  @override
  Stream<List<Order>> debtors() => Stream.value(const []);

  @override
  Stream<List<Employee>> employees() => Stream.value(sampleEmployees);
}
