import '../models/order.dart';
import 'date_utils.dart';

const cashPaymentLabel = 'Naqd pul';
const cardPaymentLabel = 'Karta';

/// Bitta xodimning bir kunlik dastavchik faoliyati: nechta buyurtma olib
/// keldi, nechtasini yetkazdi, va yetkazganlaridan qancha naqd/karta pul
/// qabul qildi.
class DeliveryStats {
  const DeliveryStats({
    this.pickedUpCount = 0,
    this.deliveredCount = 0,
    this.cashTotal = 0,
    this.cardTotal = 0,
  });

  final int pickedUpCount;
  final int deliveredCount;
  final double cashTotal;
  final double cardTotal;

  double get moneyTotal => cashTotal + cardTotal;

  DeliveryStats addPickup() => DeliveryStats(
        pickedUpCount: pickedUpCount + 1,
        deliveredCount: deliveredCount,
        cashTotal: cashTotal,
        cardTotal: cardTotal,
      );

  DeliveryStats addDelivery(Order order) => DeliveryStats(
        pickedUpCount: pickedUpCount,
        deliveredCount: deliveredCount + 1,
        cashTotal: cashTotal +
            (order.paymentMethod == cashPaymentLabel
                ? order.paymentAmount ?? 0
                : 0),
        cardTotal: cardTotal +
            (order.paymentMethod == cardPaymentLabel
                ? order.paymentAmount ?? 0
                : 0),
      );
}

/// Buyurtmani qabul qilgan (olib kelgan) dastavchik belgisi.
///
/// Ilgari bu tarixdan qidirilardi — ya'ni har bir buyurtmaning butun
/// tarixi yuklanishi kerak edi. Endi buyurtmaning o'zida saqlanadi.
ActorStamp? pickupEntryOf(Order order) => order.pickedUp;

/// Buyurtmani yetkazib bergan xodim belgisi.
ActorStamp? deliveryEntryOf(Order order) => order.delivered;

/// Berilgan kunda yetkazilgan buyurtmalar ro'yxati (eng so'nggisi birinchi) -
/// ixtiyoriy ravishda faqat bitta xodim yetkazganlari bilan cheklab.
List<Order> deliveredOn(
  List<Order> orders,
  DateTime day, {
  String? employeeId,
}) {
  final start = startOfDay(day);
  final end = endOfDay(day);
  final result = orders.where((o) {
    if (o.deliveredAt == null || !isWithinRange(o.deliveredAt!, start, end)) {
      return false;
    }
    if (employeeId == null) return true;
    return deliveryEntryOf(o)?.employeeId == employeeId;
  }).toList();
  result.sort((a, b) => b.deliveredAt!.compareTo(a.deliveredAt!));
  return result;
}

/// Berilgan oraliqda yetkazilgan buyurtmalar (eng so'nggisi birinchi) -
/// ixtiyoriy ravishda faqat bitta xodim yetkazganlari bilan cheklab.
List<Order> deliveredBetween(
  List<Order> orders,
  DateTime start,
  DateTime end, {
  String? employeeId,
}) {
  final result = orders.where((o) {
    if (o.deliveredAt == null || !isWithinRange(o.deliveredAt!, start, end)) {
      return false;
    }
    if (employeeId == null) return true;
    return deliveryEntryOf(o)?.employeeId == employeeId;
  }).toList();
  result.sort((a, b) => b.deliveredAt!.compareTo(a.deliveredAt!));
  return result;
}

/// Har bir xodimning berilgan ORALIQDAGI dastavchik statistikasi -
/// natijada bo'lmagan xodim uchun nol qiymatlar deb hisoblanadi.
Map<String, DeliveryStats> deliveryStatsByEmployee(
  List<Order> orders,
  DateTime start,
  DateTime end,
) {
  final result = <String, DeliveryStats>{};

  for (final order in orders) {
    final pickup = pickupEntryOf(order);
    if (pickup != null &&
        pickup.employeeId.isNotEmpty &&
        isWithinRange(pickup.at, start, end)) {
      result[pickup.employeeId] =
          (result[pickup.employeeId] ?? const DeliveryStats()).addPickup();
    }
    if (order.deliveredAt != null &&
        isWithinRange(order.deliveredAt!, start, end)) {
      final empId = deliveryEntryOf(order)?.employeeId;
      if (empId == null || empId.isEmpty) continue;
      result[empId] =
          (result[empId] ?? const DeliveryStats()).addDelivery(order);
    }
  }
  return result;
}

