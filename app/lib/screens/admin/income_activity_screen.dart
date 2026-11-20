import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../models/payroll.dart';
import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../services/employee_service.dart';
import '../../services/expense_service.dart';
import '../../services/order_service.dart';
import '../../services/payroll_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/range_picker.dart';
import '../../utils/date_utils.dart';
import '../../utils/delivery_stats.dart';
import '../../utils/income_stats.dart';
import '../../utils/payroll_math.dart';
import '../../utils/wash_stats.dart';
import '../../widgets/item_measurement_form.dart' show fmtSom;
import '../../widgets/stream_error_view.dart';
import '../activity/delivery_orders_screen.dart';
import 'work_items_screen.dart';

/// Hisobot uchun ma'lumot manbalari — sahifani bazasiz (namunaviy
/// ma'lumot bilan) chizib tekshirish uchun alohida shartnoma.
abstract interface class ReportSources {
  Stream<({List<Order> orders, List<OrderHistoryEntry> history})> report(
      DateTime from, DateTime to);
  Stream<List<Expense>> expenses(DateTime from, DateTime to);
  Stream<List<Employee>> employees();

  /// Faqat ega uchun. Baza qoidalari yangilanmagan bo'lsa xato beradi —
  /// shunda maosh hisobga olinmaydi (va bu aytiladi).
  Stream<Map<String, StaffPay>> payrollStaff();
  Stream<Map<String, Map<String, WorkTally>>> workDays(DateTime from, DateTime to);
}

class FirebaseReportSources implements ReportSources {
  FirebaseReportSources();

  late final _orders = OrderService();
  late final _expenses = ExpenseService();
  late final _payroll = PayrollService();

  @override
  Stream<({List<Order> orders, List<OrderHistoryEntry> history})> report(
          DateTime from, DateTime to) =>
      _orders.streamReport(from, to);

  @override
  Stream<List<Expense>> expenses(DateTime from, DateTime to) =>
      _expenses.streamExpensesBetween(from, to);

  @override
  Stream<List<Employee>> employees() => EmployeeService().streamEmployees();

  @override
  Stream<Map<String, StaffPay>> payrollStaff() => _payroll.streamStaff();

  @override
  Stream<Map<String, Map<String, WorkTally>>> workDays(
          DateTime from, DateTime to) =>
      _payroll.streamWorkDays(from, to);
}

/// "Hisobotlar" — tanlangan davr bo'yicha biznesning moliyaviy natijasi
/// va sexdagi ish.
///
///  * Eng tepada — SOF FOYDA (katta): tushum − chiqimlar − maosh.
///  * Ostida uchta tashkil etuvchi: yalpi tushum (chiqim va maoshsiz),
///    chiqimlar, maosh (qat'iy oylikning shu kunlarga ulushi + ishbayi).
///  * Keyin tushum tafsiloti va faollik.
///
/// Davr — kalendardan: istalgan kun, istalgan oraliq yoki butun oy.
/// Standart — bugun. Ilgari "Kunlik/Haftalik/Oylik" tugmalari bor edi —
/// olib tashlandi (2026-11-20): kalendar ularning hammasini qamraydi.
class IncomeActivityScreen extends StatefulWidget {
  const IncomeActivityScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    @visibleForTesting this.sources,
    @visibleForTesting this.now,
  });

  final String currentUserId;
  final String currentUserName;

  /// Ochgan foydalanuvchining haqiqiy vakolatlari. Bu ekran "Hisobotlarni
  /// ko'rish" vakolati bo'lgan oddiy xodimga ham ochilgani uchun, bu yerdan
  /// ochiladigan buyurtmalarga admin huquqi berib yuborilmasligi shart.
  final StaffAccess access;

  final ReportSources? sources;
  final DateTime Function()? now;

  @override
  State<IncomeActivityScreen> createState() => _IncomeActivityScreenState();
}

class _IncomeActivityScreenState extends State<IncomeActivityScreen> {
  late final ReportSources _src = widget.sources ?? FirebaseReportSources();
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  /// Maosh faqat EGAGA ko'rinadi (xodimlar bir-birining oyligini
  /// ko'rmasligi kerak) — boshqalarda bu so'rov umuman yuborilmaydi.
  bool get _owner => widget.access.isAdmin;

  late DateRange _range = DateRange.today(now: _now);

  final _subs = <StreamSubscription<Object?>>[];
  StreamSubscription<Object?>? _employeesSub;
  StreamSubscription<Object?>? _staffSub;

  ({List<Order> orders, List<OrderHistoryEntry> history})? _report;
  List<Expense>? _expenses;
  List<Employee>? _employees;
  Map<String, StaffPay>? _staff;
  Map<String, Map<String, WorkTally>>? _days;
  Object? _error;

  /// Maosh tugunlari ochilmagan (qoidalar yangilanmagan) — foyda
  /// maoshsiz hisoblanadi va bu ochiq aytiladi.
  var _payrollOff = false;

