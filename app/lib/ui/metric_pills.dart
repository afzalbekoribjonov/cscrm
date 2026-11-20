import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Ro'yxat tepasidagi kichik ko'rsatkichlar qatori. Bitta qatorda,
/// sig'masa yon tomonga suriladi — hech qachon ikki qatorga bo'linmaydi
/// va raqam kesilmaydi.
class MetricStrip extends StatelessWidget {
  const MetricStrip({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, 10, Gap.page, 0),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Bitta ko'rsatkich: "145 m²". [tone] berilsa — rangli (masalan qizil
/// "3 ta" o'lchanmagan), aks holda neytral.
class MetricPill extends StatelessWidget {
  const MetricPill({
    super.key,
    required this.value,
    this.unit,
    this.icon,
    this.tone,
    this.onTap,
    this.semanticLabel,
  });

  final String value;
  final String? unit;
  final IconData? icon;
  final StageTone? tone;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    final ink = tone?.ink(context) ?? context.colorTextPrimary;
    final sub = tone?.ink(context) ?? context.colorTextSecondary;
    final radius = BorderRadius.circular(Radii.pill);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: tone?.ink(context) ?? sub),
          const SizedBox(width: 5),
        ],
        Text(
          value,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 13,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: ink,
            fontFeatures: AppFonts.tabular,
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 3),
          Text(
            unit!,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontFamily: AppFonts.sans,
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: sub,
            ),
          ),
        ],
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 16, color: sub),
        ],
      ],
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: tone?.soft(context) ?? context.colorSurface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: tone == null
              ? BorderSide(color: context.colorBorder)
              : BorderSide(color: tone.fill.withValues(alpha: 0.35)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 7, onTap != null ? 6 : 11, 7),
            child: content,
          ),
        ),
      ),
    );
  }
}
