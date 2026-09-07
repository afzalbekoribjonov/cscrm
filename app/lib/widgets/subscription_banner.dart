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
/// Ikki darajasi bor:
///  * OGOHLANTIRISH (`expiring`) — ixcham chiziq, YOPIB qo'yish mumkin.
///    Sinov muddati qisqa bo'lganda bu chiziq doim ko'rinadi va ish
///    ekranlarini bosib turadi; foydalanuvchi uni bir marta o'qib,
///    yopib qo'ysin.
///  * SHOSHILINCH (`grace`, `lifetimeFeeDue`) — muddat allaqachon
///    tugagan, ilova to'xtashiga sanoqli vaqt qoldi. Bu YOPILMAYDI:
///    e'tibordan chetda qolsa biznes ish o'rtasida to'xtab qoladi.
///
/// Holat tinch bo'lsa hech narsa chizmaydi (nol balandlik).
class SubscriptionBanner extends StatefulWidget {
  const SubscriptionBanner({super.key, required this.isOwner});

  /// To'lov ekraniga o'tish ega uchun mazmunli, xodim uchun esa faqat
  /// ma'lumot — lekin ikkalasiga ham ko'rsatiladi.
  final bool isOwner;

  @override
  State<SubscriptionBanner> createState() => _SubscriptionBannerState();
}

class _SubscriptionBannerState extends State<SubscriptionBanner> {
  /// Foydalanuvchi yopgan holat. Holat OG'IRLASHSA (masalan `expiring`
  /// dan `grace` ga o'tsa) chiziq qaytadan ko'rinadi — chunki bu endi
  /// boshqa, jiddiyroq xabar.
  LicenseState? _dismissed;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LicenseController.instance,
      builder: (context, _) {
        final status = LicenseController.instance.value?.status;
        if (status == null || !status.needsWarning) {
          return const SizedBox.shrink();
        }

        final urgent = status.state == LicenseState.grace ||
            status.state == LicenseState.lifetimeFeeDue;

        if (!urgent && _dismissed == status.state) {
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
                  isOwner: widget.isOwner,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 7, urgent ? 14 : 4, 7),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (urgent)
                    Icon(Icons.chevron_right_rounded, size: 17, color: color)
                  else
                    IconButton(
                      tooltip: 'Yopish',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      color: color,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () =>
                          setState(() => _dismissed = status.state),
                    ),
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
