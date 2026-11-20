import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Bitta qatorda, gorizontal suriladigan kichik tanlov tugmalari
/// (saralash/filtr). Bittasi tanlangan bo'ladi.
///
/// Ekran tor bo'lsa ham tugmalar ikki qatorga bo'linmaydi va matni
/// kesilmaydi — qator yon tomonga suriladi.
class ChoiceChipsBar<T> extends StatelessWidget {
  const ChoiceChipsBar({
    super.key,
    required this.values,
    required this.value,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.busyOf,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, 8, Gap.page, 2),
  });

  final List<T> values;
  final T value;
  final String Function(T value) labelOf;
  final IconData? Function(T value)? iconOf;

  /// Shu tugmada aylanma ko'rsatish kerakmi (masalan GPS so'ralayotganda).
  final bool Function(T value)? busyOf;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _Chip(
              label: labelOf(values[i]),
              icon: iconOf?.call(values[i]),
              selected: values[i] == value,
              busy: busyOf?.call(values[i]) ?? false,
              onTap: () => onChanged(values[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.busy,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final ink = selected ? Colors.white : context.colorTextPrimary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color : context.colorSurface,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: selected ? color : context.colorBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy) ...[
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                  const SizedBox(width: 7),
                ] else if (icon != null) ...[
                  Icon(icon, size: 15, color: ink),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: AppFonts.sans,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