/// Bitta xodimning berilgan kundagi statistikasi.
DeliveryStats deliveryStatsForEmployee(
  List<Order> orders,
  String employeeId,
  DateTime day,
) {
  return deliveryStatsByEmployee(
          orders, startOfDay(day), endOfDay(day))[employeeId] ??
      const DeliveryStats();
}

/// Dastavchik ro'yxatidagi bitta qator.
///
/// Bu XODIM emas: yetgazmani boshqaruvchining o'zi ham qilishi mumkin,
/// u esa xodimlar ro'yxatida yo'q. Ilgari bo'lim faqat xodimlar bo'ylab
/// yurardi va boshqaruvchi yetkazgan buyurtmalar hech qayerda
/// ko'rinmasdi - jami raqam bilan dastavchiklar yig'indisi bir-biriga
/// to'g'ri kelmasdi.
class DeliveryPerformer {
  const DeliveryPerformer({
    required this.id,
    required this.name,
    required this.stats,
    required this.isEmployee,
  });

  final String id;
  final String name;
  final DeliveryStats stats;

  /// `false` — bu xodim yozuvi emas (boshqaruvchi yoki o'chirilgan xodim).
  final bool isEmployee;
}

/// Buyurtma belgilaridan "kim" -> "ismi" xaritasini yig'adi.
///
/// Ism buyurtmaning o'zida saqlanadi, shuning uchun xodim o'chirilgan
/// bo'lsa ham uning nomi yo'qolmaydi.
Map<String, String> actorNamesFrom(List<Order> orders) {
  final names = <String, String>{};
  void add(ActorStamp? stamp) {
    if (stamp == null || stamp.employeeId.isEmpty) return;
    if (stamp.name.isNotEmpty) names[stamp.employeeId] = stamp.name;
  }

  for (final order in orders) {
    add(order.pickedUp);
    add(order.delivered);
  }
  return names;
}

/// Yetgazma bo'limi uchun to'liq ro'yxat: vakolatli xodimlar + ro'yxatda
/// bo'lmagan, lekin haqiqatda yetkazgan har kim (boshqaruvchi va h.k.).
///
/// Vakolatli xodim hech narsa yetkazmagan bo'lsa ham ro'yxatda qoladi -
/// "bugun hech kim yetkazmadi" ham ma'lumot. Ro'yxatdan tashqaridagilar
/// esa faqat haqiqatda ish qilgan bo'lsa qo'shiladi.
List<DeliveryPerformer> deliveryPerformers({
  required List<Order> orders,
  required Map<String, DeliveryStats> statsById,
  required Map<String, String> employeeNames,
  String fallbackName = 'Boshqaruvchi',
}) {
  final names = actorNamesFrom(orders);
  final result = <DeliveryPerformer>[];

  for (final entry in employeeNames.entries) {
    result.add(DeliveryPerformer(
      id: entry.key,
      name: entry.value,
      stats: statsById[entry.key] ?? const DeliveryStats(),
      isEmployee: true,
    ));
  }

  for (final entry in statsById.entries) {
    if (employeeNames.containsKey(entry.key)) continue;
    result.add(DeliveryPerformer(
      id: entry.key,
      name: names[entry.key] ?? fallbackName,
      stats: entry.value,
      isEmployee: false,
    ));
  }

  result.sort((a, b) {
    final byDelivery =
        b.stats.deliveredCount.compareTo(a.stats.deliveredCount);
    if (byDelivery != 0) return byDelivery;
    return a.name.compareTo(b.name);
  });
  return result;
}
