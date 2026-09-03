import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Internet uzilganda ekran tepasida chiqadigan ingichka chiziq.
///
/// Firebase'ning `.info/connected` xizmat tuguni orqali ishlaydi. Aloqa
/// yo'q bo'lsa ham ish to'xtamaydi: o'zgarishlar qurilmada saqlanib
/// turadi va aloqa tiklanganda avtomatik yuboriladi - shu sabab xabar
/// ogohlantirish emas, shunchaki holat.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa har bir
  // qayta qurishda yangi obuna hosil bo'lardi.
  late final Stream<DatabaseEvent> _connected =
      FirebaseDatabase.instance.ref('.info/connected').onValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _connected,
      builder: (context, snapshot) {
        // Ma'lumot kelmaguncha hech narsa ko'rsatmaymiz - ilova ochilishida
        // bir zumga "aloqa yo'q" chaqnab ketmasligi uchun.
        if (!snapshot.hasData) return const SizedBox.shrink();
        final online = snapshot.data!.snapshot.value == true;
        if (online) return const SizedBox.shrink();

        return Material(
          color: AppColors.warning.withValues(alpha: 0.16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    size: 15, color: AppColors.warning),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Internet yo\'q — ishlar saqlanib turadi va aloqa '
                    'tiklanganda yuboriladi',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
