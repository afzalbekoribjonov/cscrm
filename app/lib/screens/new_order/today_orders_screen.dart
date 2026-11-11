import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../models/pending_order.dart';
import '../../models/work_section.dart';
import '../../services/order_sync_service.dart';
import '../../services/pending_order_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/order_sections.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/order_card.dart';
import '../home/section_scaffold.dart';
import 'new_order_screen.dart';

/// "Yangi" bo'limi — BUGUN qabul qilingan buyurtmalar ro'yxati.
///
/// Yangi buyurtma pastki o'ng burchakdagi "+" tugmasi orqali alohida
/// sahifada yaratiladi. Internet yo'q paytda yaratilganlari ro'yxat
/// tepasida "Yuborilmoqda" belgisi bilan turadi.
class TodayOrdersScreen extends StatelessWidget {
  const TodayOrdersScreen({
    super.key,
    required this.sections,
    required this.user,
    required this.todaysOrders,
  });

  final OrderSections sections;
  final AppUser user;
  final List<Order> todaysOrders;

  @override
  Widget build(BuildContext context) {
    final orders = [...todaysOrders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ValueListenableBuilder<List<PendingOrder>>(
      valueListenable: PendingOrderStore.instance.orders,
      builder: (context, pending, _) {
        final total = orders.length + pending.length;
        return SectionScaffold(
          user: user,
          section: WorkSection.yangi,
          sections: sections,
          title: 'Yangi buyurtmalar',
          subtitle: total == 0 ? 'Bugun hali buyurtma yo\'q' : 'Bugun: $total ta',
          floatingActionButton: FloatingActionButton(
            tooltip: t('Yangi buyurtma'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NewOrderScreen(user: user, sections: sections),
            )),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
          body: total == 0
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  tone: StageTone.brand,
                  title: 'Bugun hali buyurtma qabul qilinmagan',
                  message: 'Yangi buyurtma qo\'shish uchun pastdagi "+" '
                      'tugmasini bosing.',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(Gap.page, 8, Gap.page,
                      96 + MediaQuery.of(context).padding.bottom),
                  children: [
                    if (pending.isNotEmpty) ...[
                      _PendingHeader(count: pending.length),
                      const SizedBox(height: 10),
                      for (final p in pending.reversed) ...[
                        _PendingCard(order: p),
                        const SizedBox(height: 10),
                      ],
                    ],
                    for (final order in orders) ...[
                      OrderCard(
                        key: ValueKey(order.id),
                        order: order,
                        user: user,
                        section: WorkSection.yangi,
                        showPrice: true,
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _PendingHeader extends StatelessWidget {
  const _PendingHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: OrderSyncService.instance.state,
      builder: (context, state, _) {
        final offline = state == SyncState.offline;
        final tone = offline ? StageTone.warning : StageTone.info;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tone.soft(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(offline ? Icons.cloud_off_rounded : Icons.cloud_upload_outlined,
                  color: tone.ink(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  offline
                      ? '$count ta buyurtma internet tiklanishini kutmoqda'
                      : '$count ta buyurtma yuborilmoqda…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tone.ink(context),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.order});

  final PendingOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const IconTile(icon: Icons.schedule_send_rounded, tone: StageTone.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customerName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${order.items.length} ta xizmat · '
                  '${UzDates.time(UzDates.fromMillis(order.createdAt))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ],
            ),
          ),
          const TonePill(
            label: 'Raqam kutilmoqda',
            tone: StageTone.info,
            dense: true,
          ),
        ],
      ),
    );
  }
}
