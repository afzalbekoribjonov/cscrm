import 'package:flutter/material.dart';

import '../models/staff_access.dart';
import '../models/staff_permission.dart';
import '../screens/admin/debtors_screen.dart';
import '../screens/admin/expenses_screen.dart';
import '../screens/admin/income_activity_screen.dart';

/// Bo'lim ekranlarining AppBar'iga qo'shiladigan moliyaviy tugmalar.
///
/// Boshqaruv paneli faqat adminda ochiq, shu sabab tegishli vakolat
/// berilgan oddiy xodim bu ekranlarga aynan shu tugmalar orqali kiradi.
/// Vakolat yo'q bo'lsa tugma umuman chizilmaydi.
List<Widget> financeActions({
  required StaffAccess access,
  required String currentUserId,
  required String currentUserName,
}) {
  // Admin bularni Boshqaruv panelidan ochadi - AppBar'ni takror
  // tugmalar bilan to'ldirmaymiz.
  if (access.isAdmin) return const [];

  return [
    if (access.can(StaffPermission.reports))
      _FinanceAction(
        icon: Icons.insights_rounded,
        tooltip: 'Daromad va faollik',
        builder: (_) => IncomeActivityScreen(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          access: access,
        ),
      ),
    if (access.can(StaffPermission.expenses))
      _FinanceAction(
        icon: Icons.receipt_long_rounded,
        tooltip: 'Chiqimlar',
        builder: (_) => ExpensesScreen(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
        ),
      ),
    if (access.can(StaffPermission.debtors))
      _FinanceAction(
        icon: Icons.account_balance_wallet_outlined,
        tooltip: 'Qarzdorlar',
        builder: (_) => DebtorsScreen(
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          access: access,
        ),
      ),
  ];
}

class _FinanceAction extends StatelessWidget {
  const _FinanceAction({
    required this.icon,
    required this.tooltip,
    required this.builder,
  });

  final IconData icon;
  final String tooltip;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: builder),
      ),
    );
  }
}
