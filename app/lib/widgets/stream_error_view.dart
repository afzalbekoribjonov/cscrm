import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Firebase stream xatoga uchraganda (masalan permission-denied yoki tarmoq
/// uzilishi) buyurtmalar/xodimlar ro'yxati jimgina "bo'sh" ko'rinib
/// qolmasligi uchun ishlatiladi - aks holda foydalanuvchi xatoni sababini
/// bilmay, ma'lumot "yo'qolgan" deb o'ylaydi.
class StreamErrorView extends StatelessWidget {
  const StreamErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.danger, size: 36),
            const SizedBox(height: 12),
            Text(
              'Ma\'lumotlarni yuklab bo\'lmadi',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colorSurfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                error.toString(),
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Qayta urinish')),
            ],
          ],
        ),
      ),
    );
  }
}
