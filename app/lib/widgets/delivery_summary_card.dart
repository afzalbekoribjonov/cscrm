import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/staff_access.dart';
import '../models/staff_permission.dart';
import '../screens/orders/order_detail_screen.dart';
import '../theme/app_colors.dart';
import 'item_measurement_form.dart' show fmtSom;
import 'phone_link.dart';

/// Yetkazilgan buyurtma uchun moliyaviy xulosa kartasi - Daromad va faollik
/// bo'limida ishlatiladi. Odatiy [OrderCard]dan farqli o'laroq faqat to'lov
/// bilan bog'liq ma'lumotlarni ko'rsatadi: buyurtma narxi, dastavchik
/// qabul qilgan summa va ular orasidagi skidka (agar bo'lsa).
class DeliverySummaryCard extends StatelessWidget {
  const DeliverySummaryCard({
    super.key,
    required this.order,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final Order order;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final received = order.paymentAmount ?? 0;

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
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.code,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              PhoneLink(
                phone: order.customerPhone,
                masked: !access.can(StaffPermission.viewPhone),
              ),
              const Divider(height: 20),
              _row(context, 'Buyurtma narxi', fmtSom(order.totalPrice)),
              const SizedBox(height: 6),
              _row(context, 'Dastavchik oldi', fmtSom(received)),
              if (order.debtAmount > 0) ...[
                const SizedBox(height: 6),
                _row(
                  context,
                  'Qarz',
                  fmtSom(order.debtAmount),
                  valueColor: AppColors.danger,
                ),
              ],
              if (order.discountAmount > 0) ...[
                const SizedBox(height: 6),
                _row(
                  context,
                  'Skidka qilindi',
                  fmtSom(order.discountAmount),
                  valueColor: AppColors.warning,
                ),
              ],
              if (order.debtAmount <= 0 && order.discountAmount <= 0) ...[
                const SizedBox(height: 6),
                Text(
                  'To\'liq to\'landi',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.success, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value,
      {Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: valueColor),
        ),
      ],
    );
  }
}
