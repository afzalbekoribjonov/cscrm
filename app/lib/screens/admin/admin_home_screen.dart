import 'package:flutter/material.dart';

import '../../branding/logo.dart';
import '../../models/order.dart';
import '../../models/order_status.dart';
import '../../models/staff_access.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/stream_error_view.dart';
import 'admin_credentials_screen.dart';
import 'debtors_screen.dart';
import 'employees_list_screen.dart';
import 'expenses_screen.dart';
import 'income_activity_screen.dart';
import 'orders_admin_screen.dart';
import 'products_admin_screen.dart';

/// Boshqaruvchi paneli bosh sahifasi: bugungi statistika kartalari +
/// Xodimlar / Xizmatlar / Buyurtmalar bo'limlariga kirish.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  // Oqim BIR MARTA yaratiladi. build() ichida yaratilsa, har bir qayta
  // chizishda yangi Stream obyekti paydo bo'lib, ro'yxat "waiting"
  // holatiga qaytardi va ko'rsatkichlar miltillardi.
  //
  // Davr: faqat BUGUN - bu ekran bugungi ko'rsatkichlarni ko'rsatadi.
  late final Stream<List<Order>> _ordersStream =
      OrderService().streamOrdersForPeriod(
    startOfDay(DateTime.now()),
    endOfDay(DateTime.now()),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const CscrmWordmark(markSize: 30),
        actions: const [LogoutAction()],
      ),
      body: StreamBuilder<List<Order>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          final orders = snapshot.data ?? const <Order>[];
          final acceptedToday =
              orders.where((o) => isToday(o.createdAt)).length;
          final deliveredToday = orders
              .where((o) =>
                  o.status == OrderStatus.yetgazildi &&
                  o.deliveredAt != null &&
                  isToday(o.deliveredAt!))
              .length;
          final inWorkshop = orders.where((o) => o.status.isInWorkshop).length;

          return ListView(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
            children: [
              Text('Boshqaruvchi paneli', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Bugungi holat va boshqaruv bo\'limlari.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        value: '$acceptedToday',
                        label: 'Bugungi buyurtma',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_shipping_rounded,
                        color: AppColors.statusDelivered,
                        value: '$deliveredToday',
                        label: 'Yetgazilgan',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_laundry_service_rounded,
                        color: AppColors.statusWashing,
                        value: '$inWorkshop',
                        label: 'Sexda mavjud',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _AdminMenuCard(
                icon: Icons.groups_rounded,
                color: AppColors.primary,
                title: 'Xodimlar',
                subtitle: 'Qo\'shish, tahrirlash, statistika',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const EmployeesListScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _AdminMenuCard(
                icon: Icons.inventory_2_rounded,
                color: AppColors.accent,
                title: 'Xizmatlar',
                subtitle: 'Yuvish xizmatlari ro\'yxati',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProductsAdminScreen()),
                ),
              ),
              const SizedBox(height: 14),
              _AdminMenuCard(
                icon: Icons.calendar_month_rounded,
                color: AppColors.statusReadyDelivery,
                title: 'Buyurtmalar',
                subtitle: 'Kalendar bo\'yicha tarix va statistika',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrdersAdminScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _AdminMenuCard(
                icon: Icons.payments_rounded,
                color: AppColors.success,
                title: 'Daromad va faollik',
                subtitle: 'Bugungi dastavchi naqd/karta hisoboti',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IncomeActivityScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                      access: const StaffAccess.admin(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _AdminMenuCard(
                icon: Icons.receipt_long_rounded,
                color: AppColors.danger,
                title: 'Chiqimlar',
                subtitle: 'Sarflarni yozish va sof foydani ko\'rish',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ExpensesScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _AdminMenuCard(
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.warning,
                title: 'Qarzdorlar',
                subtitle: 'To\'liq to\'lanmagan buyurtmalar',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DebtorsScreen(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                      access: const StaffAccess.admin(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _AdminMenuCard(
                icon: Icons.lock_outline_rounded,
                color: AppColors.statusWashing,
                title: 'Login va parol',
                subtitle: 'Boshqaruvchi hisobini o\'zgartirish',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AdminCredentialsScreen(currentLogin: widget.currentUserName),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 1),
            Text(label, style: theme.textTheme.bodySmall, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
