import 'package:cscrm/models/measure_unit.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/models/pending_order.dart';
import 'package:cscrm/services/order_service.dart';
import 'package:cscrm/services/pending_order_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yuborilmagan buyurtmalar navbati.
///
/// Bu sinovlar MA'LUMOT YO'QOLMASLIGINI qo'riqlaydi: internetsiz
/// yozilgan buyurtma ilova yopilib qayta ochilsa ham joyida turishi
/// kerak. Yo'qolsa, xodim uni qog'ozdan qayta tiklay olmaydi.

PendingOrder order({
  String localId = 'a1',
  int createdAt = 1000,
  String name = 'Nodira',
  int? assigned,
}) =>
    PendingOrder(
      localId: localId,
      createdAt: createdAt,
      customerName: name,
      customerPhone: '998901234567',
      address: 'Chilonzor 9',
      deadline: 2000,
      deliveryType: DeliveryType.olibKelish,
      items: const [
        NewOrderItemDraft(
          productId: 'p1',
          productName: 'Gilam yuvish',
          hajm: '12 m²',
          price: 216000,
          unit: MeasureUnit.m2,
          quantity: 12,
        ),
      ],
      createdBy: 'emp1',
      createdByName: 'Sardor',
      comment: 'Tez kerak',
      assignedOrderId: assigned,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('yozuv diskka tushadi va qayta o\'qiladi', () async {
    final store = PendingOrderStore();
    await store.add(order());

    // Yangi nusxa — ilova qayta ochilgandek.
    final fresh = PendingOrderStore();
    await fresh.load();
    final reloaded = fresh.orders.value.single;

    expect(reloaded.customerName, 'Nodira');
    expect(reloaded.items.single.productName, 'Gilam yuvish');
    expect(reloaded.items.single.unit, MeasureUnit.m2);
    expect(reloaded.deliveryType, DeliveryType.olibKelish);
    expect(reloaded.comment, 'Tez kerak');
  });

  test('barcha maydonlar saqlanadi va qaytadi', () async {
    final original = order(assigned: 57);
    final restored = PendingOrder.decode(original.encode());

    expect(restored.localId, original.localId);
    expect(restored.createdAt, original.createdAt);
    expect(restored.customerPhone, original.customerPhone);
    expect(restored.address, original.address);
    expect(restored.deadline, original.deadline);
    expect(restored.createdBy, original.createdBy);
    expect(restored.createdByName, original.createdByName);
    expect(restored.assignedOrderId, 57);
    expect(restored.items.single.quantity, 12);
    expect(restored.items.single.price, 216000);
  });

  test('tartib yaratilish vaqti bo\'yicha saqlanadi', () async {
    final store = PendingOrderStore();

    await store.add(order(localId: 'b', createdAt: 200));
    await store.add(order(localId: 'a', createdAt: 100));

    // Qo'shilish tartibi — navbat tartibi. Raqamlar ham shu
    // ketma-ketlikda beriladi.
    expect(store.orders.value.map((o) => o.localId), ['b', 'a']);
  });

  test('raqam yozuvga yoziladi', () async {
    final store = PendingOrderStore();
    await store.add(order(localId: 'x'));

    await store.assignOrderId('x', 42);

    expect(store.orders.value.single.assignedOrderId, 42);
  });

  test('yuborilgach navbatdan chiqadi', () async {
    final store = PendingOrderStore();
    await store.add(order(localId: 'x'));
    await store.add(order(localId: 'y'));

    await store.remove('x');

    expect(store.orders.value.map((o) => o.localId), ['y']);
  });

  test('chiqishda navbat tozalanadi', () async {
    final store = PendingOrderStore();
    await store.add(order());

    await store.clear();

    expect(store.orders.value, isEmpty);
  });

  test('mahalliy kalitlar takrorlanmaydi', () {
    // Bir soniyada bir nechta buyurtma yaratilishi mumkin — kalitlar
    // to'qnashsa, biri ikkinchisini navbatdan o'chirib yuborardi.
    final ids = {for (var i = 0; i < 500; i++) PendingOrderStore.newLocalId()};
    expect(ids.length, 500);
  });

  test('buzuq yozuv qolganlarini to\'xtatmaydi', () async {
    // Bitta yozuv buzilgan bo'lsa (masalan ilova yangilanishida
    // format o'zgargan), qolgan buyurtmalar baribir yuborilishi
    // kerak — aks holda bitta buzuq yozuv butun navbatni
    // to'xtatib qo'yardi.
    SharedPreferences.setMockInitialValues({
      'pending_orders': ['{buzuq', order(localId: 'ok').encode()],
    });

    final store = PendingOrderStore();
    await store.load();

    expect(store.orders.value.map((o) => o.localId), ['ok']);
  });

  test('diskdagi navbat ilova qayta ochilganda tiklanadi', () async {
    SharedPreferences.setMockInitialValues({
      'pending_orders': [
        order(localId: 'b', createdAt: 200).encode(),
        order(localId: 'a', createdAt: 100).encode(),
      ],
    });

    final store = PendingOrderStore();
    await store.load();

    expect(
      store.orders.value.map((o) => o.localId),
      ['a', 'b'],
      reason: 'tiklanganda vaqt bo\'yicha tartiblanadi',
    );
  });
}
