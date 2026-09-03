import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../branding/app_branding.dart';
import '../../branding/logo.dart';
import '../../firebase_options.dart';
import '../../theme/app_colors.dart';

/// Firebase'ga ulanib bo'lmaganda ko'rsatiladi.
///
/// Ikki xil holat ajratiladi, chunki ularning yechimi butunlay boshqacha:
///
///  * [FirebaseConfigMissing] — build sozlamalari berilmagan. Bu DASTURCHI
///    xatosi: `--dart-define-from-file` unutilgan. Foydalanuvchiga "internetni
///    tekshiring" deyish noto'g'ri bo'lardi, shuning uchun aniq ko'rsatma
///    beriladi.
///  * Boshqa xatoliklar — tarmoq, Google Play Services, noto'g'ri kalit va h.k.
///    Bu yerda foydalanuvchi qayta urinib ko'radi, matnni esa nusxalab
///    yordam xizmatiga yuboradi.
class FirebaseUnavailableScreen extends StatelessWidget {
  const FirebaseUnavailableScreen({
    super.key,
    required this.error,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  bool get _isConfigError => error is FirebaseConfigMissing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = error.toString();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CscrmMark(size: 64),
                  const SizedBox(height: 20),
                  Icon(
                    _isConfigError
                        ? Icons.build_circle_outlined
                        : Icons.cloud_off_rounded,
                    size: 34,
                    color: _isConfigError
                        ? AppColors.warning
                        : context.colorTextSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isConfigError
                        ? 'Sozlamalar to\'liq emas'
                        : 'Serverga ulanib bo\'lmadi',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isConfigError
                        ? 'Ilova Firebase kalitlarisiz yig\'ilgan. Quyidagi '
                            'buyruq bilan qayta ishga tushiring:'
                        : 'Internet aloqasini tekshirib, qayta urinib ko\'ring. '
                            'Muammo takrorlansa, quyidagi matnni nusxalab '
                            'yordam xizmatiga yuboring.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: context.colorTextSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (_isConfigError) ...[
                    _CodeBlock(
                      text: 'flutter run \\n'
                          '  --dart-define-from-file=env/dev.json',
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.colorSurfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colorBorder),
                    ),
                    child: SelectableText(
                      details,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: details));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nusxalandi')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Nusxalash'),
                      ),
                      if (onRetry != null)
                        ElevatedButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Qayta urinish'),
                        ),
                    ],
                  ),
                  if (!_isConfigError) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Yordam: ${AppBranding.supportPhone}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: context.colorTextSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorTextPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          height: 1.5,
          color: context.colorTextPrimary,
        ),
      ),
    );
  }
}
