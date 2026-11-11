import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    required this.valueLabel,
    this.highlighted = false,
  });

  /// Ustun ostidagi yorliq ("Du").
  final String label;
  final double value;

  /// Bosilganda ko'rsatiladigan qiymat ("1,2 mln").
  final String valueLabel;

  /// Bugungi kun — to'liq rangda, qolganlari xiraroq.
  final bool highlighted;
}

/// Kichik ustunli grafik (bitta ko'rsatkich, 7–12 ustun).
///
/// Ustunlar ingichka, uchi yumaloq; qiymat faqat eng balandida va
/// tanlanganida yoziladi — har bir ustun ustidagi raqam o'qishni
/// qiyinlashtiradi. Ustun bosilsa uning qiymati chiqadi.
class MiniBarChart extends StatefulWidget {
  const MiniBarChart({
    super.key,
    required this.bars,
    required this.color,
    this.height = 150,
  });

  final List<BarDatum> bars;
  final Color color;
  final double height;

  @override
  State<MiniBarChart> createState() => _MiniBarChartState();
}

class _MiniBarChartState extends State<MiniBarChart> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bars = widget.bars;
    final maxValue = bars.fold<double>(0, (m, b) => math.max(m, b.value));
    final maxIndex =
        maxValue <= 0 ? -1 : bars.indexWhere((b) => b.value == maxValue);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: context.colorTextSecondary,
      fontFeatures: AppFonts.tabular,
    );

    return SizedBox(
      height: widget.height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < bars.length; i++)
            Expanded(
              child: Semantics(
                label: t('${bars[i].label}: ${bars[i].valueLabel}'),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = _selected == i ? null : i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 18,
                        child: (_selected == i || (_selected == null && i == maxIndex))
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  bars[i].valueLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: context.colorTextPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: AppFonts.tabular,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final ratio = maxValue <= 0 ? 0.0 : bars[i].value / maxValue;
                            final h = math.max(ratio * c.maxHeight, bars[i].value > 0 ? 4.0 : 2.0);
                            final active = bars[i].highlighted || _selected == i;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                width: math.min(22, c.maxWidth * 0.55),
                                height: h,
                                decoration: BoxDecoration(
                                  color: bars[i].value <= 0
                                      ? context.colorBorder
                                      : active
                                          ? widget.color
                                          : widget.color.withValues(alpha: 0.38),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bars[i].label,
                        style: bars[i].highlighted
                            ? labelStyle?.copyWith(
                                color: context.colorTextPrimary,
                                fontWeight: FontWeight.w700,
                              )
                            : labelStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Katta summani ixcham yozadi: "1,2 mln", "850 ming".
String compactSom(double v) {
  if (v >= 1000000) {
    final m = v / 1000000;
    return '${m >= 10 ? m.round() : (m * 10).round() / 10} mln'.replaceAll('.', ',');
  }
  if (v >= 1000) return '${(v / 1000).round()} ming';
  return v.round().toString();
}
