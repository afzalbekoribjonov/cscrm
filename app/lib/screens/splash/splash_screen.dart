import 'package:flutter/material.dart';

import '../../branding/app_branding.dart';
import '../../branding/logo.dart';

/// Ilova ochilganda ko'rinadigan brendlangan boshlang'ich ekran.
///
/// Sessiya, Firebase sozlamalari va obuna holati tekshirilguncha shu ekran
/// turadi - `main.dart` dagi `_RootGate` uni almashtiradi.
///
/// Fon rangi Android'ning o'z ochilish ekrani bilan AYNAN bir xil
/// ([LogoColors.badge]). Shu sababli ikkalasi orasida o'tish ko'zga
/// tashlanmaydi — foydalanuvchi uchun bu bitta uzluksiz ekran.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: LogoColors.badge,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Plashkasiz: fon allaqachon o'sha rangda, ya'ni plashka
              // faqat ko'rinmas kvadrat bo'lib qolardi.
              const SizedBox(
                width: 170,
                height: 120,
                child: CscrmStackedLetters(),
              ),
              const SizedBox(height: 18),
              Text(
                AppBranding.tagline,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.80),
                ),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
