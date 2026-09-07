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
import '../../utils/income_stats.dart';
import '../../utils/wash_stats.dart';
import '../../widgets/item_measurement_form.dart' show fmtSom;
import '../../widgets/period_calendar.dart';
import '../../widgets/stream_error_view.dart';
import '../activity/delivery_orders_screen.dart';
import 'work_items_screen.dart';

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
  /// Tanlangan davr EKRAN holatida saqlanadi, tanlagich ichida emas -
  /// aks holda ro'yxat aylantirilganda tanlov o'z-o'zidan qaytardi.
  /// Standart: BUGUN.
  PeriodSelection _selection = PeriodSelection.today();

  /// Oqim TANLANGAN DAVRDAN kelib chiqadi. Ilgari bu yerda "joriy oy"
  /// qattiq yozilgan edi - tanlov esa bugun. Ikkalasi bir-biriga mos
  /// bo'lmagani uchun ekran keraksiz ko'p ma'lumot yuklab olardi.
  late var _reportStream = _orderService.streamReport(
    _selection.range.$1,
    _selection.range.$2,
  );
  final _employeesStream = EmployeeService().streamEmployees();
  final _expensesStream = ExpenseService().streamExpenses();

  DateTime get _start => _selection.range.$1;
  DateTime get _end => _selection.range.$2;

  void _retry() => setState(() {
        _orderService = OrderService();
        _reportStream = _orderService.streamReport(_start, _end);
      });

  /// Davr o'zgarganda so'rovni ham yangilaymiz - aks holda ekran eski
  /// davr ma'lumotini mahalliy filtrlab ko'rsatib, noto'g'ri (kam) raqam
  /// chiqarardi.
  void _applyPeriod(PeriodSelection selection) {
    setState(() {
      _selection = selection;
      final (start, end) = selection.range;
      _reportStream = _orderService.streamReport(start, end);
    });
  }

  /// Ko'rsatkich ortidagi ishlar ro'yxatini ochadi.
  void _openWorkItems(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<WorkItem> items,
    required Color color,
  }) {
    if (items.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkItemsScreen(
          title: title,
          subtitle: subtitle,
          items: items,
          color: color,
        ),
      ),
    );
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
        PeriodBar(value: _selection, onChanged: _applyPeriod),
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

  /// Hajm bo'limi: sarlavha, izoh va birlik bo'yicha qatorlar.
  ///
  /// Yuvish va qadoqlash bir xil ko'rinishda chiziladi — ikkalasi bir xil
  /// ma'noli ko'rsatkich, faqat qaysi bosqich ekani boshqa.
  List<Widget> _volumeSection(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String hint,
    required String emptyText,
    required WashStats stats,
    required IconData icon,
    required Color color,
  }) {
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (!stats.isEmpty)
            TextButton.icon(
              onPressed: () => _openWorkItems(
                context,
                title: title,
                subtitle: '${stats.totalItems} ta xizmat · ${_selection.label}',
                items: stats.allItems,
                color: color,
              ),
              icon: const Icon(Icons.visibility_outlined, size: 17),
              label: const Text('Hammasi'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
      const SizedBox(height: 2),
      Text(hint, style: theme.textTheme.bodySmall),
      const SizedBox(height: 10),
      if (stats.isEmpty)
        _EmptyNote(text: emptyText)
      else
        ...stats.volumes.map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StatRow(
              icon: icon,
              color: color,
              label: '${v.unit.label}  ·  ${v.itemCount} ta',
              value: formatVolume(v.quantity, v.unit),
              onInspect: () => _openWorkItems(
                context,
                title: '$title — ${v.unit.label}',
                subtitle:
                    '${formatVolume(v.quantity, v.unit)} · ${v.itemCount} ta '
                    'xizmat · ${_selection.label}',
                items: v.items,
                color: color,
              ),
            ),
          ),
        ),
    ];
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
    // Pul QAYSI KUNI OLINGAN bo'lsa, o'sha kunning daromadi. Qarz
    // to'lovlari yetkazilgan kunga emas, to'langan kunga yoziladi.
    final incomeStats = incomeForRange(orders, history, _start, _end);
    final cash = incomeStats.cash;
    final card = incomeStats.card;
    final income = incomeStats.total;
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
    // Yuvish va qadoqlash ALOHIDA hisoblanadi: bir kunda yuvilgan narsa
    // ertasiga qadoqlanishi mumkin, ya'ni ikki raqam teng bo'lishi
    // shart emas.
    final packaged = packagedStatsForRange(orders, history, _start, _end);
    final created =
        orders.where((o) => isWithinRange(o.createdAt, _start, _end)).length;
    final statsByEmployee = deliveryStatsByEmployee(orders, _start, _end);
    // Yetgazmani BOSHQARUVCHI ham qiladi, u esa xodimlar ro'yxatida
    // yo'q. Shu sabab ro'yxat ikki manbadan yig'iladi - aks holda
    // boshqaruvchi yetkazgan buyurtmalar hech qayerda ko'rinmasdi va
    // jami raqam dastavchiklar yig'indisiga to'g'ri kelmasdi.
    final drivers = deliveryPerformers(
      orders: orders,
      statsById: statsByEmployee,
      employeeNames: {
        for (final e in employees)
          if (e.active && e.sections.contains(WorkSection.yetgazma))
            e.id: e.fullName,
      },
    );

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
        onInspect: () => _openOrders(
          context,
          'Naqd to\'langan buyurtmalar',
          delivered
              .where((o) => o.paymentMethod == cashPaymentLabel)
              .toList(),
        ),
      ),
      const SizedBox(height: 8),
      _StatRow(
        icon: Icons.credit_card_rounded,
        color: AppColors.accent,
        label: 'Karta orqali',
        value: fmtSom(card),
        onInspect: () => _openOrders(
          context,
          'Karta orqali to\'langan buyurtmalar',
          delivered
              .where((o) => o.paymentMethod == cardPaymentLabel)
              .toList(),
        ),
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
          onInspect: () => _openOrders(
            context,
            'Skidka berilgan buyurtmalar',
            delivered.where((o) => o.discountAmount > 0).toList(),
          ),
        ),
      ],
      const SizedBox(height: 8),
      _StatRow(
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.danger,
        label: 'Qarzdorlik ($debtCount ta)',
        value: fmtSom(debt),
        emphasise: debt > 0,
        onInspect: debtCount == 0
            ? null
            : () => _openOrders(
                  context,
                  'Qarzi qolgan buyurtmalar',
                  delivered.where((o) => o.hasDebt).toList(),
                ),
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
      ..._volumeSection(
        context,
        theme,
        title: 'Yuvilgan hajm',
        hint: 'Xizmat qadoqlashga o\'tkazilgan sana bo\'yicha hisoblanadi.',
        emptyText: 'Bu davrda yuvilgan xizmat yo\'q',
        stats: wash,
        icon: Icons.local_laundry_service_rounded,
        color: AppColors.statusWashing,
      ),
      const SizedBox(height: 20),
      ..._volumeSection(
        context,
        theme,
        title: 'Qadoqlangan hajm',
        hint: 'Xizmat "Tayyor" holatiga o\'tkazilgan sana bo\'yicha. '
            'Yuvilgan hajmga teng bo\'lishi shart emas — bugun yuvilgani '
            'ertaga qadoqlanishi mumkin.',
        emptyText: 'Bu davrda qadoqlangan xizmat yo\'q',
        stats: packaged,
        icon: Icons.inventory_2_rounded,
        color: AppColors.statusReadyDelivery,
      ),
      const SizedBox(height: 20),
      Text(
        'Dastavchilar',
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (drivers.isEmpty)
        _EmptyNote(text: 'Bu davrda hech kim yetkazmagan')
      else
        ...drivers.map((driver) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DriverCard(
              driver: driver,
              onTap: driver.stats.deliveredCount == 0
                  ? null
                  : () => _openOrders(
                        context,
                        '${driver.name} — yetkazmalar',
                        deliveredBetween(orders, _start, _end,
                            employeeId: driver.id),
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
    this.onInspect,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final bool emphasise;

  /// "Ko'z" tugmasi. Raqam qayerdan chiqqanini ko'rsatadi.
  /// `null` bo'lsa tugma umuman chizilmaydi.
  final VoidCallback? onInspect;

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
          if (onInspect != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Tafsilotlarni ko\'rish',
              onPressed: onInspect,
              icon: const Icon(Icons.visibility_outlined),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              color: color,
            ),
          ],
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
  const _DriverCard({required this.driver, required this.onTap});

  final DeliveryPerformer driver;
  final VoidCallback? onTap;

  DeliveryStats get stats => driver.stats;

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
                      driver.name.isEmpty
                          ? '?'
                          : driver.name[0].toUpperCase(),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                driver.name,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Xodim emasligini ko'rsatamiz - aks holda
                            // "bu kim?" degan savol tug'iladi.
                            if (!driver.isEmployee) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text(
                                  'Boshqaruvchi',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
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
