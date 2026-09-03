import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'order.dart';

/// Bildirishnoma turi — ikonka va rangni belgilaydi.
enum NotificationType {
  newOrder('Yangi buyurtma', Icons.note_add_rounded, AppColors.primary),
  accepted('Qabul qilindi', Icons.inventory_rounded, AppColors.statusWashing),
  readyForDelivery('Yetgazishga tayyor', Icons.local_shipping_rounded,
      AppColors.statusReadyDelivery),
  delivered('Yetgazildi', Icons.check_circle_rounded, AppColors.statusDelivered),
  rewash('Qayta yuvishga qaytarildi', Icons.replay_rounded, AppColors.danger),
  debtSettled('Qarz to\'landi', Icons.payments_rounded, AppColors.success);

  const NotificationType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Bitta bildirishnoma.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.orderId,
    required this.orderCode,
    required this.customerName,
    required this.body,
    required this.at,
    required this.byEmployeeId,
    required this.byName,
  });

  /// Buyurtma va hodisa turidan tuzilgan barqaror ID.
  final String id;

  final NotificationType type;
  final int orderId;
  final String orderCode;
  final String customerName;

  /// Qo'shimcha tafsilot (masalan qayta yuvish sababi).
  final String body;

  final int at;
  final String byEmployeeId;
  final String byName;
}

/// Buyurtmalardan bildirishnomalar yig'adi.
///
/// NEGA BAZAGA YOZILMAYDI: kerakli ma'lumot allaqachon buyurtmada bor.
/// Alohida `notifications` tuguni yaratilsa, har bir amalda qo'shimcha
/// yozuv ketardi va tugun yillar davomida cheksiz o'sardi.
///
/// NEGA TARIXDAN EMAS: tarix endi alohida tugunda va ro'yxat so'roviga
/// tushmaydi (aynan shu narsa trafikni kamaytirish uchun qilingan). Shu
/// sabab bildirishnoma buyurtmaning O'ZIDAGI hodisa belgilaridan
/// quriladi — ular soni qat'iy va o'smaydi.
///
/// [currentActorId] — o'z harakati bildirishnoma bo'lib qaytmasligi uchun.
/// [since] — shu vaqtdan keyingi hodisalar.
List<AppNotification> buildNotifications({
  required List<Order> orders,
  required String currentActorId,
  required int since,
  int limit = 50,
}) {
  final result = <AppNotification>[];

  void add({
    required Order order,
    required NotificationType type,
    required int at,
    required String by,
    required String byName,
    String body = '',
  }) {
    if (at < since) return;
    if (by == currentActorId) return;

    result.add(AppNotification(
      id: '${order.id}/${type.name}',
      type: type,
      orderId: order.id,
      orderCode: order.code,
      customerName: order.customerName,
      body: body,
      at: at,
      byEmployeeId: by,
      byName: byName,
    ));
  }

  for (final order in orders) {
    add(
      order: order,
      type: NotificationType.newOrder,
      at: order.createdAt,
      by: order.createdBy,
      byName: order.createdByName,
    );

    final pickedUp = order.pickedUp;
    if (pickedUp != null) {
      add(
        order: order,
        type: NotificationType.accepted,
        at: pickedUp.at,
        by: pickedUp.employeeId,
        byName: pickedUp.name,
      );
    }

    final ready = order.ready;
    if (ready != null) {
      add(
        order: order,
        type: NotificationType.readyForDelivery,
        at: ready.at,
        by: ready.employeeId,
        byName: ready.name,
      );
    }

    final delivered = order.delivered;
    if (delivered != null) {
      add(
        order: order,
        type: NotificationType.delivered,
        at: delivered.at,
        by: delivered.employeeId,
        byName: delivered.name,
        body: delivered.note ?? '',
      );
    }

    // Qayta yuvish: faqat OXIRGISI ko'rsatiladi. Bir buyurtmada bir necha
    // xizmat qaytarilsa, ro'yxatda bittasi chiqadi — to'liq ro'yxat
    // buyurtma kartasidagi tarixda ko'rinadi.
    final rewash = order.rewash;
    if (rewash != null) {
      add(
        order: order,
        type: NotificationType.rewash,
        at: rewash.at,
        by: rewash.employeeId,
        byName: rewash.name,
        body: rewash.note ?? '',
      );
    }

    final debt = order.debtPayment;
    if (debt != null) {
      add(
        order: order,
        type: NotificationType.debtSettled,
        at: debt.at,
        by: debt.employeeId,
        byName: debt.name,
        body: debt.note ?? '',
      );
    }
  }

  // Eng yangisi birinchi.
  result.sort((a, b) => b.at.compareTo(a.at));
  return result.length > limit ? result.sublist(0, limit) : result;
}
