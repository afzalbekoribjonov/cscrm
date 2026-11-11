import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/item_status.dart';
import '../../models/order.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../utils/order_sections.dart';
import '../../widgets/order_list_view.dart';
import '../home/section_scaffold.dart';
import 'unmeasured_screen.dart';

/// "Yuvish" bo'limi — sexga kirgan buyurtmalarning yuvilishi kerak
/// bo'lgan xizmatlari.
///
/// Ilgari tepada 4 ta katta statistika kartasi turardi — ekranning
/// yarmini egallardi. Endi faqat bitta narsa ko'rsatiladi: o'lchanmagan
/// xizmatlar soni (qizil), u bosilganda ularning ro'yxati ochiladi.
class WashScreen extends StatelessWidget {
  const WashScreen({super.key, required this.sections, required this.user});

  final OrderSections sections;
  final AppUser user;

  /// Qayta yuvishga qaytganlar — tepada: ular kechikkan ish.
  List<Order> _sorted() {
    final list = [...sections.wash];
    int rank(Order o) =>
        o.items.any((i) => i.status == ItemStatus.qaytaYuvildi) ? 0 : 1;
    list.sort((a, b) => rank(a).compareTo(rank(b)));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final orders = _sorted();
    final items = orders.fold<int>(
        0, (s, o) => s + o.items.where((i) => i.status.isWashStage).length);
    final unmeasured = sections.unmeasured.length;

    return SectionScaffold(
      user: user,
      section: WorkSection.yuvish,
      sections: sections,
      subtitle: orders.isEmpty
          ? 'Navbat bo\'sh'
          : '${orders.length} ta buyurtma · $items ta xizmat',
      body: OrderListView(
        orders: orders,
        user: user,
        section: WorkSection.yuvish,
        emptyIcon: Icons.local_laundry_service_outlined,
        emptyTitle: 'Yuvish navbatida buyurtma yo\'q',
        emptyMessage: 'Sexga qabul qilingan buyurtmalar shu yerga tushadi.',
        header: unmeasured == 0
            ? null
            : AlertStrip(
                icon: Icons.straighten_rounded,
                tone: StageTone.danger,
                text: '$unmeasured ta xizmat o\'lchanmagan',
                trailing: 'Ko\'rish',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UnmeasuredScreen(
                    refs: sections.unmeasured,
                    user: user,
                  ),
                )),
              ),
      ),
    );
  }
}
