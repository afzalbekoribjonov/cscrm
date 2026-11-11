import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../models/app_user.dart';
import '../models/order.dart';
import '../models/work_section.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../ui/surfaces.dart';
import '../utils/order_sections.dart';
import 'order_card.dart';

/// Bo'lim ro'yxati: tepada ixtiyoriy sarlavha qismi, pastda buyurtma
/// kartalari. Bo'sh bo'lsa — nima uchun bo'shligini aytadigan holat.
class OrderListView extends StatelessWidget {
  const OrderListView({
    super.key,
    required this.orders,
    required this.user,
    required this.section,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptyMessage,
    this.header,
    this.distanceOf,
    this.placeOf,
    this.showPrice = false,
    this.bottomPadding = 24,
  });

  final List<Order> orders;
  final AppUser user;
  final WorkSection section;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptyMessage;

  /// Ro'yxat ustidagi qism (filtr, ogohlantirish).
  final Widget? header;

  final double? Function(Order order)? distanceOf;
  final OrderPlace? Function(Order order)? placeOf;
  final bool showPrice;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom + bottomPadding;
    if (orders.isEmpty) {
      return Column(
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 8, Gap.page, 0),
              child: header!,
            ),
          Expanded(
            child: EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(Gap.page, 8, Gap.page, bottom),
      itemCount: orders.length + (header == null ? 0 : 1),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header!;
        final order = orders[index - (header == null ? 0 : 1)];
        return OrderCard(
          key: ValueKey(order.id),
          order: order,
          user: user,
          section: section,
          distanceMeters: distanceOf?.call(order),
          place: placeOf?.call(order),
          showPrice: showPrice,
        );
      },
    );
  }
}

/// Ro'yxat ustidagi bosiladigan ogohlantirish qatori ("3 ta o'lchanmagan").
class AlertStrip extends StatelessWidget {
  const AlertStrip({
    super.key,
    required this.icon,
    required this.text,
    required this.tone,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final StageTone tone;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = tone.ink(context);
    return Material(
      color: tone.soft(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: ink, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}
