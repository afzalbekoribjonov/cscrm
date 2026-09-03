import 'package:flutter/material.dart';

import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../utils/order_sections.dart';
import '../../widgets/count_banner.dart';
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
                if (index == 0) return CountBanner(count: filtered.length);
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
