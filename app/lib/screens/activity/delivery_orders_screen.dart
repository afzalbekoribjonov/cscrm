import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/staff_access.dart';
import '../../widgets/delivery_summary_card.dart';

/// Berilgan buyurtmalar ro'yxatini moliyaviy xulosa kartalari
/// ([DeliverySummaryCard]) sifatida ko'rsatadi - Daromad va faollik
/// bo'limidagi "Ko'proq ko'rish" va xodimning shaxsiy faoliyat ekranidan
/// ochiladi. Filtrlash chaqiruvchi tomonda ([deliveredOn]) bajariladi, bu
/// ekran faqat tayyor ro'yxatni chizadi.
class DeliveryOrdersScreen extends StatelessWidget {
  const DeliveryOrdersScreen({
    super.key,
    required this.title,
    required this.orders,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String title;
  final List<Order> orders;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: orders.isEmpty
          ? Center(
              child: Text(
                'Bu davrda yetkazilgan buyurtma yo\'q',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) => DeliverySummaryCard(
                order: orders[index],
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                access: access,
              ),
            ),
    );
  }
}