  DateTime get _start => _range.from;
  DateTime get _end => _range.to;

  @override
  void initState() {
    super.initState();
    _employeesSub = _src.employees().listen(
      (v) => _set(() => _employees = v),
      onError: (Object e) => _set(() => _employees = const []),
    );
    if (_owner) {
      _staffSub = _src.payrollStaff().listen(
        (v) => _set(() => _staff = v),
        onError: (Object e) => _set(() => _payrollOff = true),
      );
    }
    _listenRange();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _employeesSub?.cancel();
    _staffSub?.cancel();
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  /// Davr o'zgarganda so'rovlar ham yangilanadi — eski davr ma'lumotini
  /// mahalliy filtrlab ko'rsatish noto'g'ri (kam) raqam berardi.
  void _listenRange() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _report = null;
    _expenses = null;
    _days = null;
    _error = null;
    _subs
      ..add(_src.report(_start, _end).listen(
            (v) => _set(() => _report = v),
            onError: (Object e) => _set(() => _error = e),
          ))
      ..add(_src.expenses(_start, _end).listen(
            (v) => _set(() => _expenses = v),
            onError: (Object e) => _set(() => _error = e),
          ));
    if (_owner) {
      _subs.add(_src.workDays(_start, _end).listen(
            (v) => _set(() => _days = v),
            onError: (Object e) => _set(() => _payrollOff = true),
          ));
    }
  }

