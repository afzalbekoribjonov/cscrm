import 'dart:async';

import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/models/pending_order.dart';
import 'package:cscrm/services/order_service.dart';
import 'package:cscrm/services/order_sync_service.dart';
import 'package:cscrm/services/pending_order_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Navbatni bo'shatish mantig'i.
///
/// Bu yerdagi eng jiddiy xavf — BUYURTMANING IKKI MARTA yozilishi.
/// U shu tarzda yuzaga keladi: raqam serverdan olindi, buyurtma
/// yozildi, lekin navbatdan o'chirilmasdan ilova yopilib qoldi.
/// Keyingi ochilishda o'sha yozuv yana yuboriladi. Mijozda bitta
/// gilam, bazada ikkita buyurtma.

PendingOrder order({
  required String localId,
  int createdAt = 1000,
  int? assigned,
}) =>
    PendingOrder(
      localId: localId,
      createdAt: createdAt,
      customerName: 'Mijoz $localId',
      customerPhone: '998901234567',
      address: '',
      deadline: null,
      deliveryType: DeliveryType.oziKeldi,
      items: const [],
      createdBy: 'emp1',
      createdByName: 'Sardor',
      comment: '',
      assignedOrderId: assigned,
    );

/// Serverga chiqmaydigan soxta yozuvchi.
class _FakeWriter implements OrderWriter {
  _FakeWriter({
    this.existing = const {},
    this.failAfter,
    this.failWrite = false,
  });

  /// Bazada allaqachon bor raqamlar.
  Set<int> existing;

  /// Nechta muvaffaqiyatli yozuvdan keyin raqam olishda xatolik bersin.
  final int? failAfter;

  /// Raqam olinadi, lekin YOZUV yiqiladi.
  final bool failWrite;

  int nextId = 100;
  final allocated = <int>[];
  final written = <int>[];

  @override
  Future<int> allocateOrderId() async {
    if (failAfter != null && written.length >= failAfter!) {
      throw StateError('aloqa uzildi');
    }
    final id = nextId++;
    allocated.add(id);
    return id;
  }

  @override
  Future<bool> exists(int orderId) async => existing.contains(orderId);

  @override
  Future<void> writeOrder({
    required int orderId,
    required String customerName,
    required String customerPhone,
    String address = '',
    DateTime? deadline,
    required DeliveryType deliveryType,
    required List<NewOrderItemDraft> items,
    required String createdBy,
    required String createdByName,
    String? comment,
    int? createdAt,
  }) async {
    if (failWrite) throw StateError('yozuv yiqildi');
    written.add(orderId);
    existing = {...existing, orderId};
  }
}

/// Sinovdan boshqariladigan ulanish holati.
class _Connection {
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get stream => _controller.stream;

  Future<void> set(bool online) async {
    _controller.add(online);
    // Tinglovchi xabarni olishi uchun bitta navbat aylanishi kerak.
    await Future<void>.delayed(Duration.zero);
  }

  void dispose() => _controller.close();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Har bir sinovga toza navbat va toza xizmat.
  Future<(OrderSyncService, PendingOrderStore, _FakeWriter, _Connection)>
      build({_FakeWriter? writer}) async {
    final store = PendingOrderStore();
    final sync = OrderSyncService(store: store);
    final fake = writer ?? _FakeWriter();
    final connection = _Connection();

    await sync.start(orders: fake, connection: connection.stream);
    addTearDown(connection.dispose);
    return (sync, store, fake, connection);
  }

