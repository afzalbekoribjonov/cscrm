import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../utils/order_sections.dart';
import '../../widgets/order_list_view.dart';
import '../home/section_scaffold.dart';

/// "Omborxona" — tayyor bo'lganidan keyin belgilangan kundan (standart
/// 15) ortiq olib ketilmagan buyurtmalar.
///
/// Alohida bo'lim, alohida vakolat bilan: ombor xodimi faqat shu yerni
/// ko'radi va shu yerdan topshiradi. Eng uzoq kutayotgan — tepada.
class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({
    super.key,
    required this.sections,
    required this.user,
  });

  final OrderSections sections;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final orders = [...sections.warehouse]
      ..sort((a, b) => (a.readyAt ?? 0).compareTo(b.readyAt ?? 0));
    final days = sections.policies.warehouseDays;

    return SectionScaffold(
      user: user,
      section: WorkSection.ombor,
      sections: sections,
      title: 'Omborxona',
      subtitle: orders.isEmpty
          ? 'Omborda buyurtma yo\'q'
          : '${orders.length} ta buyurtma omborda',
      body: OrderListView(
        orders: orders,
        user: user,
        section: WorkSection.ombor,
        showPrice: true,
        placeOf: (_) => OrderPlace.warehouse,
        emptyIcon: Icons.warehouse_outlined,
        emptyTitle: 'Omborda buyurtma yo\'q',
        emptyMessage: 'Tayyor bo\'lganidan $days kun o\'tib olib ketilmagan '
            'buyurtmalar shu yerga tushadi.',
        header: orders.isEmpty
            ? null
            : AlertStrip(
                icon: Icons.schedule_rounded,
                tone: StageTone.warehouse,
                text: 'Tayyor bo\'lganiga $days kundan ko\'p bo\'lgan '
                    'buyurtmalar',
              ),
      ),
    );
  }
}

/// Buyurtma necha kundan beri omborda.
int daysInWarehouse(Order order, int thresholdDays, DateTime now) {
  final ready = order.readyAt;
  if (ready == null) return 0;
  final since = DateTime.fromMillisecondsSinceEpoch(ready)
      .add(Duration(days: thresholdDays));
  final d = now.difference(since).inDays;
  return d < 0 ? 0 : d;
}
