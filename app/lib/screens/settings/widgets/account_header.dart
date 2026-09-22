import 'package:flutter/material.dart';

import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';

/// Sozlamalar tepasidagi hisob kartasi: kim kirgan va qaysi biznesga.
///
/// Ilgari bu ma'lumot oddiy ro'yxat qatori edi va boshqa sozlamalar
/// orasida yo'qolib ketardi. Vaholanki "men kim bo'lib kirganman"
/// degan savol sozlamalarga kelishning eng tez-tez sababi.
class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key, required this.session});

  final Session session;

  /// Ism-familiyaning bosh harflari — rasm o'rniga.
  ///
  /// Rasm yuklash imkoniyati yo'q, bo'sh doira esa tugallanmagan
  /// ko'rinadi. Harflar hech qachon yuklanmaydi va har doim bor.
  String get _initials {
    final name = (session.displayName ?? '').trim();
    if (name.isEmpty) return '?';

    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  String get _roleLabel =>
      session.role == SessionRole.owner ? 'Boshqaruvchi' : 'Xodim';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.brand],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  session.displayName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((session.tenantName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    session.tenantName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _roleLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
