import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/item_status.dart';
import '../../models/work_section.dart';
import '../../utils/order_sections.dart';
import '../../widgets/order_list_view.dart';
import '../home/section_scaffold.dart';

/// "Qadoqlash" bo'limi — kamida bitta xizmati qadoqlashda turgan
/// buyurtmalar.
class PackagingScreen extends StatelessWidget {
  const PackagingScreen({
    super.key,
    required this.sections,
    required this.user,
  });

  final OrderSections sections;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final orders = sections.packaging;
    final items = orders.fold<int>(
        0,
        (s, o) =>
            s + o.items.where((i) => i.status == ItemStatus.qadoqlashda).length);

    return SectionScaffold(
      user: user,
      section: WorkSection.qadoqlash,
      sections: sections,
      subtitle: orders.isEmpty
          ? 'Navbat bo\'sh'
          : '${orders.length} ta buyurtma · $items ta xizmat',
      body: OrderListView(
        orders: orders,
        user: user,
        section: WorkSection.qadoqlash,
        emptyIcon: Icons.inventory_2_outlined,
        emptyTitle: 'Qadoqlash navbatida buyurtma yo\'q',
        emptyMessage: 'Yuvilgan xizmatlar shu yerga tushadi.',
      ),
    );
  }
}
