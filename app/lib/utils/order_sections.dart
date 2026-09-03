import '../models/item_status.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import 'date_utils.dart';

/// Operatsion bo'limlar uchun oldindan hisoblangan ro'yxatlar.
///
/// NEGA KERAK: ilgari har bir ekran va har bir nishoncha (badge) ro'yxatni
/// ALOHIDA filtrlardi — bitta buyurtma o'zgarganda ro'yxat yetti marta
/// aylanib chiqilardi (4 ta ekran + 3 ta hisoblagich). Endi hammasi bir
/// martalik o'tishda hisoblanadi va tayyor holda uzatiladi.
///
/// Filtr shartlari ham shu yerda to'plangan — ilgari ular uchta ekran
/// fayliga tarqalgan edi va ekran bilan nishoncha bir-biridan farq qilib
/// ketishi mumkin edi.
class OrderSections {
  const OrderSections({
    required this.all,
    required this.wash,
    required this.packaging,
    required this.pickup,
    required this.readyForDelivery,
    required this.deliveredToday,
  });

  const OrderSections.empty()
      : all = const [],
        wash = const [],
        packaging = const [],
        pickup = const [],
        readyForDelivery = const [],
        deliveredToday = const [];

  /// Barcha operatsion buyurtmalar — qidiruv shu ro'yxat ustida ishlaydi.
  final List<Order> all;

  /// Sexga kirgan, hali yuvilishi kerak bo'lganlar.
  final List<Order> wash;

  /// Kamida bitta xizmati qadoqlashda.
  final List<Order> packaging;

  /// Mijozdan olib kelinishi kerak.
  final List<Order> pickup;

  /// Yetgazishga tayyor.
  final List<Order> readyForDelivery;

  /// Bugun yetgazilganlar (Yetgazma bo'limidagi "Yetgazildi" ro'yxati).
  final List<Order> deliveredToday;

  /// Yetgazma bo'limi nishonchasi — qilinishi kerak bo'lgan ish soni.
  int get deliveryBadgeCount => pickup.length + readyForDelivery.length;

  /// Bitta o'tishda barcha bo'limlarni ajratadi.
  factory OrderSections.from(List<Order> orders) {
    final wash = <Order>[];
    final packaging = <Order>[];
    final pickup = <Order>[];
    final ready = <Order>[];
    final deliveredToday = <Order>[];

    for (final order in orders) {
      if (needsWash(order)) wash.add(order);
      if (needsPackaging(order)) packaging.add(order);

      switch (order.status) {
        case OrderStatus.olibKelish:
          pickup.add(order);
        case OrderStatus.yetgazishgaTayyor:
          ready.add(order);
        case OrderStatus.yetgazildi:
          final at = order.deliveredAt;
          if (at != null && isToday(at)) deliveredToday.add(order);
        case OrderStatus.ishniBoshlash:
        case OrderStatus.yuvishda:
          break;
      }
    }

    return OrderSections(
      all: orders,
      wash: wash,
      packaging: packaging,
      pickup: pickup,
      readyForDelivery: ready,
      deliveredToday: deliveredToday,
    );
  }
}

/// Buyurtma "Yuvish" bo'limida ko'rinishi kerakmi.
///
/// Xizmati hali qo'shilmagan (soni/o'lchami keyin kiritiladigan)
/// buyurtmalar ham shu yerda ko'rinadi — aks holda ular hech qayerda
/// ko'rinmay, "yo'qolib" qoladi.
bool needsWash(Order order) {
  if (!order.status.isInWorkshop) return false;
  if (order.items.isEmpty) return true;
  return order.items.any(
    (i) =>
        i.status == ItemStatus.yuvilmoqda ||
        i.status == ItemStatus.qaytaYuvildi,
  );
}

/// Buyurtma "Qadoqlash" bo'limida ko'rinishi kerakmi.
bool needsPackaging(Order order) =>
    order.items.any((i) => i.status == ItemStatus.qadoqlashda);
