import 'package:flutter/material.dart' hide Text;

import '../../../l10n/text.dart';
import '../../../models/app_user.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../ui/surfaces.dart';
import '../../home/app_menu.dart';

/// Sozlamalar tepasidagi hisob kartasi: kim kirgan va qaysi biznesda.
class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owner = session.role == SessionRole.owner;
    final name = (session.displayName ?? '').trim();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          UserAvatar(initials: initialsOf(name), size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? (owner ? 'Boshqaruvchi' : 'Xodim') : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge,
                ),
                if ((session.tenantName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    session.tenantName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: context.colorTextSecondary),
                  ),
                ],
                const SizedBox(height: 8),
                TonePill(
                  label: owner ? 'Boshqaruvchi' : 'Xodim',
                  tone: owner ? StageTone.brand : StageTone.neutral,
                  icon: owner
                      ? Icons.admin_panel_settings_outlined
                      : Icons.badge_outlined,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
