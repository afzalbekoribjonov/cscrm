import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_status.dart';
import '../models/staff_access.dart';
import '../models/staff_permission.dart';
import '../models/work_section.dart';
import '../screens/orders/order_detail_screen.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import 'phone_link.dart';
import 'status_chip.dart';

/// Muddatgacha qolgan (yoki undan o'tib ketgan) kunlar yorlig'i, masalan
/// "4 kun", "Bugun", "-3 kun". Muddat kiritilmagan yoki yetgazib
/// bo'lingan buyurtmalar uchun null.
String? dayBadgeText(Order order) {
  final deadline = order.deadline;
  if (deadline == null || order.status == OrderStatus.yetgazildi) return null;
  final dueDay = startOfDay(DateTime.fromMillisecondsSinceEpoch(deadline));
  final today = startOfDay(DateTime.now());
  final diff = dueDay.difference(today).inDays;
  if (diff == 0) return 'Bugun';
  return '$diff kun';
}

Color dayBadgeColor(BuildContext context, Order order) {
  final deadline = order.deadline;
  if (deadline == null || order.status == OrderStatus.yetgazildi) {
    return context.colorTextSecondary;
  }
  final dueDay = startOfDay(DateTime.fromMillisecondsSinceEpoch(deadline));
  final today = startOfDay(DateTime.now());
  final diff = dueDay.difference(today).inDays;
  if (diff <= 0) return AppColors.danger;
  if (diff <= 1) return AppColors.warning;
  return context.colorTextSecondary;
}

/// Ro'yxatlarda ko'rsatiladigan qisqa buyurtma kartasi: ID, muddat,
/// mijoz ismi, manzil va telefon raqami. Raqam ustiga bosilsa telefon
/// ilovasi ochiladi, kartaning qolgan qismiga bosilsa to'liq
/// [OrderDetailScreen] ochiladi.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    this.section,
  });

  final Order order;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  /// Karta qaysi bo'limda ko'rsatilyapti - buyurtma ochilganda faqat shu
  /// bo'limga tegishli amallar ko'rsatilishi uchun uzatiladi.
  final WorkSection? section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayText = dayBadgeText(order);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(
              orderId: order.id,
              currentUserId: currentUserId,
              currentUserName: currentUserName,
              access: access,
              section: section,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.code,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (dayText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dayBadgeColor(context, order)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        dayText,
                        style: TextStyle(
                          color: dayBadgeColor(context, order),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              if (order.address.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 15, color: context.colorTextSecondary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        order.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 3),
              Row(
                children: [
                  // Raqam qolgan bo'sh joyni to'liq egallaydi (Spacer bilan
                  // raqobatlashmaydi) - shu sabab to'liq ko'rinadi.
                  Expanded(
                    child: PhoneLink(
                      phone: order.customerPhone,
                      masked: !access.can(StaffPermission.viewPhone),
                      iconSize: 14,
                      style:
                          theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.items.isEmpty
                        ? 'Xizmatsiz'
                        : '${order.items.length} xizmat',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                  const SizedBox(width: 7),
                  StatusChip(status: order.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