  /// Bo'shatish tugashini kutadi.
  Future<void> settle(OrderSyncService sync) async {
    for (var i = 0; i < 100 && sync.draining; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await Future<void>.delayed(Duration.zero);
  }

  test('aloqa yo\'qda buyurtma navbatda qoladi', () async {
    final (sync, store, fake, _) = await build();

    await sync.enqueue(order(localId: 'a'));
    await settle(sync);

    expect(fake.written, isEmpty, reason: 'aloqa yo\'q — yuborilmasligi kerak');
    expect(store.orders.value, hasLength(1));
    expect(sync.state.value, SyncState.offline);
  });

  test('aloqa tiklanganda navbat o\'zi bo\'shaydi', () async {
    final (sync, store, fake, connection) = await build();

    await sync.enqueue(order(localId: 'a'));
    await sync.enqueue(order(localId: 'b'));
    await connection.set(true);
    await settle(sync);

    expect(fake.written, [100, 101]);
    expect(store.orders.value, isEmpty);
    expect(sync.state.value, SyncState.idle);
  });

  test('raqamlar YARATILISH tartibida beriladi', () async {
    final (sync, _, fake, connection) = await build();

    await sync.enqueue(order(localId: 'birinchi', createdAt: 100));
    await sync.enqueue(order(localId: 'ikkinchi', createdAt: 200));
    await connection.set(true);
    await settle(sync);

    expect(fake.allocated, [100, 101]);
  });

  test('ALLAQACHON yozilgan buyurtma IKKINCHI marta yozilmaydi', () async {
    // Eng muhim sinov: raqam olingan va buyurtma yozilgan, lekin
    // navbatdan o'chirilmasdan ilova yopilgan holat.
    final fake = _FakeWriter(existing: {57});
    final (sync, store, _, connection) = await build(writer: fake);

    await sync.enqueue(order(localId: 'a', assigned: 57));
    await connection.set(true);
    await settle(sync);

    expect(fake.written, isEmpty, reason: 'buyurtma allaqachon bazada');
    expect(fake.allocated, isEmpty, reason: 'yangi raqam olinmasligi kerak');
    expect(store.orders.value, isEmpty, reason: 'navbatdan chiqarilishi kerak');
  });

  test('raqami bor, lekin yozilmagan buyurtma AYNAN o\'sha raqam bilan '
      'yoziladi', () async {
    // Raqam olingan, lekin yozuv ulgurmagan holat. Yangi raqam
    // olinsa, eskisi bo'sh qolardi.
    final (sync, _, fake, connection) = await build();

    await sync.enqueue(order(localId: 'a', assigned: 57));
    await connection.set(true);
    await settle(sync);

    expect(fake.written, [57]);
    expect(fake.allocated, isEmpty);
  });

  test('raqam YOZUVDAN OLDIN navbatga saqlanadi', () async {
    // Shu bir qadam tufayli yuqoridagi ikki holat farqlanadi.
    // Raqam olinib, yozuv yiqilgan holatni yasaymiz: navbatda qolgan
    // yozuvda raqam turgan bo'lishi kerak.
    final fake = _FakeWriter(failWrite: true);
    final (sync, store, _, connection) = await build(writer: fake);

    await sync.enqueue(order(localId: 'a'));
    await connection.set(true);
    await settle(sync);

    expect(fake.allocated, [100]);
    expect(
      store.orders.value.single.assignedOrderId,
      100,
      reason: 'raqam saqlanmasa, keyingi urinishda yangisi olinardi va '
          'buyurtma ikki marta yozilib qolishi mumkin edi',
    );
  });

  test('bittasi yiqilsa qolganlari navbatda qoladi', () async {
    final fake = _FakeWriter(failAfter: 1);
    final (sync, store, _, connection) = await build(writer: fake);

    await sync.enqueue(order(localId: 'a'));
    await sync.enqueue(order(localId: 'b'));
    await connection.set(true);
    await settle(sync);

    expect(fake.written, hasLength(1));
    expect(
      store.orders.value.map((o) => o.localId),
      ['b'],
      reason: 'yiqilgan buyurtma emas, KEYINGISI navbatda qolishi kerak',
    );
  });

  test('chiqishda navbat tozalanadi', () async {
    final (sync, store, _, _) = await build();

    await sync.enqueue(order(localId: 'a'));
    await sync.stop();

    expect(store.orders.value, isEmpty);
    expect(sync.state.value, SyncState.idle);
  });
}
