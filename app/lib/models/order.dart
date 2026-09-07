import '../utils/firebase_map.dart';
import 'comment.dart';
import 'item_status.dart';
import 'order_item.dart';
import 'order_status.dart';

/// Bitta hodisaning "kim va qachon" belgisi.
///
/// Buyurtma tugunida saqlanadigan QISQA xulosa. To'liq tarix alohida
/// tugunda ([OrderHistoryEntry] izohiga qarang), lekin bildirishnomalar
/// va statistika uchun har safar tarixni yuklash isrof bo'lardi — shu
/// sabab eng kerakli bir nechta hodisa buyurtmaning o'zida belgilanadi.
///
/// Bu maydonlar SONI QAT'IY — tarix kabi o'smaydi.
class ActorStamp {
  const ActorStamp({
    required this.at,
    required this.employeeId,
    required this.name,
    this.note,
  });

  final int at;
  final String employeeId;
  final String name;
  final String? note;

  /// Berilgan prefiks bo'yicha o'qiydi, masalan `delivered` →
  /// `deliveredAt` / `deliveredBy` / `deliveredByName`.
  static ActorStamp? read(Map<dynamic, dynamic> map, String prefix) {
    final at = (map['${prefix}At'] as num?)?.toInt();
    if (at == null || at <= 0) return null;
    return ActorStamp(
      at: at,
      employeeId: map['${prefix}By'] as String? ?? '',
      name: map['${prefix}ByName'] as String? ?? '',
      note: map['${prefix}Note'] as String?,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.deadline,
    required this.deliveryType,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.items,
    required this.totalPrice,
    required this.comments,
    this.pickedUp,
    this.ready,
    this.delivered,
    this.rewash,
    this.debtPayment,
    this.lastActionAt = 0,
    this.lastActionBy = '',
    this.washStartedAt,
    this.paymentMethod,
    this.paymentAmount,
    this.deliveryPaidAmount,
    this.debtAmount = 0,
    this.discountAmount = 0,
    this.pickupLat,
    this.pickupLng,
  });

