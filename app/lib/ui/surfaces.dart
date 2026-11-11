import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Ilovaning asosiy kartasi: oq sirt, ingichka chegara, yumshoq burchak.
///
/// `Card` o'rniga shu ishlatiladi — bosilganda to'lqin effekti burchakdan
/// chiqib ketmaydi va barcha kartalar bir xil ko'rinadi.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.radius = Radii.lg,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? context.colorBorder),
    );
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? context.colorSurface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Bo'lim sarlavhasi: nom, ixtiyoriy izoh va o'ng tomonda havola.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.live = false,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, Gap.sm),
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  /// Ma'lumot jonli yangilanadi — sarlavha yonida yashil nuqta.
  final bool live;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (live) ...[
                      const SizedBox(width: 8),
                      const LiveDot(),
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Jonli ma'lumot belgisi — sekin "nafas oladigan" yashil nuqta.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = AppColors.success, this.size = 8});

  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.2,
      height: s * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = Curves.easeOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: s + s * 1.2 * v,
                height: s + s * 1.2 * v,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.35 * (1 - v)),
                ),
              ),
              Container(
                width: s,
                height: s,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rangli fondagi ikonka — menyu, ro'yxat va ko'rsatkichlar uchun.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.tone,
    this.size = 40,
    this.iconSize,
    this.radius = 12,
  });

  final IconData icon;
  final StageTone tone;
  final double size;
  final double? iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.soft(context),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize ?? size * 0.5, color: tone.ink(context)),
    );
  }
}

/// Holat belgisi: yumshoq fon + rangli matn (+ ixtiyoriy ikonka).
class TonePill extends StatelessWidget {
  const TonePill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
    this.dot = false,
  });

  final String label;
  final StageTone tone;
  final IconData? icon;
  final bool dense;

  /// Ikonka o'rniga kichik nuqta.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final ink = tone.ink(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tone.soft(context),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: ink),
            SizedBox(width: dense ? 4 : 5),
          ] else if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tone.fill, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.sans,
                color: ink,
                fontWeight: FontWeight.w700,
                fontSize: dense ? 11.5 : 12.5,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ma'lumot yo'q holati — doim NIMA UCHUN bo'shligini aytadi.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.tone = StageTone.neutral,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final StageTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: tone.soft(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: tone.ink(context)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.colorTextSecondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Bo'limga vakolati yo'q xodim ko'radigan sahifa.
///
/// Ilgari bunday xodim bo'lim ro'yxatini ko'ra olardi (faqat amal qila
/// olmasdi). Endi ichidagi ma'lumot umuman ko'rsatilmaydi.
class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_person_rounded,
      tone: StageTone.warning,
      title: 'Sizda vakolat mavjud emas',
      message: message ??
          'Bu bo\'limni ko\'rish uchun boshqaruvchidan vakolat so\'rang.',
    );
  }
}

/// Ikki ustunli "nom — qiymat" qatori (ma'lumot kartalarida).
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: context.colorTextSecondary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.colorTextSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: (emphasize
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600))
                  ?.copyWith(
                color: valueColor,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
