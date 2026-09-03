import 'package:flutter/material.dart';

import '../../branding/app_branding.dart';
import '../../branding/logo.dart';
import '../../theme/app_colors.dart';

/// Ilova ochilganda ko'rinadigan brendlangan boshlang'ich ekran.
///
/// Sessiya, Firebase sozlamalari va obuna holati tekshirilguncha shu ekran
/// turadi - `main.dart` dagi `_RootGate` uni almashtiradi.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.brandGradient,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CscrmMark(size: 108, rounded: 0.3),
                const SizedBox(height: 24),
                Text(
                  AppBranding.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppBranding.tagline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
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
