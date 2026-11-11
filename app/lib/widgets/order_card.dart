import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/staff_permission.dart';
import '../models/work_section.dart';
import '../screens/orders/order_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../ui/surfaces.dart';
import '../utils/delivery_sort.dart';
import '../utils/money.dart';
import '../utils/order_sections.dart';
import 'phone_link.dart';
import 'stage_visuals.dart';

/// Ro'yxatdagi buyurtma kartasi.
///
/// Bo'limdan ochilganda kartada FAQAT shu bo'limga tegishli xizmatlar
/// nomi bilan ko'rinadi. Boshqa bo'limlardagi xizmatlar pastda kichik
/// belgilar bilan ("2 ta qadoqlashda, 1 ta tayyor") — ular boshqa
/// xodimning ishi va ro'yxatni to'ldirib yubormasligi kerak.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.user,
    this.section,
    this.distanceMeters,
    this.place,
    this.showPrice = false,
  });

  final Order order;
  final AppUser user;

  /// Karta qaysi bo'limda — ochilgan buyurtmada shu bo'limning ishi
  /// ko'rsatiladi.
  final WorkSection? section;

  /// "Manzil bo'yicha" saralanganda — dastavchikdan masofa.
  final double? distanceMeters;

  /// Berilsa — buyurtmaning joyi belgi bilan ko'rsatiladi (qidiruvda).
  final OrderPlace? place;

  /// Narx ko'rsatilsinmi (topshirish va qidiruvda).
  final bool showPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badge = deadlineBadge(order);
    final mine = [
      for (final i in order.items)
        if (itemBelongsTo(i, section)) i,
    ];
    final others = [
      for (final i in order.items)
        if (!itemBelongsTo(i, section)) i,
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: order.id,
          user: user,
          section: section,
        ),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.code,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: context.colorPrimaryInk,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.customerName.isEmpty ? 'Mijoz' : order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (place != null) ...[
                const SizedBox(width: 8),
                _placePill(place!),
              ] else if (badge != null) ...[
                const SizedBox(width: 8),
                TonePill(
                  label: badge.label,
                  tone: badge.tone,
                  icon: Icons.event_rounded,
                  dense: true,
                ),
              ],
            ],
          ),
          if (order.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            _IconLine(
              icon: Icons.place_outlined,
              text: distanceMeters == null
                  ? order.address
                  : '${order.address} · ${formatDistance(distanceMeters!)}',
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PhoneLink(
                    phone: order.customerPhone,
                    masked: !user.access.can(StaffPermission.viewPhone),
                    iconSize: 14,
                    compact: true,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              if (showPrice && order.totalPrice > 0)
                Text(
                  formatSom(order.totalPrice),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
            ],
          ),
          if (order.items.isEmpty) ...[
            const SizedBox(height: 10),
            const TonePill(
              label: 'Xizmat hali qo\'shilmagan',
              tone: StageTone.warning,
              icon: Icons.playlist_add_rounded,
              dense: true,
            ),
          ] else if (section != null) ...[
            if (mine.isNotEmpty) ...[
              const SizedBox(height: 10),
              _ItemLines(items: mine),
            ],
            if (others.isNotEmpty) ...[
              const SizedBox(height: 10),
              _OtherStages(items: others),
            ],
          ] else ...[
            const SizedBox(height: 10),
            _OtherStages(items: order.items, showAll: true),
          ],
        ],
      ),
    );
  }

  Widget _placePill(OrderPlace place) {
    final v = placeVisual(place);
    return TonePill(label: v.label, tone: v.tone, icon: v.icon, dense: true);
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: context.colorTextSecondary),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Shu bo'limdagi xizmatlar — har biri bitta qatorda.
class _ItemLines extends StatelessWidget {
  const _ItemLines({required this.items});

  final List<OrderItem> items;

  static const _maxLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = items.take(_maxLines).toList();
    final hidden = items.length - shown.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (final item in shown) _line(context, theme, item),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('yana $hidden ta xizmat',
                    style: theme.textTheme.bodySmall),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, ThemeData theme, OrderItem item) {
    final visual = ItemStage.of(item).visual;
    final ink = visual.tone.ink(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(visual.icon, size: 15, color: ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          if (!item.hasNumericMeasure && item.status.isWashStage)
            const TonePill(
              label: 'O\'lchanmagan',
              tone: StageTone.danger,
              dense: true,
            )
          else if (item.hajm.isNotEmpty)
            Flexible(
              child: Text(
                item.hajm,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFeatures: AppFonts.tabular),
              ),
            ),
          const SizedBox(width: 8),
          Text(
            visual.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Boshqa bo'limlardagi xizmatlar — faqat belgi va soni.
class _OtherStages extends StatelessWidget {
  const _OtherStages({required this.items, this.showAll = false});

  final List<OrderItem> items;
  final bool showAll;

  @override
  Widget build(BuildContext context) {
    final counts = <ItemStage, int>{};
    for (final item in items) {
      final stage = ItemStage.of(item);
      counts[stage] = (counts[stage] ?? 0) + 1;
    }
    final stages = ItemStage.values.where(counts.containsKey).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!showAll)
          Text(
            'Boshqa bo\'limda:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        for (final stage in stages)
          Tooltip(
            message:
                t('${counts[stage]} ta: ${stage.visual.label.toLowerCase()}'),
            child: TonePill(
              label: showAll
                  ? '${counts[stage]} ${stage.visual.label.toLowerCase()}'
                  : '${counts[stage]}',
              tone: stage.visual.tone,
              icon: stage.visual.icon,
              dense: true,
            ),
          ),
      ],
    );
  }
}
