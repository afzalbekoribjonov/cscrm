import 'package:flutter/material.dart';

import '../models/license_status.dart';
import '../screens/subscription/subscription_blocked_screen.dart';
import '../services/license_controller.dart';
import '../theme/app_colors.dart';

/// Muddat tugashiga oz qolganda tepada chiqadigan eslatma.
///
/// Bloklashdan OLDIN ogohlantirish muhim: biznes to'lovni oldindan
/// rejalashtira olsin, ish kuni o'rtasida to'satdan to'xtab qolmasin.
///
/// Holat tinch bo'lsa hech narsa chizmaydi (nol balandlik).
class SubscriptionBanner extends StatelessWidget {
  const SubscriptionBanner({super.key, required this.isOwner});

  /// To'lov ekraniga o'tish ega uchun mazmunli, xodim uchun esa faqat
  /// ma'lumot — lekin ikkalasiga ham ko'rsatiladi.
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LicenseController.instance,
      builder: (context, _) {
        final status = LicenseController.instance.value?.status;
        if (status == null || !status.needsWarning) {
          return const SizedBox.shrink();
        }

        final (color, icon) = _visualFor(status.state);

        return Material(
          color: color.withValues(alpha: 0.12),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubscriptionBlockedScreen(
                  status: status,
                  isOwner: isOwner,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      status.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: color),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  (Color, IconData) _visualFor(LicenseState state) {
    switch (state) {
      case LicenseState.grace:
        // Muddat allaqachon tugagan - qizil, chunki ish to'xtashiga
        // sanoqli kun qoldi.
        return (AppColors.danger, Icons.warning_amber_rounded);
      case LicenseState.lifetimeFeeDue:
        return (AppColors.licenseLifetime, Icons.storage_rounded);
      default:
        return (AppColors.warning, Icons.schedule_rounded);
    }
  }
}
