import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../ui/choice_chips_bar.dart';
import '../../ui/metric_pills.dart';
import '../../utils/order_sections.dart';
import '../../utils/unit_amounts.dart';
import '../../utils/wash_sort.dart';
import '../../widgets/order_list_view.dart';
import '../home/section_scaffold.dart';
import 'unmeasured_screen.dart';

/// "Yuvish" bo'limi — sexga kirgan buyurtmalarning yuvilishi kerak
/// bo'lgan xizmatlari.
///
/// Tepada IXCHAM ikki qator (2026-11-20):
///  1. Ko'rsatkichlar — qizil "N ta" (o'lchanmaganlar, bosilsa
///     ro'yxati ochiladi) va hozir yuvishdagi o'lchangan xizmatlarning
///     jami hajmi aniq so'z bilan: "145 m² · 50 m · 3 kg · 6 dona ·
///     4 kichik · 8 katta".
///  2. Saralash — Topshirish kuni, Sana, Qimmat, Arzon.
class WashScreen extends StatefulWidget {
  const WashScreen({super.key, required this.sections, required this.user});

  final OrderSections sections;
  final AppUser user;

  @override
  State<WashScreen> createState() => _WashScreenState();
}

class _WashScreenState extends State<WashScreen> {
  var _sort = WashSort.deadline;

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections;
    final orders = sortWashOrders(sections.wash, _sort);
    final items = orders.fold<int>(
        0,
        (s, o) =>
            s + o.items.where((i) => i.status.isWashStage && !i.isHanded).length);

    return SectionScaffold(
      user: widget.user,
      section: WorkSection.yuvish,
      sections: sections,
      subtitle: orders.isEmpty
          ? 'Navbat bo\'sh'
          : '${orders.length} ta buyurtma · $items ta xizmat',
      body: Column(
        // Ko'rsatkichlar va saralash chapdan boshlanadi (o'rtada emas).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (orders.isNotEmpty) ...[
            _WashMetrics(
              orders: orders,
              unmeasured: sections.unmeasured.length,
              onOpenUnmeasured: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UnmeasuredScreen(
                    refs: sections.unmeasured,
                    user: widget.user,
                  ),
                ),
              ),
            ),
            ChoiceChipsBar<WashSort>(
              values: WashSort.values,
              value: _sort,
              labelOf: (s) => s.label,
              onChanged: (s) => setState(() => _sort = s),
            ),
          ],
          Expanded(
            child: OrderListView(
              orders: orders,
              user: widget.user,
              section: WorkSection.yuvish,
              emptyIcon: Icons.local_laundry_service_outlined,
              emptyTitle: 'Yuvish navbatida buyurtma yo\'q',
              emptyMessage:
                  'Sexga qabul qilingan buyurtmalar shu yerga tushadi.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Ko'rsatkichlar qatori: o'lchanmaganlar (qizil) va jami hajm.
class _WashMetrics extends StatelessWidget {
  const _WashMetrics({
    required this.orders,
    required this.unmeasured,
    required this.onOpenUnmeasured,
  });

  final List<Order> orders;
  final int unmeasured;
  final VoidCallback onOpenUnmeasured;

  @override
  Widget build(BuildContext context) {
    final volume = washVolume(orders);
    final pills = <Widget>[
      if (unmeasured > 0)
        MetricPill(
          icon: Icons.error_rounded,
          tone: StageTone.danger,
          value: '$unmeasured ta',
          semanticLabel: t('$unmeasured ta xizmat o\'lchanmagan. Ro\'yxatni ochish'),
          onTap: onOpenUnmeasured,
        ),
      for (final (unit, qty) in volume.entries)
        MetricPill(value: formatAmount(qty), unit: unitWord(unit)),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return MetricStrip(children: pills);
  }
}
