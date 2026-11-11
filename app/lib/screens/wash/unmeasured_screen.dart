import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/order_sections.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/stage_visuals.dart';
import '../orders/order_detail_screen.dart';

/// O'lchanmagan xizmatlar ro'yxati — "Yuvish" bo'limidagi qizil belgidan
/// ochiladi. Xizmat bosilsa — u turgan buyurtma ochiladi.
class UnmeasuredScreen extends StatelessWidget {
  const UnmeasuredScreen({super.key, required this.refs, required this.user});

  final List<OrderItemRef> refs;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Eng eski buyurtma — tepada: u eng uzoq kutib qolgan.
    final sorted = [...refs]
      ..sort((a, b) => a.order.createdAt.compareTo(b.order.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('O\'lchanmagan xizmatlar'),
            Text('${refs.length} ta', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: sorted.isEmpty
          ? const EmptyState(
              icon: Icons.verified_outlined,
              tone: StageTone.success,
              title: 'Hamma xizmat o\'lchangan',
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(Gap.page, 8, Gap.page,
                  24 + MediaQuery.of(context).padding.bottom),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final ref = sorted[i];
                final visual = ItemStage.of(ref.item).visual;
                return AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      orderId: ref.order.id,
                      user: user,
                      section: WorkSection.yuvish,
                    ),
                  )),
                  child: Row(
                    children: [
                      IconTile(icon: visual.icon, tone: visual.tone),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ref.item.productName,
                                style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              '${ref.order.code} · ${ref.order.customerName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${visual.label} · qabul: '
                              '${UzDates.relativeDay(UzDates.fromMillis(ref.order.createdAt))}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: visual.tone.ink(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.colorTextTertiary),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
