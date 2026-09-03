import 'package:flutter/material.dart';

import '../../models/order.dart';
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

/// "Yetgazma" bo'limi - transport bilan bog'liq 3 bosqich: mijozdan olib
/// kelinishi kerak bo'lgan, sexda tayyor bo'lib mijozga yetgazilishi kerak
/// bo'lgan, va bugun yetgazib bo'lingan buyurtmalar.
class YetgazmaScreen extends StatefulWidget {
  const YetgazmaScreen({
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
  State<YetgazmaScreen> createState() => _YetgazmaScreenState();
}

class _YetgazmaScreenState extends State<YetgazmaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.sections.pickup;
    final ready = widget.sections.readyForDelivery;
    final deliveredToday = widget.sections.deliveredToday;

    return Scaffold(
      appBar: AppBar(
        title: EmployeeAppBarTitle(
            title: 'Yetgazma', employeeName: widget.currentUserName),
        actions: [
          NotificationAction(
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
          ),
          const ThemeToggleAction(),
          OrderSearchAction(
            orders: widget.sections.all,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
            section: WorkSection.yetgazma,
          ),
          ...financeActions(
            access: widget.access,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
          if (!widget.access.isAdmin && widget.access.has(WorkSection.yetgazma))
            MyActivityAction(
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
              access: widget.access,
            ),
          const LogoutAction(),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'Olib kelish (${pickup.length})'),
            Tab(text: 'Tayyor (${ready.length})'),
            Tab(text: 'Yetgazildi (${deliveredToday.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderList(
            orders: pickup,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
            emptyText: 'Olib kelinishi kerak bo\'lgan buyurtma yo\'q',
          ),
          _OrderList(
            orders: ready,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
            emptyText: 'Yetgazishga tayyor buyurtma yo\'q',
          ),
          _OrderList(
            orders: deliveredToday,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
            emptyText: 'Bugun hali yetgazilgan buyurtma yo\'q',
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    required this.emptyText,
  });

  final List<Order> orders;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(emptyText, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      itemCount: orders.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) return CountBanner(count: orders.length);
        return OrderCard(
          order: orders[index - 1],
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          access: access,
          section: WorkSection.yetgazma,
        );
      },
    );
  }
}
