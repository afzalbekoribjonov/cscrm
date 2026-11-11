import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../widgets/order_card.dart';

/// Oddiy buyurtmalar ro'yxati sahifasi — bosh sahifadagi ogohlantirishlardan
/// ("Muddati o'tgan", "Qayta yuvishda") ochiladi.
class OrderListScreen extends StatelessWidget {
  const OrderListScreen({
    super.key,
    required this.title,
    required this.orders,
    required this.user,
  });

  final String title;
  final List<Order> orders;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text('${orders.length} ta buyurtma', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: orders.isEmpty
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Ro\'yxat bo\'sh',
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(Gap.page, 8, Gap.page,
                  24 + MediaQuery.of(context).padding.bottom),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => OrderCard(
                order: orders[i],
                user: user,
                showPrice: true,
              ),
            ),
    );
  }
}