  void _applyRange(DateRange range) {
    setState(() => _range = range);
    _listenRange();
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

  /// Maosh hali yuklanmoqdami (ega uchun, qoidalar ochiq bo'lsa).
  bool get _payrollLoading =>
      _owner && !_payrollOff && (_staff == null || _days == null);

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final loading = _report == null ||
        _expenses == null ||
        _employees == null ||
        _payrollLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Hisobotlar')),
      body: error != null
          ? StreamErrorView(error: error, onRetry: () => setState(_listenRange))
          : ListView(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                RangeBar(value: _range, onChanged: _applyRange, now: _now),
                const SizedBox(height: 16),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ..._buildStats(context),
              ],
            ),
    );
  }

  /// Hajm bo'limi: sarlavha, izoh va birlik bo'yicha qatorlar.
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
    final period = _range.label(now: _now);
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
                subtitle: '${stats.totalItems} ta xizmat · $period',
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
              label: '${v.unit.label} · ${v.itemCount} ta',
              value: formatVolume(v.quantity, v.unit),
              onInspect: () => _openWorkItems(
                context,
                title: '$title — ${v.unit.label}',
                subtitle:
                    '${formatVolume(v.quantity, v.unit)} · ${v.itemCount} ta '
                    'xizmat · $period',
                items: v.items,
                color: color,
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _buildStats(BuildContext context) {
    final theme = Theme.of(context);
    final orders = _report!.orders;
    final history = _report!.history;
    final expenses = _expenses!;
    final employees = _employees!;

    // ---- Moliya ----
    final delivered = orders
        .where((o) =>
            o.deliveredAt != null &&
            isWithinRange(o.deliveredAt!, _start, _end))
        .toList();
    // Pul QAYSI KUNI OLINGAN bo'lsa, o'sha kunning tushumi. Qarz
    // to'lovlari yetkazilgan kunga emas, to'langan kunga yoziladi.
    final incomeStats = incomeForRange(orders, history, _start, _end);
    final income = incomeStats.total;
    final expenseTotal = expenses
        .where((e) => isWithinRange(e.spentAt, _start, _end))
        .fold<double>(0, (sum, e) => sum + e.amount);
    final salary = _owner && !_payrollOff
        ? salaryCost(
            from: _start,
            to: _end,
            staff: _staff ?? const {},
            days: _days ?? const {},
            employees: employees,
            today: _now,
          )
        : null;
    final profit = income - expenseTotal - (salary?.total ?? 0);
    final debt = delivered.fold<double>(0, (sum, o) => sum + o.debtAmount);
    final debtCount = delivered.where((o) => o.hasDebt).length;
    final discount =
        delivered.fold<double>(0, (sum, o) => sum + o.discountAmount);

    // ---- Faollik ----
    final wash = washStatsForRange(orders, history, _start, _end);
    // Yuvish va qadoqlash ALOHIDA hisoblanadi: bir kunda yuvilgan narsa
    // ertasiga qadoqlanishi mumkin.
    final packaged = packagedStatsForRange(orders, history, _start, _end);
    final created =
        orders.where((o) => isWithinRange(o.createdAt, _start, _end)).length;
    final statsByEmployee = deliveryStatsByEmployee(orders, _start, _end);
    // Yetgazmani BOSHQARUVCHI ham qiladi, u esa xodimlar ro'yxatida
    // yo'q — ro'yxat ikki manbadan yig'iladi.
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
      _ProfitHero(
        profit: profit,
        includesSalary: salary != null,
        days: _range.days,
      ),
      const SizedBox(height: 12),
      _PartRow(
        icon: Icons.account_balance_wallet_rounded,
        tone: StageTone.success,
        label: 'Yalpi tushum',
        caption: 'Chiqim va maoshsiz, olingan pul',
        value: fmtSom(income),
        onInspect: delivered.isEmpty
            ? null
            : () => _openOrders(context, 'Davr bo\'yicha yetkazmalar', delivered),
      ),
      const SizedBox(height: 8),
      _PartRow(
        icon: Icons.receipt_long_rounded,
        tone: StageTone.danger,
        label: 'Chiqimlar',
        caption: 'Shu davrda sarflangan',
        value: expenseTotal > 0 ? '−${fmtSom(expenseTotal)}' : fmtSom(0),
      ),
      if (_owner) ...[
        const SizedBox(height: 8),
        _PartRow(
          icon: Icons.payments_rounded,
          tone: StageTone.brand,
          label: 'Maosh',
          caption: salary == null
              ? 'Maosh hisobi tez orada qo\'shiladi'
              : salary.fixed > 0
                  ? 'Ishbayi ${fmtSom(salary.piece)} · oylik ulushi ${fmtSom(salary.fixed)}'
                  : 'Xodimlarning ishbayi',
          value: salary == null
              ? '—'
              : salary.total > 0
                  ? '−${fmtSom(salary.total)}'
                  : fmtSom(0),
        ),
      ],
      const SizedBox(height: 22),
      _SectionHeader(
        icon: Icons.payments_rounded,
        title: 'Tushum tafsiloti',
        subtitle: 'Pul qanday olingan',
      ),
      const SizedBox(height: 12),
      _StatRow(
        icon: Icons.payments_outlined,
        color: AppColors.success,
        label: 'Naqd pul',
        value: fmtSom(incomeStats.cash),
        onInspect: () => _openOrders(
          context,
          'Naqd to\'langan buyurtmalar',
          delivered.where((o) => o.paymentMethod == cashPaymentLabel).toList(),
        ),
      ),
      const SizedBox(height: 8),
      _StatRow(
        icon: Icons.credit_card_rounded,
        color: AppColors.accent,
        label: 'Karta orqali',
        value: fmtSom(incomeStats.card),
        onInspect: () => _openOrders(
          context,
          'Karta orqali to\'langan buyurtmalar',
          delivered.where((o) => o.paymentMethod == cardPaymentLabel).toList(),
        ),
      ),
      if (incomeStats.other > 0) ...[
        const SizedBox(height: 8),
        _StatRow(
          icon: Icons.more_horiz_rounded,
          color: AppColors.info,
          label: 'Boshqa usulda',
          value: fmtSom(incomeStats.other),
        ),
      ],
      if (incomeStats.debtPayments > 0) ...[
        const SizedBox(height: 8),
        _StatRow(
          icon: Icons.history_rounded,
          color: AppColors.info,
          label: 'Shundan qarz to\'lovlari',
          value: fmtSom(incomeStats.debtPayments),
        ),
      ],
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
        label: 'Qarzga qoldi ($debtCount ta)',
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
      const SizedBox(height: 22),
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
                label: 'Topshirilgan',
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
        hint: 'Xizmat "Tayyor" holatiga o\'tkazilgan sana bo\'yicha.',
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

/// Sof foyda — sahifaning eng muhim raqami.
class _ProfitHero extends StatelessWidget {
  const _ProfitHero({
    required this.profit,
    required this.includesSalary,
    required this.days,
  });

  final double profit;
  final bool includesSalary;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = profit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: positive
              ? AppColors.heroGradient
              : const [Color(0xFF991B1B), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Sof foyda',
                style: theme.textTheme.titleSmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              positive ? fmtSom(profit) : '−${fmtSom(profit.abs())}',
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            includesSalary
                ? 'Tushum − chiqimlar − maosh'
                : 'Tushum − chiqimlar',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

/// Sof foydaning tashkil etuvchisi: ikonka, nom, izoh va summa.
class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.caption,
    required this.value,
    this.onInspect,
  });

  final IconData icon;
  final StageTone tone;
  final String label;
  final String caption;
  final String value;
  final VoidCallback? onInspect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: context.colorSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: context.colorBorder),
      ),
      child: InkWell(
        onTap: onInspect,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          // Nom va summa BIR qatorda, izoh esa ostida — butun kenglikda.
          // Tor ekranda izoh summa yonida siqilib, 3-4 qatorga
          // bo'linib ketmaydi; juda katta summa esa kichrayadi, kesilmaydi.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.soft(context),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: tone.ink(context)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(label, style: theme.textTheme.titleSmall),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                value,
                                maxLines: 1,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: tone.ink(context),
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: AppFonts.tabular,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (onInspect != null)
                          Icon(Icons.chevron_right_rounded,
                              size: 20, color: context.colorTextTertiary),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(caption, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
