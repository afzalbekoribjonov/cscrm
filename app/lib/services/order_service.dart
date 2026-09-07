import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/item_status.dart';
import '../models/measure_unit.dart';
import '../models/order.dart';
import '../models/order_history_entry.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../utils/combine_streams.dart';
import '../utils/date_utils.dart';
import '../utils/firebase_map.dart';
import '../utils/offline_write.dart';
import '../utils/order_totals.dart';
import '../utils/phone.dart';
import 'tenant_scope.dart';

/// Hisoblash bosqichida tayyorlangan, alohida jismoniy birlikka aylantirilgan
/// mahsulot — hali Firebase'ga yozilmagan, faqat qurilmada.
class NewOrderItemDraft {
  const NewOrderItemDraft({
    required this.productId,
    required this.productName,
    required this.hajm,
    required this.price,
    this.unit,
    this.quantity = 0,
  });

  final String productId;
  final String productName;
  final String hajm;
  final double price;

  /// Statistika uchun raqamli o'lchov - o'lchanmagan xizmatda null/0.
  final MeasureUnit? unit;
  final double quantity;

  Map<String, Object?> toFirebase({
    required String itemId,
    required String createdBy,
  }) =>
      {
        'itemId': itemId,
        'productId': productId,
        'productName': productName,
        'hajm': hajm,
        'price': price,
        'createdBy': createdBy,
        'status': ItemStatus.yuvilmoqda.key,
        if (unit != null) 'unit': unit!.key,
        if (quantity > 0) 'quantity': quantity,
      };
}

class OrderService {
  OrderService({TenantScope? scope}) : _scope = scope ?? TenantScope.current;

  /// Barcha yo'llar shu doiradan o'tadi - `/tenants/{tenantId}/...`.
  final TenantScope _scope;

  /// Bir vaqtda ochiq turadigan buyurtmalar soni uchun yuqori chegara.
  ///
  /// Operatsion ekranlar faqat FAOL buyurtmalarni ko'rsatadi, ular esa
  /// odatda o'nlab bo'ladi. Chegara shunchaki himoya - ma'lumot buzilib,
  /// minglab yozuv "faol" bo'lib qolsa ham ilova qotib qolmaydi.
  static const _activeLimit = 500;

