import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../models/app_user.dart';
import '../models/order.dart';
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
/// Karta HAR DOIM bir xil balandlikda: raqam va mijoz, manzil (bitta
/// qator), telefon va pastda xizmatlar — faqat BELGI va SON bilan
/// ("navbatda 2, qadoqlashda 3, tayyor 1"). Xizmatlarning nomi, o'lchami
/// va holati buyurtma ichida ko'rinadi: ro'yxatda ular kartalarni har xil
/// uzunlikka cho'zib, ro'yxatni o'qib bo'lmas holga keltirardi.
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
          const SizedBox(height: 6),
          _IconLine(
            icon: Icons.place_outlined,
            text: order.address.isEmpty
                ? 'Manzil kiritilmagan'
                : distanceMeters == null
                    ? order.address
                    : '${order.address} · ${formatDistance(distanceMeters!)}',
            muted: order.address.isEmpty,
          ),
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
          const SizedBox(height: 10),
          StageCounts(order: order, section: section),
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
  const _IconLine({required this.icon, required this.text, this.muted = false});

  final IconData icon;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? context.colorTextTertiary : context.colorTextSecondary;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Xizmatlar — faqat belgi va soni, bitta qatorda.
///
/// Yuvish bo'limida o'lchanmagan xizmatlar soni alohida qizil belgi bilan
/// ko'rsatiladi — bu ro'yxatda ham kerakli ma'lumot.
class StageCounts extends StatelessWidget {
  const StageCounts({super.key, required this.order, this.section});

  final Order order;
  final WorkSection? section;

  @override
  Widget build(BuildContext context) {
    if (order.items.isEmpty) {
      return const TonePill(
        label: 'Xizmat qo\'shilmagan',
        tone: StageTone.warning,
        icon: Icons.playlist_add_rounded,
        dense: true,
      );
    }
    final counts = <ItemStage, int>{};
    var unmeasured = 0;
    for (final item in order.items) {
      final stage = ItemStage.of(item);
      counts[stage] = (counts[stage] ?? 0) + 1;
      if (item.status.isWashStage && !item.hasNumericMeasure && !item.isHanded) {
        unmeasured++;
      }
    }
    final chips = <Widget>[
      for (final stage in ItemStage.values)
        if (counts.containsKey(stage))
          _CountChip(
            icon: stage.visual.icon,
            tone: stage.visual.tone,
            count: counts[stage]!,
            tooltip: '${counts[stage]} ta: ${stage.visual.label.toLowerCase()}',
          ),
      if (section == WorkSection.yuvish && unmeasured > 0)
        _CountChip(
          icon: Icons.straighten_rounded,
          tone: StageTone.danger,
          count: unmeasured,
          tooltip: '$unmeasured ta o\'lchanmagan',
        ),
    ];
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.tone,
    required this.count,
    required this.tooltip,
  });

  final IconData icon;
  final StageTone tone;
  final int count;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final ink = tone.ink(context);
    return Tooltip(
      message: t(tooltip),
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 4, 9, 4),
        decoration: BoxDecoration(
          color: tone.soft(context),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: ink),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.1,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
