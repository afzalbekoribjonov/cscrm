import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../utils/wash_stats.dart';

final _timeFormat = DateFormat('dd.MM.yyyy, HH:mm');

/// Ko'rsatkich ortidagi ishlar ro'yxati.
///
/// "148 m² yuvilgan" degan raqamning o'zi tekshirib bo'lmaydigan
/// ma'lumot. Bu ekran o'sha raqam AYNAN qaysi xizmatlardan yig'ilganini,
/// har biri qaysi buyurtmaga tegishli ekanini va buyurtma RAQAMINI
/// ko'rsatadi — raqamni sanab chiqib solishtirish mumkin bo'lsin.
class WorkItemsScreen extends StatelessWidget {
  const WorkItemsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.color,
  });

  final String title;
  final String subtitle;
  final List<WorkItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Bir buyurtmadan bir necha xizmat chiqishi mumkin - ularni
    // guruhlab ko'rsatamiz, aks holda ro'yxat takrorlanayotgandek
    // tuyuladi.
    final byOrder = <int, List<WorkItem>>{};
    for (final item in items) {
      (byOrder[item.orderId] ??= []).add(item);
    }
    final orderIds = byOrder.keys.toList()
      ..sort((a, b) {
        final aAt = byOrder[a]!.first.at;
        final bAt = byOrder[b]!.first.at;
        return bAt.compareTo(aAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                'Bu davrda ish qayd etilmagan',
                style: theme.textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
              itemCount: orderIds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final orderId = orderIds[index];
                final group = byOrder[orderId]!;
                return _OrderGroupCard(
                  orderId: orderId,
                  items: group,
                  color: color,
                );
              },
            ),
    );
  }
}

class _OrderGroupCard extends StatelessWidget {
  const _OrderGroupCard({
    required this.orderId,
    required this.items,
    required this.color,
  });

  final int orderId;
  final List<WorkItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customer = items.first.customerName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '№$orderId',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  customer,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName,
                            style: theme.textTheme.bodyMedium),
                        Text(
                          _timeFormat.format(
                            DateTime.fromMillisecondsSinceEpoch(item.at),
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    formatVolume(item.quantity, item.unit),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
