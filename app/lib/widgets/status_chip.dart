import 'package:flutter/material.dart';

import '../models/order_status.dart';
import '../theme/app_colors.dart';

Color statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.olibKelish:
      return AppColors.statusPickup;
    case OrderStatus.ishniBoshlash:
      return AppColors.statusReady;
    case OrderStatus.yuvishda:
      return AppColors.statusWashing;
    case OrderStatus.yetgazishgaTayyor:
      return AppColors.statusReadyDelivery;
    case OrderStatus.yetgazildi:
      return AppColors.statusDelivered;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
