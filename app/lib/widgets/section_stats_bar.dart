import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bo'lim tepasidagi bitta ko'rsatkich.
class SectionStat {
  const SectionStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.emphasise = false,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  /// Diqqat talab qiladigan ko'rsatkich — rangli fon bilan ajratiladi.
  final bool emphasise;
}

/// Bo'lim ro'yxati ustidagi ko'rsatkichlar qatori.
///
/// Kenglikka MOSLASHADI: kartalar `Wrap` ichida, har biriga eng kam
/// kenglik berilgan. Tor telefonda ikkitadan, kengroq ekranda esa
/// yonma-yon joylashadi — hech qayerda siqilib, matn kesilmaydi.
///
/// Qat'iy `Row` ataylab ishlatilmagan: uchta-to'rtta karta tor ekranda
/// bir-birini ezib, raqamlar o'qib bo'lmaydigan holga kelardi.
class SectionStatsBar extends StatelessWidget {
  const SectionStatsBar({super.key, required this.stats});

  final List<SectionStat> stats;

  /// Bitta kartaning eng kam kengligi. Shundan kelib chiqib bir qatorga
  /// nechtasi sig'ishi hisoblanadi.
  static const double _minCardWidth = 148;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final available = constraints.maxWidth;

        // Bir qatorga nechta sig'adi — lekin ko'rsatkichlar sonidan
        // oshmaydi va kamida bittasi bo'ladi.
        var perRow = ((available + gap) / (_minCardWidth + gap)).floor();
        perRow = perRow.clamp(1, stats.length);

        final cardWidth = (available - gap * (perRow - 1)) / perRow;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: cardWidth,
                child: _StatCard(stat: stat),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final SectionStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: stat.emphasise
            ? stat.color.withValues(alpha: 0.10)
            : context.colorSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: stat.emphasise
              ? stat.color.withValues(alpha: 0.38)
              : context.colorBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: stat.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(stat.icon, size: 16, color: stat.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stat.value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    color: stat.emphasise ? stat.color : null,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  stat.label,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
