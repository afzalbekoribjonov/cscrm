import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../services/employee_service.dart';
import '../../services/expense_service.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../utils/delivery_stats.dart';
import '../../utils/wash_stats.dart';
import '../../widgets/item_measurement_form.dart' show fmtSom;
import '../../widgets/period_calendar.dart';
import '../../widgets/stream_error_view.dart';
import '../activity/delivery_orders_screen.dart';

/// "Daromad va faollik" - tanlangan kalendar davri bo'yicha ikki blok:
///
///  * **Daromad** - qabul qilingan pul, chiqim, sof foyda, qarzdorlik;
///  * **Faollik** - yuvilgan hajm (m², metr, kg, dona) va dastavchilar.
///
/// Barcha ma'lumot bitta davr filtri ostida - yuqoridagi kalendardan
/// kunlik/haftalik/oylik yoki istalgan kun tanlanadi.
class IncomeActivityScreen extends StatefulWidget {
  const IncomeActivityScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;

  /// Ochgan foydalanuvchining haqiqiy vakolatlari. Bu ekran "Hisobotlarni
  /// ko'rish" vakolati bo'lgan oddiy xodimga ham ochilgani uchun, bu yerdan
  /// ochiladigan buyurtmalarga admin huquqi berib yuborilmasligi shart.
  final StaffAccess access;

  @override
  State<IncomeActivityScreen> createState() => _IncomeActivityScreenState();
}

class _IncomeActivityScreenState extends State<IncomeActivityScreen> {
  OrderService _orderService = OrderService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa, davr
  // almashtirilganda ro'yxatlar "waiting" holatiga qaytib flicker qilardi.
  // Oqim TANLANGAN DAVRGA bog'liq - davr almashtirilganda qayta
  // yaratiladi (_applyPeriod). Ilgari bu yerda butun tarix o'qilardi.
  late var _reportStream = _orderService.streamReport(
    startOfMonth(DateTime.now()),
    endOfMonth(DateTime.now()),
  );
  final _employeesStream = EmployeeService().streamEmployees();
  final _expensesStream = ExpenseService().streamExpenses();

  DateTime _start = startOfMonth(DateTime.now());
  DateTime _end = endOfMonth(DateTime.now());

  void _retry() => setState(() {
        _orderService = OrderService();
        _reportStream = _orderService.streamReport(_start, _end);
      });

  /// Davr o'zgarganda so'rovni ham yangilaymiz - aks holda ekran eski
  /// davr ma'lumotini mahalliy filtrlab ko'rsatib, noto'g'ri (kam) raqam
  /// chiqarardi.
  void _applyPeriod(DateTime start, DateTime end) {
    setState(() {
      _start = start;
      _end = end;
      _reportStream = _orderService.streamReport(start, end);
    });
  }

