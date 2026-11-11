import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'surfaces.dart';

/// Menyudagi bitta imkoniyat.
class MenuAction {
  const MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tone = StageTone.brand,
    this.badge = 0,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final StageTone tone;
  final VoidCallback onTap;

  /// O'ng tomondagi raqam (masalan o'qilmagan xabarlar).
  final int badge;

  /// Xavfli amal (o'chirish, bloklash) — qizil va ro'yxat oxirida.
  final bool destructive;
}

/// Menyudagi guruh — sarlavha bilan.
class MenuGroup {
  const MenuGroup({this.title, required this.actions});
  final String? title;
  final List<MenuAction> actions;
}

/// "⋮" tugmasi bosilganda ochiladigan imkoniyatlar oynasi.
///
/// Ilgari har bir imkoniyat app bar'da alohida ikonka bo'lib turardi —
/// 5–6 ta tushunarsiz belgi qatori. Endi ular bitta joyda, nomi va
/// izohi bilan.
Future<void> showActionMenu(
  BuildContext context, {
  String? title,
  Widget? header,
  required List<MenuGroup> groups,
}) {
  final visible = groups.where((g) => g.actions.isNotEmpty).toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, 12 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.colorBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (header != null) ...[
                const SizedBox(height: 12),
                header,
              ],
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                  child: Text(title, style: theme.textTheme.headlineSmall),
                ),
              for (var g = 0; g < visible.length; g++) ...[
                if (visible[g].title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
                    child: Text(
                      visible[g].title!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ctx.colorTextSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: ctx.colorSurface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: ctx.colorBorder),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < visible[g].actions.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, indent: 64, color: ctx.colorBorder),
                        _MenuRow(
                          action: visible[g].actions[i],
                          onTap: () {
                            Navigator.of(ctx).pop();
                            visible[g].actions[i].onTap();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.action, required this.onTap});

  final MenuAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = action.destructive ? StageTone.danger : action.tone;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            IconTile(icon: action.icon, tone: tone, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: action.destructive ? tone.ink(context) : null,
                    ),
                  ),
                  if (action.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(action.subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (action.badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  action.badge > 99 ? '99+' : '${action.badge}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  color: context.colorTextTertiary),
          ],
        ),
      ),
    );
  }
}

/// "⋮" tugmasi. [dot] — ichida e'tibor talab qiladigan narsa bor.
class MoreButton extends StatelessWidget {
  const MoreButton({
    super.key,
    required this.onPressed,
    this.dot = false,
    this.tooltip = 'Imkoniyatlar',
  });

  final VoidCallback onPressed;
  final bool dot;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: t(tooltip),
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: dot,
        smallSize: 8,
        child: const Icon(Icons.more_vert_rounded),
      ),
    );
  }
}
