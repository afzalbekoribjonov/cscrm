import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/pending_order.dart';
import 'order_service.dart';
import 'pending_order_store.dart';

/// Navbatning hozirgi holati — ekrandagi belgi shunga qarab chiziladi.
enum SyncState {
  /// Hammasi yuborilgan.
  idle,

  /// Yuborilmoqda yoki navbatda yozuv bor.
  pending,

  /// Aloqa yo'q, navbatda yozuv bor.
  offline,
}

/// Yuborilmagan buyurtmalarni serverga jo'natadi.
///
/// ISHLASH TARTIBI. Buyurtma HAR DOIM avval navbatga tushadi — aloqa
/// bor-yo'qligidan qat'i nazar. Aloqa bo'lsa u bir soniyada
/// yuboriladi va foydalanuvchi buni sezmaydi ham.
///
/// Nega ikki xil yo'l qilinmagan ("onlayn bo'lsa to'g'ridan-to'g'ri,
/// aks holda navbatga"): ikki yo'l ikki xil xatolikka olib keladi va
/// ulardan biri kamdan-kam ishlatilgani uchun sinovdan ham chetda
/// qoladi. Bitta yo'l — bitta xulq.
///
/// Navbat KETMA-KET bo'shatiladi: har bir buyurtma o'z raqamini
/// oladi, ular yaratilish tartibida beriladi.
class OrderSyncService {
  /// Konstruktor OCHIQ — sinovda soxta yozuvchi va soxta ulanish
  /// oqimi bilan ishlatiladi. Ilovada esa yagona nusxa ([instance])
  /// ishlatiladi: navbat butun ilovada bitta bo'lishi shart.
  OrderSyncService({PendingOrderStore? store})
      : _store = store ?? PendingOrderStore.instance;

  static final OrderSyncService instance = OrderSyncService();

  final PendingOrderStore _store;

  /// Ekranlar shunga obuna bo'ladi.
  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);

  StreamSubscription<bool>? _connectionSub;
  OrderWriter? _orders;

  var _online = false;
  var _draining = false;

  /// Hozir navbat bo'shatilmoqdami — sinov shuni kutadi.
  @visibleForTesting
  bool get draining => _draining;

  /// Tizimga kirgandan keyin chaqiriladi.
  ///
  /// [orders] va [connection] sinovda almashtiriladi. Ilovada
  /// ikkalasi ham `null`: yozuvchi `OrderService`, ulanish esa
  /// Firebase'ning `.info/connected` xizmat tuguni bo'ladi.
  Future<void> start({
    OrderWriter? orders,
    Stream<bool>? connection,
  }) async {
    _orders = orders ?? OrderService();
    await _store.load();

    // Eski tinglovchi avval olib tashlanadi.
    //
    // `start()` bir necha marta chaqirilishi mumkin: ilova qayta
    // ochilganda, foydalanuvchi almashganda yoki ishlab chiqishda hot
    // restart bo'lganda. Har safar yangi tinglovchi qo'shilsa, bitta
    // o'zgarish bir necha marta qayta ishlanardi.
    _store.orders
      ..removeListener(_onQueueChanged)
      ..addListener(_onQueueChanged);
    _onQueueChanged();

    await _connectionSub?.cancel();
    _connectionSub = (connection ?? _firebaseConnection()).listen((online) {
      _online = online;
      _onQueueChanged();
      if (online) unawaited(drain());
    });
  }

  Stream<bool> _firebaseConnection() => FirebaseDatabase.instance
      .ref('.info/connected')
      .onValue
      .map((event) => event.snapshot.value == true);

  /// Chiqishda: navbat keyingi foydalanuvchiga o'tib ketmasin.
  Future<void> stop() async {
    await _connectionSub?.cancel();
    _connectionSub = null;
    _store.orders.removeListener(_onQueueChanged);
    _online = false;
    await _store.clear();
    state.value = SyncState.idle;
  }

  void _onQueueChanged() {
    final empty = _store.orders.value.isEmpty;
    state.value = empty
        ? SyncState.idle
        : (_online ? SyncState.pending : SyncState.offline);
  }

  /// Buyurtmani navbatga qo'yadi va (aloqa bo'lsa) darhol yuboradi.
  Future<PendingOrder> enqueue(PendingOrder order) async {
    final saved = await _store.add(order);
    if (_online) unawaited(drain());
    return saved;
  }

  /// Navbatni bo'shatadi.
  ///
  /// Bir vaqtda faqat bitta bo'shatish ketadi ([_draining]): ikkitasi
  /// birga ishlasa, bitta buyurtma ikki marta yuborilib, ikkita raqam
  /// olib qolardi.
  @visibleForTesting
  Future<void> drain() async {
    if (_draining || !_online) return;
    _draining = true;

    try {
      while (_online) {
        final queue = _store.orders.value;
        if (queue.isEmpty) break;

        final next = queue.first;
        final sent = await _send(next);
        if (!sent) break; // Aloqa uzildi — keyinroq davom etamiz.
        await _store.remove(next.localId);
      }
    } finally {
      _draining = false;
      _onQueueChanged();
    }
  }

  /// Bitta buyurtmani yuboradi. `false` — hozir bo'lmadi, keyin.
  Future<bool> _send(PendingOrder order) async {
    final orders = _orders;
    if (orders == null) return false;

    try {
      var orderId = order.assignedOrderId;

      if (orderId == null) {
        orderId = await orders.allocateOrderId();
        // Raqam yozuvga DARHOL saqlanadi.
        //
        // Ilova aynan shu yerda — raqam olingan, lekin buyurtma hali
        // yozilmagan paytda — yopilib qolsa, keyingi urinishda yangi
        // raqam olinardi. Bundan ham yomoni: buyurtma yozilib
        // ulgurgan bo'lsa, ikkinchi nusxasi paydo bo'lardi.
        await _store.assignOrderId(order.localId, orderId);
      } else if (await orders.exists(orderId)) {
        // Oldingi urinishda yozilib ulgurgan — takrorlamaymiz.
        return true;
      }

      await orders.writeOrder(
        orderId: orderId,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        address: order.address,
        deadline: order.deadline == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(order.deadline!),
        deliveryType: order.deliveryType,
        items: order.items,
        createdBy: order.createdBy,
        createdByName: order.createdByName,
        comment: order.comment,
        createdAt: order.createdAt,
      );
      return true;
    } catch (e) {
      debugPrint('Navbatdagi buyurtmani yuborib bo\'lmadi: $e');
      return false;
    }
  }
}
