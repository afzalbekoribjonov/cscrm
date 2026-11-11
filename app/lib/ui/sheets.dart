import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'surfaces.dart';

/// Pastdan chiqadigan oyna — barcha "sheet"lar uchun bir xil ramka:
/// tortish dastagi, sarlavha, yopish tugmasi, kontent va pastki tugmalar.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, Gap.page),
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Pastda doim ko'rinib turadigan tugmalar (klaviatura ochilganda ham).
  final Widget? actions;
  final bool scrollable;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final content = Padding(padding: padding, child: child);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorBorderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 10, 6, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.headlineSmall),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: t('Yopish'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (scrollable)
              Flexible(child: SingleChildScrollView(child: content))
            else
              Flexible(child: content),
            if (actions != null)
              Container(
                padding: EdgeInsets.fromLTRB(
                    Gap.page, 10, Gap.page, 12 + media.padding.bottom),
                decoration: BoxDecoration(
                  color: context.colorSurface,
                  border: Border(top: BorderSide(color: context.colorBorder)),
                ),
                child: actions,
              )
            else
              SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Bir xil ko'rinishdagi pastki oynani ochadi.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Muhim yoki qaytarib bo'lmaydigan amalni tasdiqlash.
///
/// Xavfli amalda fokus "Bekor qilish" da turadi va tasdiq tugmasi qizil —
/// tasodifiy bosish hech narsani o'chirmaydi.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  IconData? icon,
}) async {
  final tone = destructive ? StageTone.danger : StageTone.brand;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        icon: IconTile(
          icon: icon ??
              (destructive
                  ? Icons.delete_outline_rounded
                  : Icons.help_outline_rounded),
          tone: tone,
          size: 52,
          radius: 16,
        ),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  autofocus: true,
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Bekor qilish'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                      : null,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(
                    confirmLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Natija haqida qisqa xabar (pastda).
void showResult(BuildContext context, String message,
    {bool error = false, IconData? icon}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final ink =
      error ? Colors.white : Theme.of(context).colorScheme.onInverseSurface;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.danger : null,
        content: Row(
          children: [
            Icon(
              icon ??
                  (error
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded),
              color: error ? Colors.white : const Color(0xFF4ADE80),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: ink, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
}