  factory Order.fromMap(String id, Map<dynamic, dynamic> map) {
    final items = <OrderItem>[];
    for (final entry in asFirebaseMap(map['items']).entries) {
      if (entry.value is! Map) continue;
      items.add(OrderItem.fromMap(entry.key, entry.value as Map));
    }
    items.sort(
      (a, b) => (int.tryParse(a.key) ?? 0).compareTo(int.tryParse(b.key) ?? 0),
    );

    final comments = <Comment>[];
    for (final entry in asFirebaseMap(map['comments']).entries) {
      if (entry.value is! Map) continue;
      comments.add(Comment.fromMap(entry.key, entry.value as Map));
    }
    comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Order(
      id: int.tryParse(id) ?? 0,
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      deadline: (map['deadline'] as num?)?.toInt(),
      deliveryType: DeliveryType.fromKey(map['deliveryType'] as String? ?? ''),
      status: OrderStatus.fromKey(map['status'] as String? ?? ''),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      items: items,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0,
      comments: comments,
      pickedUp: ActorStamp.read(map, 'pickedUp'),
      ready: ActorStamp.read(map, 'ready'),
      delivered: ActorStamp.read(map, 'delivered'),
      rewash: ActorStamp.read(map, 'lastRewash'),
      debtPayment: ActorStamp.read(map, 'lastDebtPayment'),
      lastActionAt: (map['lastActionAt'] as num?)?.toInt() ?? 0,
      lastActionBy: map['lastActionBy'] as String? ?? '',
      washStartedAt: (map['washStartedAt'] as num?)?.toInt(),
      paymentMethod: map['paymentMethod'] as String?,
      paymentAmount: (map['paymentAmount'] as num?)?.toDouble(),
      deliveryPaidAmount:
          (map['deliveryPaidAmount'] as num?)?.toDouble(),
      debtAmount: (map['debtAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0,
      pickupLat: (map['pickupLat'] as num?)?.toDouble(),
      pickupLng: (map['pickupLng'] as num?)?.toDouble(),
    );
  }

  final int id;
  final String customerName;
  final String customerPhone;
  final String address;

  /// Mijozga topshirish uchun kelishilgan so'nggi sana (millisecondsSinceEpoch).
  /// Ixtiyoriy - kiritilmasligi mumkin.
  final int? deadline;
  final DeliveryType deliveryType;
  final OrderStatus status;
  final String createdBy;
  final String createdByName;
  final int createdAt;
  final List<OrderItem> items;
  final double totalPrice;
  final List<Comment> comments;

  // --- Hodisa belgilari ---------------------------------------------------
  // To'liq tarix alohida tugunda; bular esa eng kerakli bir nechta hodisa
  // uchun buyurtmaning o'zida saqlanadigan qisqa xulosa.

  /// Mijozdan olib kelinib, sexga qabul qilingan payt.
  final ActorStamp? pickedUp;

  /// Barcha xizmat tayyor bo'lib, yetgazishga o'tgan payt.
  final ActorStamp? ready;

  /// Mijozga topshirilgan payt.
  final ActorStamp? delivered;

  /// OXIRGI qayta yuvishga qaytarish.
  final ActorStamp? rewash;

  /// OXIRGI qarz to'lovi.
  final ActorStamp? debtPayment;

  /// Buyurtmaga eng oxirgi marta kim va qachon tegingani.
  ///
  /// Ovozli signal shu orqali "bu o'zgarishni men qildimmi" degan savolga
  /// javob topadi — butun tarixni yuklamasdan.
  final int lastActionAt;
  final String lastActionBy;

  final int? washStartedAt;

  int? get pickedUpAt => pickedUp?.at;
  int? get readyAt => ready?.at;
  int? get deliveredAt => delivered?.at;

  /// Yetgazib berilganda to'lov usuli ("naqd" | "karta") va olingan summa.
  final String? paymentMethod;
  final double? paymentAmount;

  /// Yetkazish PAYTIDA olingan pul.
  ///
  /// [paymentAmount] dan farqi: u jamlanma va qarz to'langan sari o'sadi.
  /// Daromadni "qaysi kuni pul olindi" bo'yicha hisoblash uchun esa
  /// yetkazish lahzasidagi summa kerak - u keyin o'zgarmaydi.
  ///
  /// Eski yozuvlarda bu maydon yo'q; o'shalar uchun [paymentAmount] ga
  /// qaytamiz (qarz to'lanmagan bo'lsa ikkalasi baribir teng).
  final double? deliveryPaidAmount;

  /// Yetkazishda olingan pul - eski yozuvlarga chidamli.
  double get paidAtDelivery => deliveryPaidAmount ?? paymentAmount ?? 0;

  /// To'liq olinmagan summaning taqsimoti. Dastavchik topshirish paytida
  /// farqni aynan qaysi biri ekanini o'zi belgilaydi:
  ///  * [debtAmount]     - mijoz keyin to'laydi (Qarzdorlarga tushadi)
  ///  * [discountAmount] - kechirildi, hech qachon olinmaydi
  final double debtAmount;
  final double discountAmount;

  bool get hasDebt => debtAmount > 0;

  /// Dastavchik "Olib kelish" bosqichida saqlagan manzil koordinatalari -
  /// "Yo'lga chiqish" tugmasi shu orqali xaritani ochadi.
  final double? pickupLat;
  final double? pickupLng;

  bool get hasPickupLocation => pickupLat != null && pickupLng != null;

  String get code => '#$id';

  /// Ishlov jarayonidagi (sexga tushgan) mahsulotlar orasida "Tayyor"
  /// bo'lganlar nisbati - buyurtma cardida progress sifatida ko'rsatiladi.
  int get readyItemCount =>
      items.where((i) => i.status == ItemStatus.tayyor).length;

  bool get allItemsReady =>
      items.isNotEmpty && items.every((i) => i.status == ItemStatus.tayyor);
}