  /// Bitta buyurtmani jonli kuzatadi - to'liq ko'rinish (OrderDetailScreen)
  /// shu orqali doim eng so'nggi ma'lumotni ko'rsatadi, statik nusxa bilan
  /// ishlash oqibatida kelib chiqadigan "eskirgan holat" muammosi bo'lmaydi.
  Stream<Order?> streamOrder(int orderId) {
    return _scope.ref('orders/$orderId').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      try {
        return Order.fromMap('$orderId', raw);
      } catch (e, st) {
        debugPrint('Buyurtmani o\'qib bo\'lmadi ($orderId): $e\n$st');
        return null;
      }
    });
  }

  // -------------------------------------------------------------------
  // Tarix
  // -------------------------------------------------------------------

  /// Tarix yozuvi uchun yangi kalit.
  String _newHistoryKey() => _scope.ref('order_history').push().key!;

  /// Tarix yozuvini tayyorlaydi.
  ///
  /// Yozuv buyurtma tugunida EMAS, alohida `order_history` tugunida
  /// saqlanadi — sabab: RTDB so'rovi buyurtmaning butun daraxtini
  /// qaytaradi va ro'yxat ekranlari tarixni ham yuklab olardi.
  Map<String, Object?> _historyEntry(
    int orderId,
    Map<String, Object?> fields,
  ) =>
      {'orderId': orderId, ...fields};

  /// "Kim va qachon" belgisi — buyurtmaning o'zida saqlanadi.
  ///
  /// Bildirishnomalar va statistika shu maydonlardan foydalanadi, shuning
  /// uchun ular uchun butun tarixni yuklash kerak emas.
  Map<String, Object?> _stamp(
    String prefix, {
    required String byEmployeeId,
    required String byName,
    String? note,
  }) =>
      {
        '${prefix}At': ServerValue.timestamp,
        '${prefix}By': byEmployeeId,
        '${prefix}ByName': byName,
        if (note != null && note.isNotEmpty) '${prefix}Note': note,
      };

  /// Har qanday o'zgarishda yangilanadi — ovozli signal "buni men
  /// qildimmi" degan savolga shu orqali javob topadi.
  Map<String, Object?> _lastAction(String byEmployeeId) => {
        'lastActionAt': ServerValue.timestamp,
        'lastActionBy': byEmployeeId,
      };

  /// Bitta buyurtmaning to'liq tarixi — faqat buyurtma kartasi ochilganda.
  Stream<List<OrderHistoryEntry>> streamOrderHistory(int orderId) {
    return _scope
        .ref('order_history')
        .orderByChild('orderId')
        .equalTo(orderId)
        .onValue
        .map((event) => _parseHistory(event.snapshot));
  }

  /// Davr ichidagi barcha tarix yozuvlari — hisobot ekranlari uchun
  /// (yuvish hajmi, xodim faolligi).
  Stream<List<OrderHistoryEntry>> streamHistoryBetween(
    DateTime from,
    DateTime to,
  ) {
    return _scope
        .ref('order_history')
        .orderByChild('at')
        .startAt(from.millisecondsSinceEpoch)
        .endAt(to.millisecondsSinceEpoch)
        .onValue
        .map((event) => _parseHistory(event.snapshot));
  }

  List<OrderHistoryEntry> _parseHistory(DataSnapshot snapshot) {
    final raw = asFirebaseMap(snapshot.value);
    final entries = <OrderHistoryEntry>[];
    for (final e in raw.entries) {
      if (e.value is! Map) continue;
      try {
        entries.add(OrderHistoryEntry.fromMap(e.key, e.value as Map));
      } catch (err) {
        debugPrint('Tarix yozuvi o\'qilmadi (${e.key}): $err');
      }
    }
    entries.sort((a, b) => a.at.compareTo(b.at));
    return entries;
  }

  /// Snapshot'ni buyurtmalar ro'yxatiga aylantiradi.
  ///
  /// Bitta buzilgan yozuv butun ro'yxatni yo'qotmasligi kerak - shu yozuv
  /// o'tkazib yuboriladi, qolganlari ko'rsatiladi.
  List<Order> _parse(DataSnapshot snapshot) {
    final raw = asFirebaseMap(snapshot.value);
    final orders = <Order>[];
    for (final entry in raw.entries) {
      if (entry.value is! Map) continue;
      try {
        orders.add(Order.fromMap(entry.key, entry.value as Map));
      } catch (e, st) {
        debugPrint('Buyurtmani o\'qib bo\'lmadi (${entry.key}): $e\n$st');
      }
    }
    orders.sort(_byDeadlineThenNewest);
    return orders;
  }

  /// FAOL buyurtmalar - operatsion ekranlar (Yangi/Yuvish/Qadoqlash/
  /// Yetgazma) shu oqimdan oziqlanadi.
  ///
  /// NEGA MUHIM: ilgari bu yerda butun `orders` daraxti o'qilardi. Kuniga
  /// 20 ta buyurtma qiladigan biznesda ikki yildan keyin bu ~15 000 ta
  /// yozuv degani - har safar to'liq yuklanardi. Endi faqat yetgazilmagan
  /// buyurtmalar keladi, ya'ni yuklama biznesning HAJMIGA emas, joriy
  /// ISH HAJMIGA bog'liq bo'ladi.
  Stream<List<Order>> streamActiveOrders() {
    return _scope
        .ref('orders')
        .orderByChild('active')
        .equalTo(true)
        .limitToLast(_activeLimit)
        .onValue
        .map((event) => _parse(event.snapshot));
  }

  /// Operatsion ekranlar uchun to'liq to'plam.
  ///
  /// Faol buyurtmalar + BUGUN yetgazilganlar.
  ///
  /// Ikkinchisi ATAYLAB qo'shilgan: buyurtma yetgazilgach `active: false`
  /// bo'ladi va faol so'rovga tushmaydi, lekin Yetgazma bo'limidagi
  /// "Yetgazildi" ro'yxati aynan bugungi topshiriqlarni ko'rsatishi kerak.
  /// Faqat faol buyurtmalar bilan bu ro'yxat doim bo'sh chiqardi.
  ///
  /// Kun chegarasi oqim YARATILGANDA hisoblanadi. Ilova yarim tunda ochiq
  /// qolsa ro'yxat o'zi yangilanmaydi — keyingi ochilishda to'g'rilanadi.
  Stream<List<Order>> streamOperational() {
    final now = DateTime.now();
    return combineLatest2(
      streamActiveOrders(),
      streamOrdersDeliveredBetween(startOfDay(now), endOfDay(now)),
      _mergeById,
    );
  }

  /// Berilgan davrda YARATILGAN buyurtmalar - hisobot ekranlari uchun.
  Stream<List<Order>> streamOrdersCreatedBetween(DateTime from, DateTime to) {
    return _scope
        .ref('orders')
        .orderByChild('createdAt')
        .startAt(from.millisecondsSinceEpoch)
        .endAt(to.millisecondsSinceEpoch)
        .onValue
        .map((event) => _parse(event.snapshot));
  }

  /// Berilgan davrda YETGAZILGAN buyurtmalar - daromad hisoboti uchun.
  ///
  /// Yaratilgan sana bo'yicha so'rash noto'g'ri bo'lardi: yanvarda
  /// qabul qilinib martda topshirilgan buyurtmaning puli mart daromadiga
  /// kiradi.
  Stream<List<Order>> streamOrdersDeliveredBetween(DateTime from, DateTime to) {
    return _scope
        .ref('orders')
        .orderByChild('deliveredAt')
        .startAt(from.millisecondsSinceEpoch)
        .endAt(to.millisecondsSinceEpoch)
        .onValue
        .map((event) => _parse(event.snapshot));
  }

  /// Qarzi qolgan buyurtmalar.
  ///
  /// `debtAmount` bo'yicha indeks: 0 dan katta qiymatlar. Qarzi yo'q va
  /// hali yetgazilmagan buyurtmalarda bu maydon umuman bo'lmaydi, shuning
  /// uchun ular so'rovga tushmaydi.
  Stream<List<Order>> streamDebtors() {
    return _scope
        .ref('orders')
        .orderByChild('debtAmount')
        .startAt(0.01)
        .onValue
        .map((event) => _parse(event.snapshot));
  }

  /// Davr hisoboti uchun buyurtmalar to'plami.
  ///
  /// UCHTA oqim birlashtiriladi va har biri aniq bir savol uchun kerak:
  ///
  ///  * shu davrda YARATILGAN — "nechta buyurtma qabul qilindi"
  ///  * shu davrda YETGAZILGAN — daromad (yanvarda qabul qilinib martda
  ///    topshirilgan buyurtmaning puli MART daromadiga kiradi, shuning
  ///    uchun yaratilish sanasi bo'yicha hisoblash noto'g'ri bo'lardi)
  ///  * hozir FAOL — sexda turgan, hali yetgazilmagan buyurtmalar
  ///
  /// Bir buyurtma bir nechta oqimda chiqishi mumkin — ID bo'yicha
  /// takrorlanish olib tashlanadi.
  ///
  /// CHEKLOV: davrdan OLDIN yaratilgan, davr ICHIDA olib kelingan va
  /// davrdan KEYIN yetgazilgan buyurtma o'tgan davr hisobotiga tushmaydi
  /// (u uchala so'rovga ham mos kelmaydi). Bu juda kam uchraydigan holat;
  /// aniqroq kerak bo'lsa `pickedUpAt` bo'yicha alohida indeks qo'shiladi.
  Stream<List<Order>> streamOrdersForPeriod(DateTime from, DateTime to) {
    return combineLatest2(
      combineLatest2(
        streamOrdersCreatedBetween(from, to),
        streamOrdersDeliveredBetween(from, to),
        _mergeById,
      ),
      streamActiveOrders(),
      _mergeById,
    );
  }

  /// Hisobot ekranlari uchun: davr buyurtmalari VA davr tarixi.
  ///
  /// Tarix endi alohida tugunda, shuning uchun uni alohida so'rash kerak.
  /// Ikkalasi bitta oqimda birlashtiriladi — ekran ikki `StreamBuilder`
  /// bilan ovora bo'lmasin va ular bir-biriga mos kelmagan holatni
  /// ko'rsatib qo'ymasin.
  Stream<({List<Order> orders, List<OrderHistoryEntry> history})> streamReport(
    DateTime from,
    DateTime to,
  ) {
    return combineLatest2(
      streamOrdersForPeriod(from, to),
      streamHistoryBetween(from, to),
      (List<Order> orders, List<OrderHistoryEntry> history) =>
          (orders: orders, history: history),
    );
  }

  /// Ikki ro'yxatni ID bo'yicha birlashtiradi (takrorlanishsiz).
  List<Order> _mergeById(List<Order> a, List<Order> b) {
    final byId = <int, Order>{for (final o in a) o.id: o};
    for (final o in b) {
      byId[o.id] = o;
    }
    return byId.values.toList()..sort(_byDeadlineThenNewest);
  }

  /// Oxirgi [limit] ta buyurtma - boshqaruv ro'yxati uchun.
  Stream<List<Order>> streamRecentOrders({int limit = 200}) {
    return _scope
        .ref('orders')
        .orderByChild('createdAt')
        .limitToLast(limit)
        .onValue
        .map((event) => _parse(event.snapshot));
  }

  /// Har doim eng yaqin topshirish sanasiga ega buyurtma birinchi keladi.
  /// Muddati bo'lmagan buyurtmalar oxiriga tushadi, lekin yo'qolmaydi.
  /// Muddatlar teng bo'lsa, yangi buyurtma birinchi.
  int _byDeadlineThenNewest(Order a, Order b) {
    final ad = a.deadline;
    final bd = b.deadline;
    if (ad == null && bd == null) return b.id.compareTo(a.id);
    if (ad == null) return 1;
    if (bd == null) return -1;
    final cmp = ad.compareTo(bd);
    return cmp != 0 ? cmp : b.id.compareTo(a.id);
  }

  Future<int> createOrder({
    required String customerName,
    required String customerPhone,
    String address = '',
    DateTime? deadline,
    required DeliveryType deliveryType,
    required List<NewOrderItemDraft> items,
    required String createdBy,
    required String createdByName,
    String? comment,
  }) async {
    // Buyurtma raqami serverdagi umumiy hisoblagichdan olinadi - shu sabab
    // yangi buyurtma yaratish uchun internet SHART (raqamni oldindan
    // taxmin qilib bo'lmaydi, aks holda ikki xodimda bir xil raqam
    // chiqib qolardi). Aloqa bo'lmasa uzoq kutib turmay, tushunarli
    // xatolik bilan qaytamiz.
    final counterRef = _scope.ref('counters/orderId');
    final result = await awaitOrFail(counterRef.runTransaction((current) {
      // `as int` ATAYLAB ishlatilmaydi: hisoblagichga biror sababdan
      // matn yoki kasr son yozilib qolsa, tип xatosi butun "yangi
      // buyurtma" oqimini to'xtatib qo'yardi va bunda sababi ham
      // ko'rinmasdi. Endi kutilmagan qiymat 0 deb qabul qilinadi.
      final next = switch (current) {
        final int n => n + 1,
        final num n => n.toInt() + 1,
        final String s => (int.tryParse(s) ?? 0) + 1,
        _ => 1,
      };
      return Transaction.success(next);
    }));

    if (!result.committed) {
      throw StateError(
        'Buyurtma raqamini olishning iloji bo\'lmadi. Qayta urinib ko\'ring.',
      );
    }
    final orderId = (result.snapshot.value as num).toInt();

    final itemsMap = <String, Object?>{};
    var totalPrice = 0.0;
    for (var i = 0; i < items.length; i++) {
      final draft = items[i];
      final index = i + 1;
      itemsMap['$index'] = draft.toFirebase(
        itemId: '$orderId/$index',
        createdBy: createdBy,
      );
      totalPrice += draft.price;
    }

    // "Ishni boshlash" endi alohida bosqich sifatida ishlatilmaydi: o'zi
    // kelgan mijoz buyurtmasi to'g'ridan-to'g'ri yuvishga, olib kelinishi
    // kerak bo'lgani esa "Olib kelish"ga tushadi (qabul qilingach yana
    // to'g'ridan-to'g'ri yuvishga o'tadi - qarang: advanceStatus). Shundan
    // keyin har bir mahsulot Yuvish/Qadoqlash bo'limlarida mustaqil
    // siljiydi - buyurtmaning umumiy holati faqat barcha mahsulot "tayyor"
    // bo'lganda avtomatik yangilanadi (qarang: updateItemStatus).
    final initialStatus = deliveryType == DeliveryType.olibKelish
        ? OrderStatus.olibKelish
        : OrderStatus.yuvishda;

    final trimmedComment = comment?.trim() ?? '';
    final historyKey = _newHistoryKey();

    // Hisoblagich muvaffaqiyatli oshdi, ya'ni bir soniya oldin aloqa bor
    // edi. Shu sabab yozuvni `awaitOrQueue` bilan qo'yamiz: buyurtma
    // mahalliy keshda darhol paydo bo'ladi va ro'yxatda ko'rinadi.
    //
    // Rad etilgan yozuv endi JIM YO'QOLMAYDI - `awaitOrQueue` uni
    // `WriteRejected` qilib tashlaydi yoki kechroq `WriteFailures` oqimiga
    // yuboradi (qarang: utils/offline_write.dart).
    //
    // Qoladigan kichik xavf: hisoblagich oshgandan keyin ilova butunlay
    // yopilib qolsa, o'sha raqam ishlatilmay qoladi va raqamlarda bo'shliq
    // paydo bo'ladi (#57 dan keyin #59). Bu zararsiz - raqam faqat
    // identifikator, ketma-ketligi hisobotlarda ishlatilmaydi.
    // Buyurtma va uning birinchi tarix yozuvi BITTA yozuvda ketadi —
    // biri yozilib ikkinchisi qolib ketmasligi uchun.
    await awaitOrQueue(_scope.root.update({
      'orders/$orderId': {
        'id': orderId,
        'customerName': customerName.trim(),
        'customerPhone': normalizePhone(customerPhone),
        'address': address.trim(),
        if (deadline != null) 'deadline': deadline.millisecondsSinceEpoch,
        'deliveryType': deliveryType.key,
        'status': initialStatus.key,
        // Faol buyurtmalar alohida indeks orqali so'raladi - shu sabab
        // butun tarixni yuklash shart emas (qarang: streamActiveOrders).
        'active': true,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': ServerValue.timestamp,
        'items': itemsMap,
        'itemCount': items.length,
        'totalPrice': totalPrice,
        'lastActionAt': ServerValue.timestamp,
        'lastActionBy': createdBy,
        if (trimmedComment.isNotEmpty)
          'comments': {
            '0': {
              'text': trimmedComment,
              'authorId': createdBy,
              'authorName': createdByName,
              'createdAt': ServerValue.timestamp,
            },
          },
      },
      'order_history/$historyKey': _historyEntry(orderId, {
        'type': 'order_created',
        'byEmployeeId': createdBy,
        'byName': createdByName,
        'at': ServerValue.timestamp,
        'toStatus': initialStatus.key,
      }),
    }));

    return orderId;
  }

  /// Buyurtma darajasidagi (mahsulotlarga bog'liq bo'lmagan) holat
  /// o'zgarishlari uchun - hozircha faqat "Olib kelish -> Yuvishda"
  /// (Qabul qilindi) shu orqali amalga oshiriladi.
  Future<void> advanceStatus({
    required Order order,
    required OrderStatus toStatus,
    required String byEmployeeId,
    required String byName,
  }) async {
    final historyKey = _newHistoryKey();

    // "Olib kelish -> Yuvishda" = buyurtma sexga qabul qilindi. Kim qabul
    // qilgani belgilanadi - yetgazma statistikasi shundan hisoblanadi
    // (ilgari buning uchun butun tarix qidirilardi).
    final accepted = order.status == OrderStatus.olibKelish &&
        toStatus == OrderStatus.yuvishda;

    await awaitOrQueue(_scope.root.update({
      'orders/${order.id}/status': toStatus.key,
      if (toStatus == OrderStatus.yuvishda)
        'orders/${order.id}/washStartedAt': ServerValue.timestamp,
      ...(accepted
              ? _stamp('pickedUp', byEmployeeId: byEmployeeId, byName: byName)
              : const <String, Object?>{})
          .map((k, v) => MapEntry('orders/${order.id}/$k', v)),
      ..._lastAction(byEmployeeId)
          .map((k, v) => MapEntry('orders/${order.id}/$k', v)),
      'order_history/$historyKey': _historyEntry(order.id, {
        'type': 'status_changed',
        'byEmployeeId': byEmployeeId,
        'byName': byName,
        'at': ServerValue.timestamp,
        'fromStatus': order.status.key,
        'toStatus': toStatus.key,
      }),
    }));
  }

  /// Bitta mahsulotning sexdagi holatini o'zgartiradi. Shu o'zgarish
  /// natijasida buyurtmadagi BARCHA mahsulot "Tayyor" bo'lib qolsa,
  /// buyurtmaning umumiy holati ham avtomatik "Yetgazishga tayyor"ga
  /// o'tadi (qo'lda tugma bosish shart emas).
  Future<void> updateItemStatus({
    required Order order,
    required OrderItem item,
    required ItemStatus toStatus,
    String? rewashReason,
    required String byEmployeeId,
    required String byName,
  }) async {
    final trimmedReason = rewashReason?.trim() ?? '';

    await _mutateOrder(
      orderId: order.id,
      byEmployeeId: byEmployeeId,
      historyEntry: {
        'type': 'item_status_changed',
        'byEmployeeId': byEmployeeId,
        'byName': byName,
        'at': ServerValue.timestamp,
        'fromStatus': item.status.key,
        'toStatus': toStatus.key,
        'itemProductName': item.productName,
        'itemKey': item.key,
        if (trimmedReason.isNotEmpty) 'note': trimmedReason,
      },
      mutate: (map, items) {
        final existing = items[item.key];
        if (existing is! Map) return;
        final updated = Map<String, dynamic>.from(existing);
        updated['status'] = toStatus.key;
        if (trimmedReason.isNotEmpty) {
          updated['rewashReason'] = trimmedReason;
        }
        items[item.key] = updated;

        // "Hammasi tayyor" tekshiruvi endi SERVERDAGI joriy holatdan
        // bajariladi. Ilgari u qurilmadagi eski nusxadan hisoblanardi:
        // ikki xodim bir vaqtda oxirgi ikki xizmatni tayyor deb belgilasa,
        // ikkalasi ham "hali hammasi tayyor emas" deb ko'rardi va buyurtma
        // sexda qotib qolardi.
        // Qayta yuvishga qaytarish - bu boshqalar bilishi kerak bo'lgan
        // hodisa, shuning uchun buyurtmada belgilanadi (bildirishnoma shu
        // maydondan quriladi, tarixdan emas).
        if (toStatus == ItemStatus.qaytaYuvildi) {
          map.addAll(_stamp(
            'lastRewash',
            byEmployeeId: byEmployeeId,
            byName: byName,
            note: trimmedReason.isNotEmpty
                ? '${item.productName} — $trimmedReason'
                : item.productName,
          ));
        }

        if (allItemsReady(items)) {
          if (map['status'] != OrderStatus.yetgazishgaTayyor.key) {
            map['status'] = OrderStatus.yetgazishgaTayyor.key;
            map.addAll(_stamp(
              'ready',
              byEmployeeId: byEmployeeId,
              byName: byName,
            ));
          }
        } else if (map['status'] == OrderStatus.yetgazishgaTayyor.key) {
          // Xizmat qayta yuvishga qaytarildi - buyurtma ham sexga qaytadi.
          map['status'] = OrderStatus.yuvishda.key;
          map['readyAt'] = null;
          map['readyBy'] = null;
          map['readyByName'] = null;
        }
      },
    );
  }

  /// Mavjud buyurtmaga yangi mahsulot(lar) qo'shadi - Yuvish yoki Olib
  /// kelish bo'limidan "Mahsulot qo'shish" orqali. Tranzaksiya orqali
  /// ishlaydi, shunda ikki xodim bir vaqtda mahsulot qo'shsa ham kalitlar
  /// to'qnashmaydi.
  Future<void> addItemsToOrder({
    required int orderId,
    required List<NewOrderItemDraft> items,
    required String createdBy,
    required String createdByName,
  }) async {
    if (items.isEmpty) return;
    final ref = _scope.ref('orders/$orderId');
    // Tranzaksiya server bilan ishlaydi (bir vaqtda ikki xodim xizmat
    // qo'shsa kalitlar to'qnashmasligi uchun) - aloqa bo'lmasa uzoq
    // kutmay, tushunarli xatolik bilan qaytamiz.
    await awaitOrFail(ref.runTransaction((current) {
      if (current == null) return Transaction.success(current);
      final map = Map<String, dynamic>.from(current as Map);
      final existingItems = asFirebaseMap(map['items']);

      var maxKey = 0;
      for (final key in existingItems.keys) {
        final n = int.tryParse(key) ?? 0;
        if (n > maxKey) maxKey = n;
      }

      var totalPrice = (map['totalPrice'] as num?)?.toDouble() ?? 0;
      final newItemsMap = Map<String, dynamic>.from(existingItems);
      for (var i = 0; i < items.length; i++) {
        final draft = items[i];
        final index = maxKey + i + 1;
        newItemsMap['$index'] = draft.toFirebase(
          itemId: '$orderId/$index',
          createdBy: createdBy,
        );
        totalPrice += draft.price;
      }

      map.addAll(_lastAction(createdBy));
      map['items'] = newItemsMap;
      map['totalPrice'] = totalPrice;
      map['itemCount'] = newItemsMap.length;
      return Transaction.success(map);
    }));

    await awaitOrQueue(_scope
        .ref('order_history/${_newHistoryKey()}')
        .set(_historyEntry(orderId, {
          'type': 'item_updated',
          'byEmployeeId': createdBy,
          'byName': createdByName,
          'at': ServerValue.timestamp,
          'note': items.length == 1
              ? '${items.first.productName} qo\'shildi'
              : '${items.length} ta mahsulot qo\'shildi',
        })));
  }

  /// Buyurtmani TRANZAKSIYA orqali o'zgartiradi.
  ///
  /// NEGA TRANZAKSIYA: ilgari bu amallar umumiy narxni qurilmadagi ESKI
  /// nusxadan hisoblab (`order.totalPrice - item.price + price`), natijani
  /// to'liq qayta yozardi. Ikki xodim bir buyurtmaning ikki xil xizmatini
  /// bir vaqtda o'lchasa, keyingi yozuv birinchisini bekor qilardi va
  /// narx noto'g'ri qolardi.
  ///
  /// Tranzaksiya har safar SERVERDAGI joriy holatdan o'qiydi, shuning
  /// uchun bunday to'qnashuv bo'lmaydi. Oflayn ham ishlaydi: Firebase
  /// o'zgarishni darhol mahalliy qo'llaydi va aloqa tiklanganda server
  /// tomonida qayta hisoblab yuboradi.
  Future<void> _mutateOrder({
    required int orderId,
    required String byEmployeeId,
    required Map<String, Object?> historyEntry,
    required void Function(Map<String, dynamic> order, Map<String, dynamic> items)
        mutate,
  }) async {
    final ref = _scope.ref('orders/$orderId');

    await awaitOrQueue(ref.runTransaction((current) {
      // Buyurtma o'chirilgan bo'lsa qayta yaratib yubormaymiz.
      if (current == null) return Transaction.abort();

      final map = Map<String, dynamic>.from(current as Map);
      final items = Map<String, dynamic>.from(asFirebaseMap(map['items']));

      mutate(map, items);

      map['items'] = items;
      map['totalPrice'] = sumItemPrices(items);
      map['itemCount'] = items.length;
      map.addAll(_lastAction(byEmployeeId));

      return Transaction.success(map);
    }));

    // Tarix ALOHIDA yoziladi: tranzaksiya faqat o'z tuguni ichiga yoza
    // oladi, tarix esa endi boshqa tugunda. Nazariy jihatdan tranzaksiya
    // bekor bo'lib tarix yozilib qolishi mumkin — audit jurnali uchun bu
    // zararsiz (ortiqcha yozuv, yo'qolgan yozuv emas).
    await awaitOrQueue(_scope
        .ref('order_history/${_newHistoryKey()}')
        .set(_historyEntry(orderId, historyEntry)));
  }

  /// Xizmatning o'lchamini (va ixtiyoriy ravishda mahsulot turini)
  /// yangilaydi. [newProductId]/[newProductName] berilsa xizmat turi ham
  /// almashadi - masalan "Gilam" o'rniga "Palos" tanlansa.
  Future<void> updateItemMeasurement({
    required Order order,
    required OrderItem item,
    required String hajm,
    required double price,
    required MeasureUnit unit,
    required double quantity,
    String? newProductId,
    String? newProductName,
    required String byEmployeeId,
    required String byName,
  }) async {
    final productChanged =
        newProductName != null && newProductName != item.productName;
    final oldLabel = item.isMeasured
        ? '${item.hajm} (${item.price.toStringAsFixed(0)} so\'m)'
        : 'o\'lchanmagan';

    await _mutateOrder(
      orderId: order.id,
      byEmployeeId: byEmployeeId,
      historyEntry: {
        'type': 'item_updated',
        'byEmployeeId': byEmployeeId,
        'byName': byName,
        'at': ServerValue.timestamp,
        'itemProductName': newProductName ?? item.productName,
        'itemKey': item.key,
        'note': productChanged
            ? '${item.productName} → $newProductName · $oldLabel → $hajm (${price.toStringAsFixed(0)} so\'m)'
            : '$oldLabel → $hajm (${price.toStringAsFixed(0)} so\'m)',
      },
      mutate: (map, items) {
        final existing = items[item.key];
        if (existing is! Map) return;
        final updated = Map<String, dynamic>.from(existing);
        updated['hajm'] = hajm;
        updated['price'] = price;
        updated['unit'] = unit.key;
        updated['quantity'] = quantity;
        if (newProductId != null) updated['productId'] = newProductId;
        if (newProductName != null) updated['productName'] = newProductName;
        items[item.key] = updated;
      },
    );
  }

  /// Buyurtmadan bitta xizmatni butunlay o'chiradi va umumiy narxni
  /// qayta hisoblaydi. Xizmat kalitlari qayta raqamlanmaydi - qolgan
  /// xizmatlarning ID raqami ("6/2") o'zgarmasligi kerak.
  Future<void> deleteItem({
    required Order order,
    required OrderItem item,
    required String byEmployeeId,
    required String byName,
  }) async {
    await _mutateOrder(
      orderId: order.id,
      byEmployeeId: byEmployeeId,
      historyEntry: {
        'type': 'item_deleted',
        'byEmployeeId': byEmployeeId,
        'byName': byName,
        'at': ServerValue.timestamp,
        'itemProductName': item.productName,
        'itemKey': item.key,
        'note': item.isMeasured
            ? '${item.productName} (${item.hajm}) o\'chirildi'
            : '${item.productName} o\'chirildi',
      },
      mutate: (map, items) => items.remove(item.key),
    );
  }

  /// Topshirish sanasini belgilaydi - buyurtma qabul qilinayotganda
  /// (sana majburiy bo'lgan bosqichda) ishlatiladi.
  Future<void> setDeadline({
    required int orderId,
    required DateTime deadline,
    required String byEmployeeId,
    required String byName,
  }) async {
    final historyKey = _newHistoryKey();
    await awaitOrQueue(_scope.root.update({
      'orders/$orderId/deadline': deadline.millisecondsSinceEpoch,
      ..._lastAction(byEmployeeId)
          .map((k, v) => MapEntry('orders/$orderId/$k', v)),
      'order_history/$historyKey': _historyEntry(orderId, {
        'type': 'item_updated',
        'byEmployeeId': byEmployeeId,
        'byName': byName,
        'at': ServerValue.timestamp,
        'note':
            'Topshirish sanasi belgilandi: ${deadline.day.toString().padLeft(2, '0')}.'
                '${deadline.month.toString().padLeft(2, '0')}.${deadline.year}',
      }),
    }));
  }

  /// Dastavchik "Olib kelish" bosqichida turgan buyurtma uchun GPS
  /// koordinatalarini saqlaydi - "Qabul qilindi" tugmasi shundan keyingina
  /// faollashadi.
  Future<void> savePickupLocation({
    required int orderId,
    required double latitude,
    required double longitude,
  }) async {
    await awaitOrQueue(_scope.ref('orders/$orderId').update({
      'pickupLat': latitude,
      'pickupLng': longitude,
    }));
  }

  Future<void> addItemComment({
    required int orderId,
    required String itemKey,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final ref = _scope.ref('orders/$orderId/items/$itemKey/comments').push();
    await ref.set({
      'text': text.trim(),
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': ServerValue.timestamp,
    });
  }

  /// Yetgazma bo'limida "Yetgazildi" bosilib, to'lov kiritilgach chaqiriladi.
  /// Yetgazildi deb belgilaydi. To'liq summa olinmagan bo'lsa, farq
  /// [debtAmount] (mijoz keyin to'laydi) yoki [discountAmount] (kechirildi)
  /// sifatida aniq yoziladi - taxmin qilinmaydi, chunki ikkalasining
  /// moliyaviy ma'nosi butunlay boshqa.
  /// [shortfallIsDiscount] — yetmagan qismni kechirishmi (`true`) yoki
  /// qarz deb yozishmi (`false`). SUMMANI esa server o'zi hisoblaydi.
  ///
  /// NEGA TRANZAKSIYA: farq buyurtmaning SERVERDAGI joriy narxidan
  /// olinadi, dastavchik oynani ochganda ko'rgan narxdan emas. Dastavchik
  /// mijoz oldida turganda sexdagi xodim buyurtmaga yangi xizmat qo'shishi
  /// mumkin — eski narxdan hisoblansa, o'sha farq hech qayerda qayd
  /// etilmay yo'qolib ketardi.
  Future<void> markDelivered({
    required Order order,
    required String paymentMethod,
    required double paymentAmount,
    required bool shortfallIsDiscount,
    required String byEmployeeId,
    required String byName,
  }) async {

    await awaitOrQueue(
        _scope.ref('orders/${order.id}').runTransaction((current) {
      if (current == null) return Transaction.abort();
      final map = Map<String, dynamic>.from(current as Map);

      // Allaqachon yetgazilgan bo'lsa qayta yozmaymiz - aks holda
      // ikkinchi bosish to'lovni ustiga yozib yuborardi.
      if (map['status'] == OrderStatus.yetgazildi.key) {
        return Transaction.abort();
      }

      final items = asFirebaseMap(map['items']);
      final settlement = splitDeliveryPayment(
        orderTotal: sumItemPrices(items),
        paid: paymentAmount,
        shortfallIsDiscount: shortfallIsDiscount,
      );

      map['status'] = OrderStatus.yetgazildi.key;
      // Buyurtma operatsion oqimdan chiqdi - endi faol ro'yxatga
      // qo'shilmaydi va kundalik yuklamaga ta'sir qilmaydi.
      map['active'] = false;
      map['paymentMethod'] = paymentMethod;
      map['paymentAmount'] = settlement.paid;
      // Yetkazish lahzasidagi summa. `paymentAmount` keyin qarz to'langan
      // sari o'sadi, bu esa o'zgarmaydi - daromadni "qaysi kuni pul
      // olindi" bo'yicha hisoblash uchun aynan shu kerak.
      map['deliveryPaidAmount'] = settlement.paid;
      map['debtAmount'] = settlement.debt;
      map['discountAmount'] = settlement.discount;

      final parts = <String>[
        '$paymentMethod orqali ${settlement.paid.toStringAsFixed(0)} so\'m qabul qilindi',
        if (settlement.debt > 0)
          'qarz: ${settlement.debt.toStringAsFixed(0)} so\'m',
        if (settlement.discount > 0)
          'skidka: ${settlement.discount.toStringAsFixed(0)} so\'m',
      ];

      // Kim yetkazgani buyurtmada belgilanadi — yetgazma statistikasi va
      // bildirishnoma shu maydondan quriladi, butun tarixni yuklamasdan.
      map.addAll(_stamp(
        'delivered',
        byEmployeeId: byEmployeeId,
        byName: byName,
        note: parts.join(' · '),
      ));
      map.addAll(_lastAction(byEmployeeId));

      return Transaction.success(map);
    }));

    // Tarix alohida tugunda — tranzaksiya u yerga yoza olmaydi.
    //
    // Taqsimot (qarz/skidka) tranzaksiya ICHIDA, serverdagi joriy narxdan
    // hisoblanadi va tashqariga chiqmaydi. Shu sabab tarixga olingan
    // summa yoziladi; to'liq taqsimot buyurtmaning o'zida ko'rinadi.
    await awaitOrQueue(_scope
        .ref('order_history/${_newHistoryKey()}')
        .set(_historyEntry(order.id, {
          'type': 'status_changed',
          'byEmployeeId': byEmployeeId,
          'byName': byName,
          'at': ServerValue.timestamp,
          'fromStatus': order.status.key,
          'toStatus': OrderStatus.yetgazildi.key,
          'note':
              '$paymentMethod orqali ${paymentAmount.toStringAsFixed(0)} so\'m qabul qilindi',
        })));
  }

  /// Qarzni to'liq yoki qisman yopadi - qarzdorlar ro'yxatidan
  /// "To'lov qabul qilish" orqali chaqiriladi.
  Future<void> settleDebt({
    required Order order,
    required double amount,
    required String method,
    required String byEmployeeId,
    required String byName,
  }) async {
    // Haqiqatda olingan summa tranzaksiya ichida hisoblanadi (qarzdan
    // ortiq to'lov qabul qilinmaydi). Uni tashqariga chiqaramiz -
    // tarixga so'ralgan emas, AYNAN OLINGAN summa yozilishi kerak.
    var appliedAmount = 0.0;

    // Tranzaksiya, chunki bu yerda ikkita PUL maydoni oshiriladi/kamaytiriladi.
    // Ilgari ular qurilmadagi eski nusxadan hisoblanardi - ikki joydan bir
    // vaqtda qarz yopilsa, bittasining to'lovi yo'qolardi.
    //
    // Qancha olinishi ham SERVERDAGI qarzdan kelib chiqadi: shu bilan qarz
    // manfiy songa tushib ketmaydi.
    await awaitOrQueue(_scope.ref('orders/${order.id}').runTransaction((current) {
      if (current == null) return Transaction.abort();
      final map = Map<String, dynamic>.from(current as Map);

      final currentDebt = (map['debtAmount'] as num?)?.toDouble() ?? 0;
      if (currentDebt <= 0) {
        // Boshqa birov allaqachon yopib bo'lgan - ikki marta yozmaymiz.
        return Transaction.abort();
      }

      final payment = applyDebtPayment(
        currentDebt: currentDebt,
        currentPaid: (map['paymentAmount'] as num?)?.toDouble() ?? 0,
        amount: amount,
      );
      final applied = payment.applied;
      appliedAmount = applied;
      final remaining = payment.remainingDebt;

      map['debtAmount'] = remaining;
      map['paymentAmount'] = payment.totalPaid;
      map.addAll(_stamp(
        'lastDebtPayment',
        byEmployeeId: byEmployeeId,
        byName: byName,
        note: remaining > 0
            ? '$method orqali ${applied.toStringAsFixed(0)} so\'m qarz to\'landi · qoldi: ${remaining.toStringAsFixed(0)} so\'m'
            : '$method orqali ${applied.toStringAsFixed(0)} so\'m - qarz to\'liq yopildi',
      ));
      map.addAll(_lastAction(byEmployeeId));

      return Transaction.success(map);
    }));

    // Tarix alohida tugunda. Aniq qolgan qarz tranzaksiya ichida
    // hisoblanadi, shuning uchun tarixga kiritilgan summa yoziladi.
    await awaitOrQueue(_scope
        .ref('order_history/${_newHistoryKey()}')
        .set(_historyEntry(order.id, {
          'type': 'debt_settled',
          'byEmployeeId': byEmployeeId,
          'byName': byName,
          'at': ServerValue.timestamp,
          // Summa va usul ALOHIDA maydonlarda. Ilgari ular faqat izoh
          // matni ichida edi va hisobot ularni o'qiy olmasdi - natijada
          // qarz to'lovi daromadga umuman tushmasdi.
          'amount': appliedAmount,
          'method': method,
          'note':
              '$method orqali ${appliedAmount.toStringAsFixed(0)} so\'m qabul qilindi',
        })));
  }

  Future<void> addComment({
    required int orderId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final ref = _scope.ref('orders/$orderId/comments').push();
    await ref.set({
      'text': text.trim(),
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> deleteOrder(int orderId) async {
    await awaitOrQueue(_scope.ref('orders/$orderId').remove());
  }

  /// Buyurtmaning asosiy ma'lumotlarini tahrirlaydi (mahsulotlar, holat va
  /// tarixga tegmaydi). Muddat ixtiyoriy - null berilsa o'chiriladi.
  Future<void> updateOrderDetails({
    required int orderId,
    required String customerName,
    required String customerPhone,
    required String address,
    required DateTime? deadline,
    required DeliveryType deliveryType,
  }) async {
    await awaitOrQueue(_scope.ref('orders/$orderId').update({
      'customerName': customerName.trim(),
      'customerPhone': normalizePhone(customerPhone),
      'address': address.trim(),
      'deadline': deadline?.millisecondsSinceEpoch,
      'deliveryType': deliveryType.key,
    }));
  }
}
