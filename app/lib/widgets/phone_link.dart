import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../utils/phone.dart';

/// Telefon raqami - ikonka bilan birga ko'rsatiladi va bosilganda
/// qurilmaning telefon ilovasi raqam terilgan holatda ochiladi.
/// Ilovada raqam ko'rsatiladigan barcha joyda shu vidjet ishlatiladi.
class PhoneLink extends StatelessWidget {
  const PhoneLink({
    super.key,
    required this.phone,
    this.style,
    this.iconSize = 15,
    this.compact = false,
    this.masked = false,
  });

  /// Saqlangan (kanonik "998XXXXXXXXX") yoki istalgan formatdagi raqam.
  final String phone;
  final TextStyle? style;
  final double iconSize;

  /// true bo'lsa ikonka va matn orasidagi masofa kichraytiriladi -
  /// ixcham kartalar uchun.
  final bool compact;

  /// "Mijoz telefon raqami" vakolati yo'q xodim uchun - raqam qisman
  /// yashiriladi va qo'ng'iroq qilib bo'lmaydi.
  final bool masked;

  Future<void> _dial(BuildContext context) async {
    final digits = digitsOnly(phone);
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: '+$digits');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('launch failed');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telefon ilovasini ochib bo\'lmadi')),
      );
    }
  }

  /// Vakolatsiz xodimga ko'rsatiladigan yashirilgan ko'rinish:
  /// "+998 90 *** ** 67" - operator kodi va oxirgi ikki raqam qoladi.
  String _maskedText() {
    final local = lastDigits(phone, 9);
    if (local.length != 9) return '+998 ** *** ** **';
    return '+998 ${local.substring(0, 2)} *** ** ${local.substring(7, 9)}';
  }

  @override
  Widget build(BuildContext context) {
    if (digitsOnly(phone).isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = masked ? context.colorTextSecondary : AppColors.primary;

    final content = Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 1 : 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            masked ? Icons.phone_disabled_rounded : Icons.phone_rounded,
            size: iconSize,
            color: color,
          ),
          SizedBox(width: compact ? 5 : 7),
          // Raqam hech qachon "..." bilan kesilmasligi kerak - joy tor
          // bo'lsa matn o'zi kichrayadi. Telefon raqamining yarmi
          // ko'rinishining foydasi yo'q.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                masked ? _maskedText() : formatPhoneForDisplay(phone),
                maxLines: 1,
                softWrap: false,
                style: (style ?? theme.textTheme.bodySmall)?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (masked) return content;
    return InkWell(
      onTap: () => _dial(context),
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}