  void _openOrders(BuildContext context, String title, List<Order> orders) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DeliveryOrdersScreen(
          title: title,
          orders: orders,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
          access: widget.access,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daromad va faollik')),
      body: StreamBuilder<
          ({List<Order> orders, List<OrderHistoryEntry> history})>(
        stream: _reportStream,
        builder: (context, orderSnap) {
          if (orderSnap.hasError) {
            return StreamErrorView(error: orderSnap.error!, onRetry: _retry);
          }
          return StreamBuilder<List<Expense>>(
            stream: _expensesStream,
            builder: (context, expenseSnap) {
              return StreamBuilder<List<Employee>>(
                stream: _employeesStream,
                builder: (context, empSnap) {
                  // Uchala oqim ham kelmaguncha hisob-kitob qilinmaydi -
                  // aks holda yarim ma'lumot bilan noto'g'ri raqam
                  // ko'rinib, keyin sakrab o'zgarardi.
                  final loading = !orderSnap.hasData ||
                      !expenseSnap.hasData ||
                      !empSnap.hasData;
                  return _buildBody(
                    context,
                    orders: orderSnap.data?.orders ?? const [],
                    history: orderSnap.data?.history ?? const [],
                    expenses: expenseSnap.data ?? const [],
                    employees: empSnap.data ?? const [],
                    loading: loading,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<Order> orders,
    required List<OrderHistoryEntry> history,
    required List<Expense> expenses,
    required List<Employee> employees,
    required bool loading,
  }) {
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
      children: [
        PeriodCalendar(
          onRangeChanged: _applyPeriod,
        ),
        const SizedBox(height: 20),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          ..._buildStats(context, theme, orders, history, expenses, employees),
      ],
    );
  }

  List<Widget> _buildStats(
    BuildContext context,
    ThemeData theme,
    List<Order> orders,
    List<OrderHistoryEntry> history,
    List<Expense> expenses,
    List<Employee> employees,
  ) {
    // ---- Daromad ----
    final delivered = orders
        .where((o) =>
            o.deliveredAt != null &&
            isWithinRange(o.deliveredAt!, _start, _end))
        .toList();
    final cash = delivered
        .where((o) => o.paymentMethod == cashPaymentLabel)
        .fold<double>(0, (sum, o) => sum + (o.paymentAmount ?? 0));
    final card = delivered
        .where((o) => o.paymentMethod == cardPaymentLabel)
        .fold<double>(0, (sum, o) => sum + (o.paymentAmount ?? 0));
    final income = cash + card;
    final expenseTotal = expenses
        .where((e) => isWithinRange(e.spentAt, _start, _end))
        .fold<double>(0, (sum, e) => sum + e.amount);
    final profit = income - expenseTotal;
    final debt = delivered.fold<double>(0, (sum, o) => sum + o.debtAmount);
    final debtCount = delivered.where((o) => o.hasDebt).length;
    final discount =
        delivered.fold<double>(0, (sum, o) => sum + o.discountAmount);

    // ---- Faollik ----
    final wash = washStatsForRange(orders, history, _start, _end);
    final created =
        orders.where((o) => isWithinRange(o.createdAt, _start, _end)).length;
    final statsByEmployee = deliveryStatsByEmployee(orders, _start, _end);
    final drivers = employees
        .where((e) => e.active && e.sections.contains(WorkSection.yetgazma))
        .toList()
      ..sort((a, b) => (statsByEmployee[b.id]?.deliveredCount ?? 0)
          .compareTo(statsByEmployee[a.id]?.deliveredCount ?? 0));

    return [
      _SectionHeader(
        icon: Icons.payments_rounded,
        title: 'Daromad',
        subtitle: 'Tanlangan davrda qabul qilingan pul va chiqimlar',
      ),
      const SizedBox(height: 12),
      _ProfitBanner(income: income, expense: expenseTotal, profit: profit),
      const SizedBox(height: 10),
      _StatRow(
        icon: Icons.payments_outlined,
        color: AppColors.success,
        label: 'Naqd pul',
        value: fmtSom(cash),
      ),
      const SizedBox(height: 8),
      _StatRow(
        icon: Icons.credit_card_rounded,
        color: AppColors.accent,
        label: 'Karta orqali',
        value: fmtSom(card),
      ),
      const SizedBox(height: 8),
      _StatRow(
        icon: Icons.receipt_long_rounded,
        color: AppColors.danger,
        label: 'Chiqimlar',
        value: fmtSom(expenseTotal),
      ),
      if (discount > 0) ...[
        const SizedBox(height: 8),
        _StatRow(
          icon: Icons.percent_rounded,
          color: AppColors.warning,
          label: 'Berilgan skidka',
          value: fmtSom(discount),
        ),
      ],
      const SizedBox(height: 8),
      _StatRow(
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.danger,
        label: 'Qarzdorlik ($debtCount ta)',
        value: fmtSom(debt),
        emphasise: debt > 0,
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: delivered.isEmpty
              ? null
              : () =>
                  _openOrders(context, 'Davr bo\'yicha yetkazmalar', delivered),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Yetkazmalarni ko\'rish'),
        ),
      ),
      const SizedBox(height: 20),
      _SectionHeader(
        icon: Icons.insights_rounded,
        title: 'Faollik',
        subtitle: 'Sexda bajarilgan ish hajmi',
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _MiniCard(
                icon: Icons.note_add_rounded,
                color: AppColors.primary,
                value: '$created ta',
                label: 'Yangi buyurtma',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniCard(
                icon: Icons.local_shipping_rounded,
                color: AppColors.statusDelivered,
                value: '${delivered.length} ta',
                label: 'Yetkazilgan',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Yuvilgan hajm',
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 2),
      Text(
        'Xizmat qadoqlashga o\'tkazilgan sana bo\'yicha hisoblanadi.',
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 10),
      if (wash.isEmpty)
        _EmptyNote(text: 'Bu davrda yuvilgan xizmat yo\'q')
      else
        ...wash.volumes.map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StatRow(
              icon: Icons.local_laundry_service_rounded,
              color: AppColors.statusWashing,
              label: '${v.unit.label}  ·  ${v.itemCount} ta',
              value: formatVolume(v.quantity, v.unit),
            ),
          ),
        ),
      const SizedBox(height: 20),
      Text(
        'Dastavchilar',
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (drivers.isEmpty)
        _EmptyNote(text: 'Yetgazma vakolati berilgan xodim yo\'q')
      else
        ...drivers.map((employee) {
          final stats = statsByEmployee[employee.id] ?? const DeliveryStats();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DriverCard(
              employee: employee,
              stats: stats,
              onTap: stats.deliveredCount == 0
                  ? null
                  : () => _openOrders(
                        context,
                        '${employee.fullName} — yetkazmalar',
                        deliveredBetween(orders, _start, _end,
                            employeeId: employee.id),
                      ),
            ),
          );
        }),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sof foyda banneri - daromad, chiqim va farq bir joyda.
class _ProfitBanner extends StatelessWidget {
  const _ProfitBanner({
    required this.income,
    required this.expense,
    required this.profit,
  });

  final double income;
  final double expense;
  final double profit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = profit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? AppColors.brandGradient
              : [AppColors.danger, AppColors.danger.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sof foyda',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 2),
          Text(
            fmtSom(profit),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _BannerCell(label: 'Daromad', value: fmtSom(income)),
              ),
              Container(width: 1, height: 30, color: Colors.white24),
              Expanded(
                child: _BannerCell(label: 'Chiqim', value: fmtSom(expense)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerCell extends StatelessWidget {
  const _BannerCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Bir qatorli ko'rsatkich: chapda ikonka+nom, o'ngda summa. Uzun
/// summalar kesilmasligi uchun butun kenglikni egallaydi.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: emphasise
            ? color.withValues(alpha: 0.08)
            : context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: emphasise ? color.withValues(alpha: 0.4) : context.colorBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 11),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 10),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: emphasise ? color : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(height: 9),
          Text(
            value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.employee,
    required this.stats,
    required this.onTap,
  });

  final Employee employee;
  final DeliveryStats stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                    child: Text(
                      employee.firstName.isEmpty
                          ? '?'
                          : employee.firstName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.fullName,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${stats.deliveredCount} ta yetkazgan · '
                          '${stats.pickedUpCount} ta olib kelgan',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MoneyChip(
                      label: 'Naqd',
                      amount: stats.cashTotal,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MoneyChip(
                      label: 'Karta',
                      amount: stats.cardTotal,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          Text(
            fmtSom(amount),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800, color: color),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
