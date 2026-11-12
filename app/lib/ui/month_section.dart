import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../utils/uz_dates.dart';
import 'surfaces.dart';

/// Bitta oy: sarlavhada oy nomi, yozuvlar soni va oydagi jami summa.
/// Bosilsa ochiladi/yopiladi — ro'yxat uzun bo'lsa ham kerakli oy bir
/// qarashda topiladi.
class MonthSection extends StatefulWidget {
  const MonthSection({
    super.key,
    required this.month,
    required this.count,
    required this.total,
    required this.tone,
    required this.children,
    this.initiallyOpen = false,
    this.countLabel = 'ta',
  });

  final DateTime month;
  final int count;
  final double total;
  final StageTone tone;
  final List<Widget> children;
  final bool initiallyOpen;
  final String countLabel;

  @override
  State<MonthSection> createState() => _MonthSectionState();
}

class _MonthSectionState extends State<MonthSection> {
  late var _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final current =
        widget.month.year == now.year && widget.month.month == now.month;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: widget.tone.soft(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          UzDates.monthsShort[widget.month.month - 1],
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: widget.tone.ink(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${widget.month.year}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: widget.tone.ink(context),
                            fontFeatures: AppFonts.tabular,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current
                              ? '${UzDates.monthYear(widget.month)} · joriy oy'
                              : UzDates.monthYear(widget.month),
                          style: theme.textTheme.titleSmall,
                        ),
                        Text('${widget.count} ${widget.countLabel}',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    formatSom(widget.total),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: widget.tone.ink(context),
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: context.colorTextSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Divider(height: 1, color: context.colorBorder),
            for (var i = 0; i < widget.children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 14, color: context.colorBorder),
              widget.children[i],
            ],
          ],
        ],
      ),
    );
  }
}
