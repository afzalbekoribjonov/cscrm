import 'package:flutter/material.dart';

import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../utils/order_sections.dart';
import '../../utils/wash_section_stats.dart';
import '../../widgets/section_stats_bar.dart';
import '../../widgets/employee_app_bar_title.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_action.dart';
import '../../widgets/my_activity_action.dart';
import '../../widgets/order_card.dart';
import '../../widgets/order_search_action.dart';
import '../../widgets/finance_actions.dart';
import '../../widgets/theme_toggle_action.dart';

/// "Yuvish" bo'limi - sexga kirgan, hali xizmat qo'shilmagan yoki kamida
/// bitta xizmati "Yuvilmoqda"/"Qayta yuvildi" holatida bo'lgan
/// buyurtmalarni ko'rsatadi.
class WashScreen extends StatelessWidget {
  const WashScreen({
    super.key,
    required this.sections,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  /// Bo'limlar HomeShell'da bir marta hisoblanadi - bu ekran filtrlamaydi.
  final OrderSections sections;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  Widget build(BuildContext context) {
    final filtered = sections.wash;
    final stats = washSectionStats(filtered);

    return Scaffold(
      appBar: AppBar(
        title:
            EmployeeAppBarTitle(title: 'Yuvish', employeeName: currentUserName),
        actions: [
          NotificationAction(
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            access: access,
          ),
          const ThemeToggleAction(),
          OrderSearchAction(
            orders: sections.all,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            access: access,
            section: WorkSection.yuvish,
          ),
          ...financeActions(
            access: access,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
          ),
          if (!access.isAdmin && access.has(WorkSection.yetgazma))
            MyActivityAction(
              currentUserId: currentUserId,
              currentUserName: currentUserName,
              access: access,
            ),
          const LogoutAction(),
        ],
      ),
      body: filtered.isEmpty
          ? Center(
              child: Text(
                'Yuvish navbatida buyurtma yo\'q',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
              itemCount: filtered.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SectionStatsBar(stats: _statsFor(stats)),
                  );
                }
                return OrderCard(
                  order: filtered[index - 1],
                  currentUserId: currentUserId,
                  currentUserName: currentUserName,
                  access: access,
                  section: WorkSection.yuvish,
                );
              },
            ),
    );
  }
}


/// Ko'rsatkichlar MAZMUNIY tartibda: avval umumiy hajm, keyin ishni
/// to'sib turgan narsalar, oxirida jarayondagi ish.
///
/// Nol bo'lgan "muammo" ko'rsatkichlari umuman chizilmaydi — sexdagi
/// odamga "0 ta qayta yuvish" degan karta hech narsa bermaydi, faqat
/// joy egallaydi.
List<SectionStat> _statsFor(WashSectionStats s) {
  return [
    SectionStat(
      icon: Icons.local_laundry_service_rounded,
      color: AppColors.primary,
      value: '${s.orderCount} ta',
      label: 'Buyurtma yuvishda',
    ),
    if (s.rewashItems > 0)
      SectionStat(
        icon: Icons.replay_rounded,
        color: AppColors.danger,
        value: '${s.rewashItems} ta',
        label: 'Qayta yuvish',
        emphasise: true,
      ),
    if (s.ordersWithoutItems > 0)
      SectionStat(
        icon: Icons.playlist_add_rounded,
        color: AppColors.warning,
        value: '${s.ordersWithoutItems} ta',
        label: 'Xizmat qo\'shilmagan',
        emphasise: true,
      ),
    if (s.unmeasuredItems > 0)
      SectionStat(
        icon: Icons.straighten_rounded,
        color: AppColors.warning,
        value: '${s.unmeasuredItems} ta',
        label: 'Mahsulot o\'lchanmagan',
        emphasise: true,
      ),
    SectionStat(
      icon: Icons.water_drop_rounded,
      color: AppColors.statusWashing,
      value: '${s.washingItems} ta',
      label: 'Mahsulot yuvilmoqda',
    ),
  ];
}
