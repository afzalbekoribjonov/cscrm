import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/staff_access.dart';
import '../../models/staff_permission.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../ui/action_menu.dart';
import '../../ui/surfaces.dart';
import '../activity/my_activity_screen.dart';
import '../admin/admin_home_screen.dart';
import '../admin/debtors_screen.dart';
import '../admin/expenses_screen.dart';
import '../admin/income_activity_screen.dart';
import '../settings/settings_screen.dart';

/// "⋮" menyusi — foydalanuvchiga ochiq barcha qo'shimcha imkoniyatlar
/// bitta joyda, nomi va izohi bilan.
///
/// Ilgari ular app bar'da qator ikonkalar bo'lib turardi (hisobot,
/// chiqim, qarzdorlar, faoliyat, boshqaruv, sozlamalar) — xodim qaysi
/// belgi nima ekanini eslab qolishi kerak edi. Vakolat yo'q imkoniyat
/// menyuda umuman ko'rinmaydi.
Future<void> openAppMenu(BuildContext context, AppUser user) {
  void push(WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute(builder: builder));

  final access = user.access;
  final work = <MenuAction>[
    if (user.isManager)
      MenuAction(
        icon: Icons.dashboard_customize_outlined,
        label: 'Boshqaruv paneli',
        subtitle: 'Xodimlar, xizmatlar, qoidalar va profil',
        onTap: () => push((_) => AdminHomeScreen(
              currentUserId: user.id,
              currentUserName: user.name,
            )),
      ),
    if (!user.isManager && access.has(WorkSection.yetgazma))
      MenuAction(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Mening faoliyatim',
        subtitle: 'Olib kelgan, topshirgan va qo\'limdagi pul',
        tone: StageTone.success,
        onTap: () => push((_) => MyActivityScreen(
              currentUserId: user.id,
              currentUserName: user.name,
              access: access,
            )),
      ),
  ];

  final finance = <MenuAction>[
    if (access.can(StaffPermission.reports))
      MenuAction(
        icon: Icons.insights_rounded,
        label: 'Hisobotlar',
        subtitle: 'Tushum, buyurtmalar va xodimlar faolligi',
        tone: StageTone.info,
        onTap: () => push((_) => IncomeActivityScreen(
              currentUserId: user.id,
              currentUserName: user.name,
              access: access,
            )),
      ),
    if (access.can(StaffPermission.expenses))
      MenuAction(
        icon: Icons.receipt_long_outlined,
        label: 'Chiqimlar',
        subtitle: 'Oylar bo\'yicha sarflar',
        tone: StageTone.danger,
        onTap: () => push((_) => ExpensesScreen(
              currentUserId: user.id,
              currentUserName: user.name,
            )),
      ),
    if (access.can(StaffPermission.debtors))
      MenuAction(
        icon: Icons.request_quote_outlined,
        label: 'Qarzdorlar',
        subtitle: 'Oylar bo\'yicha to\'lanmagan summalar',
        tone: StageTone.warning,
        onTap: () => push((_) => DebtorsScreen(
              currentUserId: user.id,
              currentUserName: user.name,
              access: access,
            )),
      ),
  ];

  return showActionMenu(
    context,
    header: _AccountHeader(user: user),
    groups: [
      MenuGroup(actions: work),
      MenuGroup(title: 'Moliya', actions: finance),
      MenuGroup(
        title: 'Ilova',
        actions: [
          MenuAction(
            icon: Icons.settings_outlined,
            label: 'Sozlamalar',
            subtitle: 'Yozuv, mavzu, PIN qulf va hisob',
            tone: StageTone.neutral,
            onTap: () => push((_) => const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          UserAvatar(initials: user.initials, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.isEmpty ? user.roleLabel : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  user.businessName.isEmpty
                      ? user.roleLabel
                      : '${user.roleLabel} · ${user.businessName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bosh harflardan iborat dumaloq avatar.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.initials, this.size = 40});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.brand],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Vakolatni tekshirib, bo'lim sahifasi yoki "vakolat yo'q" ko'rinishini
/// qaytaradi.
Widget guardSection(StaffAccess access, WorkSection section, Widget child) =>
    access.has(section) ? child : const NoAccessView();
