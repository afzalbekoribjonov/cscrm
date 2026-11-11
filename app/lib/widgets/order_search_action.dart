import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../models/staff_access.dart';
import '../models/work_section.dart';
import '../screens/search/order_search_screen.dart';
import '../services/policy_service.dart';
import '../utils/order_sections.dart';

/// Berilgan buyurtmalar ichida qidiruv tugmasi (masalan hisobot
/// ekranidagi davr buyurtmalari) — umumiy qidiruv sahifasini ochadi.
class OrderSearchAction extends StatelessWidget {
  const OrderSearchAction({
    super.key,
    required this.orders,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    this.section,
  });

  final List<Order> orders;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;
  final WorkSection? section;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: t('Qidiruv'),
      icon: const Icon(Icons.search_rounded),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderSearchScreen(
          sections: OrderSections.from(
            orders,
            policies: PolicyCenter.instance.value,
          ),
          user: AppUser(id: currentUserId, name: currentUserName, access: access),
          section: section,
        ),
      )),
    );
  }
}
