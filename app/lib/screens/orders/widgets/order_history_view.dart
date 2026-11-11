import 'package:flutter/material.dart' hide Text;

import '../../../l10n/text.dart';
import '../../../models/order_history_entry.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/uz_dates.dart';
import 'order_view_common.dart';

class HistoryTimeline extends StatelessWidget {
  const HistoryTimeline({super.key, required this.entries});

  final List<OrderHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text('Hali hech qanday o\'zgarish yo\'q',
          style: Theme.of(context).textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          HistoryRow(
            index: i + 1,
            isLast: i == entries.length - 1,
            entry: entries[i],
          ),
      ],
    );
  }
}

class HistoryRow extends StatelessWidget {
  const HistoryRow({
    super.key,
    required this.index,
    required this.isLast,
    required this.entry,
  });

  final int index;
  final bool isLast;
  final OrderHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = historyVisual(entry);
    final time = UzDates.dateTime(UzDates.fromMillis(entry.at));
    // Eski yozuvlarda boshqaruvchi "Admin" deb yozilgan.
    final who = entry.byName == "Admin" ? "Boshqaruvchi" : entry.byName;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: visual.tone.soft(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(visual.icon, size: 13, color: visual.tone.ink(context)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: context.colorBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 4 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$index. ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colorTextSecondary,
                          ),
                        ),
                        TextSpan(
                          text: visual.text,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$time · $who',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.colorTextSecondary),
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
