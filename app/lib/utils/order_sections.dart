import '../models/business_policies.dart';
import '../models/item_status.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import 'date_utils.dart';

/// O'lchanmagan xizmat va u turgan buyurtma.
class OrderItemRef {
  const OrderItemRef(this.order, this.item);
  final Order order;
  final OrderItem item;
}

/// Buyurtmaning hozirgi joyi — qidiruv natijasida va kartalarda
/// ko'rsatiladigan "holat".
enum OrderPlace {
  pickup('Olib kelish'),
  workshop('Sexda'),
  almostReady('Deyarli tayyor'),
  ready('Tayyor'),
  warehouse('Omborda'),
  delivered('Topshirilgan');

  const OrderPlace(this.label);
  final String label;
}

/// Operatsion bo'limlar uchun oldindan hisoblangan ro'yxatlar.
///
/// Hammasi BIR o'tishda hisoblanadi va ekranlarga tayyor holda
/// uzatiladi: ilgari har bir ekran va nishoncha ro'yxatni alohida
/// filtrlardi va ular bir-biridan farq qilib ketishi mumkin edi.
class OrderSections {
  const OrderSections({
    required this.all,
    required this.wash,
    required this.packaging,
    required this.pickup,
    required this.almostReady,
    required this.readyForDelivery,
    required this.warehouse,
    required this.deliveredToday,
    required this.unmeasured,
    required this.policies,
    required this.computedAt,
  });

  OrderSections.empty()
      : all = const [],
        wash = const [],
        packaging = const [],
        pickup = const [],
        almostReady = const [],
        readyForDelivery = const [],
        warehouse = const [],
        deliveredToday = const [],
        unmeasured = const [],
        policies = BusinessPolicies.defaults,
        computedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Barcha operatsion buyurtmalar — qidiruv shu ro'yxat ustida ishlaydi.
  final List<Order> all;

  /// Kamida bitta xizmati yuvish bosqichida (yoki xizmati hali yo'q).
  final List<Order> wash;

  /// Kamida bitta xizmati qadoqlashda.
  final List<Order> packaging;

  /// Mijozdan olib kelinishi kerak.
  final List<Order> pickup;

  /// Ba'zi xizmatlari tayyor, qolgani hali sexda — bo'lib topshirish
  /// mumkin.
  final List<Order> almostReady;

  /// Hamma xizmati tayyor, topshirish kutilmoqda (omborxonadagilardan
  /// tashqari).
  final List<Order> readyForDelivery;

  /// Tayyor bo'lganiga belgilangan kundan ko'p o'tgan, olib ketilmagan.
  final List<Order> warehouse;

  /// Bugun topshirilganlar (boshqaruvchining bosh sahifasi uchun).
  final List<Order> deliveredToday;

  /// Yuvish bosqichidagi o'lchanmagan xizmatlar.
  final List<OrderItemRef> unmeasured;

  final BusinessPolicies policies;

  /// Ro'yxatlar qachon hisoblangan — omborxonaga o'tish vaqtga bog'liq.
  final DateTime computedAt;

  /// Yetgazma bo'limi nishonchasi — qilinishi kerak bo'lgan ish soni.
  int get deliveryBadgeCount =>
      pickup.length + almostReady.length + readyForDelivery.length;

  factory OrderSections.from(
    List<Order> orders, {
    BusinessPolicies policies = BusinessPolicies.defaults,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final wash = <Order>[];
    final packaging = <Order>[];
    final pickup = <Order>[];
    final almost = <Order>[];
    final ready = <Order>[];
    final warehouse = <Order>[];
    final deliveredToday = <Order>[];
    final unmeasured = <OrderItemRef>[];

    for (final order in orders) {
      switch (placeOf(order, policies, at)) {
        case OrderPlace.pickup:
          pickup.add(order);
        case OrderPlace.ready:
          ready.add(order);
        case OrderPlace.warehouse:
          warehouse.add(order);
        case OrderPlace.delivered:
          final d = order.deliveredAt;
          if (d != null && isSameDay(DateTime.fromMillisecondsSinceEpoch(d), at)) {
            deliveredToday.add(order);
          }
        case OrderPlace.almostReady:
          almost.add(order);
        case OrderPlace.workshop:
          break;
      }

      if (needsWash(order)) {
        wash.add(order);
        for (final item in order.items) {
          if (item.status.isWashStage && !item.hasNumericMeasure) {
            unmeasured.add(OrderItemRef(order, item));
          }
        }
      }
      if (needsPackaging(order)) packaging.add(order);
    }

    return OrderSections(
      all: orders,
      wash: wash,
      packaging: packaging,
      pickup: pickup,
      almostReady: almost,
      readyForDelivery: ready,
      warehouse: warehouse,
      deliveredToday: deliveredToday,
      unmeasured: unmeasured,
      policies: policies,
      computedAt: at,
    );
  }
}

/// Buyurtma hozir qayerda.
OrderPlace placeOf(Order order, BusinessPolicies policies, DateTime now) {
  switch (order.status) {
    case OrderStatus.yetgazildi:
      return OrderPlace.delivered;
    case OrderStatus.olibKelish:
      return OrderPlace.pickup;
    case OrderStatus.yetgazishgaTayyor:
      return policies.isInWarehouse(order.readyAt, now)
          ? OrderPlace.warehouse
          : OrderPlace.ready;
    case OrderStatus.ishniBoshlash:
    case OrderStatus.yuvishda:
      // Eski yozuvlarda "hammasi tayyor" bo'lsa-yu holat yangilanmagan
      // bo'lishi mumkin — u ham topshirishga tayyor hisoblanadi.
      if (order.items.isNotEmpty &&
          order.unhandedItems.isNotEmpty &&
          order.unhandedItems.every((i) => i.status == ItemStatus.tayyor)) {
        return OrderPlace.ready;
      }
      return order.readyToHandItems.isNotEmpty
          ? OrderPlace.almostReady
          : OrderPlace.workshop;
  }
}

/// Buyurtma "Yuvish" bo'limida ko'rinishi kerakmi.
///
/// Xizmati hali qo'shilmagan buyurtmalar ham shu yerda — aks holda ular
/// hech qayerda ko'rinmay, "yo'qolib" qolardi.
bool needsWash(Order order) {
  if (!order.status.isInWorkshop) return false;
  if (order.items.isEmpty) return true;
  return order.items.any((i) => i.status.isWashStage);
}

/// Buyurtma "Qadoqlash" bo'limida ko'rinishi kerakmi.
bool needsPackaging(Order order) =>
    order.items.any((i) => i.status == ItemStatus.qadoqlashda);
