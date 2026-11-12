import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/expense.dart';
import '../../models/item_status.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../models/order_status.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/action_menu.dart';
import '../../ui/bar_chart.dart';
import '../../ui/surfaces.dart';
import '../../utils/date_utils.dart';
import '../../utils/income_stats.dart';
import '../../utils/money.dart';
import '../../utils/order_sections.dart';
import '../../utils/team_stats.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/notification_action.dart';
import '../admin/debtors_screen.dart';
import '../admin/expenses_screen.dart';
import '../admin/income_activity_screen.dart';
import '../home/app_menu.dart';
import '../new_order/new_order_screen.dart';
import '../search/order_search_screen.dart';
import 'dashboard_sources.dart';
import 'employee_day_screen.dart';
import 'order_list_screen.dart';

/// Boshqaruvchining bosh sahifasi — "Asosiy".
///
/// Biznesning bugungi to'liq holati bitta sahifada: tushum, ish oqimi,
/// diqqat talab qiladigan joylar, jamoa natijalari va moliya.
///
/// TRAFIK: ish oqimi allaqachon ochiq turgan oqimdan olinadi (qo'shimcha
/// so'rov yo'q). Qo'shimcha faqat BUGUNNING tor kesmasi so'raladi:
/// bugungi tarix, bugungi chiqimlar, qarzdorlar. Haftalik grafik esa
/// faqat foydalanuvchi uni ochganda yuklanadi.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.sections,
    required this.onOpenSection,
    this.sources,
  });

  /// Ma'lumot manbai. Berilmasa — Firebase.
  final DashboardSources? sources;

  final AppUser user;
  final OrderSections sections;
  final ValueChanged<WorkSection> onOpenSection;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _weekKey = 'dashboard_week_chart';

  late final DashboardSources _src =
      widget.sources ?? FirebaseDashboardSources();
  final _subs = <StreamSubscription<Object?>>[];
  StreamSubscription<Object?>? _weekSub;
  StreamSubscription<Object?>? _weekOrdersSub;
  Timer? _midnight;

  late DateTime _day = startOfDay(DateTime.now());

  List<OrderHistoryEntry>? _todayHistory;
  List<Order> _todayDelivered = const [];
  List<Expense> _expenses = const [];
  List<Order>? _debtors;
  List<Employee> _employees = const [];

  // Haftalik grafik — so'ralgandagina.
  var _weekOpen = false;
  List<OrderHistoryEntry>? _weekHistory;
  List<Order>? _weekDelivered;
  var _chartIncome = true;

  @override
  void initState() {
    super.initState();
    _listenDay();
    _subs.add(_listen<List<Order>>(_src.debtors(), (v) => _debtors = v));
    _subs.add(_listen<List<Employee>>(
        _src.employees(), (v) => _employees = v));
    _scheduleMidnight();
    SharedPreferences.getInstance().then((p) {
      if (p.getBool(_weekKey) == true && mounted) _openWeek();
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _midnight?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _weekSub?.cancel();
    _weekOrdersSub?.cancel();
    super.dispose();
  }

  StreamSubscription<T> _listen<T>(Stream<T> stream, void Function(T v) on) =>
      stream.listen(
        (value) {
          if (mounted) setState(() => on(value));
        },
        onError: (Object e) => debugPrint('Bosh sahifa oqimi: $e'),
      );

  final _daySubs = <StreamSubscription<Object?>>[];

  void _listenDay() {
    for (final s in _daySubs) {
      s.cancel();
    }
    _daySubs.clear();
    final end = endOfDay(_day);
    _daySubs
      ..add(_listen<List<OrderHistoryEntry>>(
          _src.history(_day, end), (v) => _todayHistory = v))
      ..add(_listen<List<Order>>(
          _src.delivered(_day, end), (v) => _todayDelivered = v))
      ..add(_listen<List<Expense>>(
          _src.expenses(_day, end), (v) => _expenses = v));
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = startOfDay(now).add(const Duration(days: 1));
    _midnight = Timer(next.difference(now) + const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _day = startOfDay(DateTime.now());
        _todayHistory = null;
        _todayDelivered = const [];
        _expenses = const [];
      });
      _listenDay();
      if (_weekOpen) _openWeek(force: true);
      _scheduleMidnight();
    });
  }

  void _openWeek({bool force = false}) {
    if (_weekOpen && !force) return;
    _weekSub?.cancel();
    _weekOrdersSub?.cancel();
    final start = _day.subtract(const Duration(days: 6));
    final end = endOfDay(_day);
    setState(() => _weekOpen = true);
    _weekSub = _listen<List<OrderHistoryEntry>>(
        _src.history(start, end), (v) => _weekHistory = v);
    _weekOrdersSub = _listen<List<Order>>(
        _src.delivered(start, end), (v) => _weekDelivered = v);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_weekKey, true))
        .catchError((Object _) => false);
  }

  void _push(WidgetBuilder b) =>
      Navigator.of(context).push(MaterialPageRoute(builder: b));

  Map<int, Order> get _ordersById => {
        for (final o in widget.sections.all) o.id: o,
        for (final o in _todayDelivered) o.id: o,
      };

  Map<String, String> get _names => {
        for (final e in _employees) e.id: e.fullName,
      };

  @override
  Widget build(BuildContext context) {
    final s = widget.sections;
    final history = _todayHistory;
    final summary = history == null
        ? null
        : summarizeDay(
            day: _day,
            orders: _todayDelivered,
            history: history,
            ordersById: _ordersById,
          );
    final team = history == null
        ? const <EmployeeWork>[]
        : teamWork(
            history: history,
            delivered: _todayDelivered,
            start: _day,
            end: endOfDay(_day),
            ordersById: _ordersById,
            names: _names,
          );
    final createdToday = s.all
        .where((o) => o.createdAt >= _day.millisecondsSinceEpoch)
        .length;
    final active = s.all.where((o) => !o.status.isClosed).length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async => _listenDay(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  user: widget.user,
                  day: _day,
                  income: summary?.income,
                  active: active,
                  createdToday: createdToday,
                  deliveredToday: _todayDelivered.length,
                  onSearch: () => _push((_) => OrderSearchScreen(
                        sections: s,
                        user: widget.user,
                      )),
                  onMenu: () => openAppMenu(context, widget.user),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(Gap.page, 16, Gap.page,
                    28 + MediaQuery.of(context).padding.bottom),
                sliver: SliverList.list(
                  children: [
                    ..._alerts(s),
                    _QuickActions(actions: [
                      _Quick(Icons.add_rounded, 'Buyurtma', StageTone.brand,
                          () => _push((_) => NewOrderScreen(
                              user: widget.user, sections: s))),
                      _Quick(Icons.receipt_long_outlined, 'Chiqim',
                          StageTone.danger, () => _push((_) => ExpensesScreen(
                              currentUserId: widget.user.id,
                              currentUserName: widget.user.name))),
                      _Quick(Icons.request_quote_outlined, 'Qarzdorlar',
                          StageTone.warning, () => _push((_) => DebtorsScreen(
                              currentUserId: widget.user.id,
                              currentUserName: widget.user.name,
                              access: widget.user.access))),
                      _Quick(Icons.insights_rounded, 'Hisobot', StageTone.info,
                          () => _push((_) => IncomeActivityScreen(
                              currentUserId: widget.user.id,
                              currentUserName: widget.user.name,
                              access: widget.user.access))),
                    ]),
                    const SizedBox(height: 24),
                    _pipeline(s),
                    const SizedBox(height: 24),
                    _production(summary),
                    const SizedBox(height: 24),
                    _team(team),
                    const SizedBox(height: 24),
                    _finance(summary),
                    const SizedBox(height: 24),
                    _week(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ogohlantirish

  List<Widget> _alerts(OrderSections s) {
    final now = DateTime.now();
    final today = startOfDay(now);
    final overdue = s.all
        .where((o) =>
            !o.status.isClosed &&
            o.deadline != null &&
            DateTime.fromMillisecondsSinceEpoch(o.deadline!).isBefore(today))
        .toList();
    final rewash = s.all
        .where((o) => o.items.any((i) => i.status == ItemStatus.qaytaYuvildi))
        .toList();

    final alerts = <Widget>[
      if (overdue.isNotEmpty)
        _Alert(
          tone: StageTone.danger,
          icon: Icons.event_busy_rounded,
          text: '${overdue.length} ta buyurtmaning muddati o\'tgan',
          onTap: () => _push((_) => OrderListScreen(
                title: 'Muddati o\'tgan',
                orders: overdue,
                user: widget.user,
              )),
        ),
      if (rewash.isNotEmpty)
        _Alert(
          tone: StageTone.rewash,
          icon: Icons.replay_rounded,
          text: '${rewash.length} ta buyurtmada qayta yuvish',
          onTap: () => _push((_) => OrderListScreen(
                title: 'Qayta yuvishda',
                orders: rewash,
                user: widget.user,
              )),
        ),
      if (s.unmeasured.isNotEmpty)
        _Alert(
          tone: StageTone.warning,
          icon: Icons.straighten_rounded,
          text: '${s.unmeasured.length} ta xizmat o\'lchanmagan',
          onTap: () => widget.onOpenSection(WorkSection.yuvish),
        ),
      if (s.warehouse.isNotEmpty)
        _Alert(
          tone: StageTone.warehouse,
          icon: Icons.warehouse_rounded,
          text: '${s.warehouse.length} ta buyurtma omborda',
          onTap: () => openWarehouse(context, widget.user),
        ),
    ];
    if (alerts.isEmpty) return const [];
    return [
      for (final a in alerts) ...[a, const SizedBox(height: 8)],
      const SizedBox(height: 12),
    ];
  }

  // ---------------------------------------------------------------- ish oqimi

  Widget _pipeline(OrderSections s) {
    int itemsWhere(bool Function(ItemStatus st) test) => s.all.fold<int>(
        0,
        (n, o) => o.status.isInWorkshop ||
                o.status == OrderStatus.yetgazishgaTayyor
            ? n + o.items.where((i) => !i.isHanded && test(i.status)).length
            : n);

    final rows = <_Stage>[
      _Stage('Olib kelish', Icons.moped_rounded, StageTone.pickup,
          s.pickup.length, 'buyurtma', () => widget.onOpenSection(WorkSection.yetgazma)),
      _Stage('Navbatda', Icons.hourglass_top_rounded, StageTone.queued,
          itemsWhere((st) => st.awaitsWash), 'xizmat',
          () => widget.onOpenSection(WorkSection.yuvish)),
      _Stage('Yuvilmoqda', Icons.local_laundry_service_rounded, StageTone.washing,
          itemsWhere((st) => st == ItemStatus.yuvilmoqda), 'xizmat',
          () => widget.onOpenSection(WorkSection.yuvish)),
      _Stage('Qadoqlashda', Icons.inventory_2_rounded, StageTone.packaging,
          itemsWhere((st) => st == ItemStatus.qadoqlashda), 'xizmat',
          () => widget.onOpenSection(WorkSection.qadoqlash)),
      _Stage('Deyarli tayyor', Icons.timelapse_rounded, StageTone.almost,
          s.almostReady.length, 'buyurtma',
          () => widget.onOpenSection(WorkSection.yetgazma)),
      _Stage('Tayyor', Icons.check_circle_rounded, StageTone.ready,
          s.readyForDelivery.length, 'buyurtma',
          () => widget.onOpenSection(WorkSection.yetgazma)),
      if (s.policies.warehouseEnabled)
        _Stage('Omborda', Icons.warehouse_rounded, StageTone.warehouse,
            s.warehouse.length, 'buyurtma',
            () => openWarehouse(context, widget.user)),
    ];
    final total = rows.fold<int>(0, (n, r) => n + r.count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Ish oqimi',
          subtitle: 'Hozir sexda va yo\'lda',
          live: true,
          actionLabel: 'Hammasi',
          onAction: () => _push((_) => OrderSearchScreen(
                sections: s,
                user: widget.user,
              )),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _StageBar(rows: rows, total: total),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 48, color: context.colorBorder),
                _StageRow(stage: rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------- bugungi ish

  Widget _production(DaySummary? d) {
    final header = SectionHeader(
      title: 'Bugungi ish',
      subtitle: UzDates.date(_day),
    );
    if (d == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const AppCard(child: _Loading())],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        AppCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BigMetric(
                    icon: Icons.local_laundry_service_rounded,
                    tone: StageTone.washing,
                    value: d.washed.squareMeters > 0
                        ? '${formatQuantity(d.washed.squareMeters)} m²'
                        : '${d.washed.items}',
                    label: 'Yuvildi',
                    caption: '${d.washed.items} ta xizmat',
                  ),
                  _BigMetric(
                    icon: Icons.inventory_2_rounded,
                    tone: StageTone.packaging,
                    value: d.packaged.squareMeters > 0
                        ? '${formatQuantity(d.packaged.squareMeters)} m²'
                        : '${d.packaged.items}',
                    label: 'Qadoqlandi',
                    caption: '${d.packaged.items} ta xizmat',
                  ),
                  _BigMetric(
                    icon: Icons.replay_rounded,
                    tone: StageTone.rewash,
                    value: '${d.rewashed}',
                    label: 'Qayta yuvish',
                    caption: 'xizmat',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Divider(height: 1, color: context.colorBorder),
              ),
              Row(
                children: [
                  _SmallMetric(value: d.created, label: 'Qabul'),
                  _SmallMetric(value: d.pickedUp, label: 'Olib kelindi'),
                  _SmallMetric(value: d.delivered, label: 'Topshirildi'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ jamoa

  Widget _team(List<EmployeeWork> team) {
    final header = SectionHeader(
      title: 'Jamoa',
      subtitle: 'Bugungi natijalar · istalgan kunni ko\'rish uchun bosing',
    );
    if (_todayHistory == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const AppCard(child: _Loading())],
      );
    }
    if (team.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          AppCard(
            child: Row(
              children: [
                const IconTile(icon: Icons.groups_outlined, tone: StageTone.neutral),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Bugun hali ish belgilanmagan',
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                TextButton(
                  onPressed: () => _push((_) => EmployeeDayScreen(
                        employees: _employees,
                        user: widget.user,
                        sources: _src,
                      )),
                  child: const Text('Kunlar'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < team.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 64, color: context.colorBorder),
                _TeamRow(
                  rank: i + 1,
                  work: team[i],
                  onTap: () => _push((_) => EmployeeDayScreen(
                        employees: _employees,
                        user: widget.user,
                        sources: _src,
                        initialEmployeeId: team[i].id,
                        initialName: team[i].name,
                      )),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ moliya

  Widget _finance(DaySummary? d) {
    final theme = Theme.of(context);
    final expenses = _expenses.fold<double>(0, (s, e) => s + e.amount);
    final income = d?.income.total ?? 0;
    final net = income - expenses;
    final debtors = _debtors;
    final debtTotal =
        debtors?.fold<double>(0, (s, o) => s + o.debtAmount) ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: 'Moliya', subtitle: 'Bugun'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _LabeledAmount(
                        label: 'Tushum',
                        value: formatSom(income),
                        color: StageTone.success.ink(context),
                      ),
                    ),
                    Expanded(
                      child: _LabeledAmount(
                        label: 'Chiqim',
                        value: formatSom(expenses),
                        color: StageTone.danger.ink(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorSurfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text('Sof qoldiq', style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(
                        formatSom(net),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: net < 0
                              ? StageTone.danger.ink(context)
                              : StageTone.success.ink(context),
                          fontFeatures: AppFonts.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: context.colorBorder),
              ListTile(
                onTap: () => _push((_) => DebtorsScreen(
                      currentUserId: widget.user.id,
                      currentUserName: widget.user.name,
                      access: widget.user.access,
                    )),
                leading: const IconTile(
                    icon: Icons.request_quote_outlined, tone: StageTone.warning),
                title: const Text('Qarzdorlik'),
                subtitle: Text(debtors == null
                    ? 'Yuklanmoqda…'
                    : debtors.isEmpty
                        ? 'Qarzdor yo\'q'
                        : '${debtors.length} ta buyurtma'),
                trailing: Text(
                  debtors == null ? '' : formatSom(debtTotal),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: debtTotal > 0 ? StageTone.warning.ink(context) : null,
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- hafta

  Widget _week() {
    final theme = Theme.of(context);
    if (!_weekOpen) {
      return AppCard(
        onTap: () => _openWeek(),
        child: Row(
          children: [
            const IconTile(icon: Icons.bar_chart_rounded, tone: StageTone.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Haftalik dinamika', style: theme.textTheme.titleSmall),
                  Text('Oxirgi 7 kunlik tushum va yuvilgan hajm',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Text('Ko\'rsatish', style: theme.textTheme.labelLarge?.copyWith(
              color: context.colorPrimaryInk,
              fontWeight: FontWeight.w700,
            )),
          ],
        ),
      );
    }
    final history = _weekHistory;
    final delivered = _weekDelivered;
    final ready = history != null && delivered != null;
    final days = [
      for (var i = 6; i >= 0; i--) _day.subtract(Duration(days: i)),
    ];
    final points = !ready
        ? const <DaySummary>[]
        : [
            for (final d in days)
              summarizeDay(
                day: d,
                orders: delivered,
                history: history,
                ordersById: _ordersById,
              ),
          ];
    final tone = _chartIncome ? StageTone.success : StageTone.washing;
    final total = points.fold<double>(
        0, (s, p) => s + (_chartIncome ? p.income.total : p.washed.squareMeters));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Haftalik dinamika',
          trailing: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: true, label: Text('Tushum')),
              ButtonSegment(value: false, label: Text('m²')),
            ],
            selected: {_chartIncome},
            onSelectionChanged: (s) => setState(() => _chartIncome = s.first),
          ),
        ),
        AppCard(
          child: !ready
              ? const _Loading()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('7 kunda', style: theme.textTheme.bodySmall),
                    Text(
                      _chartIncome
                          ? formatSom(total)
                          : '${formatQuantity(total)} m²',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                    const SizedBox(height: 14),
                    MiniBarChart(
                      color: tone.fill,
                      bars: [
                        for (final p in points)
                          BarDatum(
                            label: UzDates.weekdaysShort[p.day.weekday - 1],
                            value: _chartIncome
                                ? p.income.total
                                : p.washed.squareMeters,
                            valueLabel: _chartIncome
                                ? compactSom(p.income.total)
                                : '${formatQuantity(p.washed.squareMeters)} m²',
                            highlighted: isSameDay(p.day, _day),
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ===========================================================================

class _Hero extends StatelessWidget {
  const _Hero({
    required this.user,
    required this.day,
    required this.income,
    required this.active,
    required this.createdToday,
    required this.deliveredToday,
    required this.onSearch,
    required this.onMenu,
  });

  final AppUser user;
  final DateTime day;
  final IncomeStats? income;
  final int active;
  final int createdToday;
  final int deliveredToday;
  final VoidCallback onSearch;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.of(context).padding.top;
    final total = income?.total;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(right: -60, top: -50, child: _Glow(size: 220, opacity: 0.10)),
            const Positioned(left: -90, bottom: -100, child: _Glow(size: 250, opacity: 0.07)),
            Padding(
              padding: EdgeInsets.fromLTRB(18, top + 8, 6, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButtonTheme(
                    data: IconButtonThemeData(
                      style: IconButton.styleFrom(foregroundColor: Colors.white),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.businessName.isEmpty ? 'Asosiy' : user.businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                              Text(
                                '${UzDates.weekdays[day.weekday - 1]}, ${UzDates.date(day)}',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: t('Qidiruv'),
                          onPressed: onSearch,
                          icon: const Icon(Icons.search_rounded),
                        ),
                        const NotificationAction(),
                        MoreButton(onPressed: onMenu),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Bugungi tushum',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      total == null ? '…' : formatSom(total),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _GlassChip(
                        icon: Icons.payments_outlined,
                        label: 'Naqd ${formatMoney(income?.cash ?? 0)}',
                      ),
                      _GlassChip(
                        icon: Icons.credit_card_rounded,
                        label: 'Karta ${formatMoney(income?.card ?? 0)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        Expanded(child: _GlassStat(value: '$active', label: 'Ishda')),
                        const SizedBox(width: 10),
                        Expanded(child: _GlassStat(value: '$createdToday', label: 'Qabul')),
                        const SizedBox(width: 10),
                        Expanded(child: _GlassStat(value: '$deliveredToday', label: 'Topshirildi')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.display,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              fontFeatures: AppFonts.tabular,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.tone,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final StageTone tone;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = tone.ink(context);
    return Material(
      color: tone.soft(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: ink, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _Quick {
  const _Quick(this.icon, this.label, this.tone, this.onTap);
  final IconData icon;
  final String label;
  final StageTone tone;
  final VoidCallback onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});
  final List<_Quick> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: InkWell(
              onTap: a.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    IconTile(icon: a.icon, tone: a.tone, size: 52, radius: 16),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stage {
  const _Stage(this.label, this.icon, this.tone, this.count, this.unit, this.onTap);
  final String label;
  final IconData icon;
  final StageTone tone;
  final int count;
  final String unit;
  final VoidCallback onTap;
}

/// Bosqichlarning ulushi — bitta to'plangan chiziq.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.rows, required this.total});
  final List<_Stage> rows;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: context.colorSurfaceMuted,
          borderRadius: BorderRadius.circular(5),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (final r in rows)
              if (r.count > 0)
                Expanded(
                  flex: r.count,
                  child: Container(
                    margin: const EdgeInsets.only(right: 2),
                    color: r.tone.fill,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage});
  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: stage.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            IconTile(icon: stage.icon, tone: stage.tone, size: 36, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                stage.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 8),
            // Son va birlik BITTA qatorda — "1 buyurtma". Ilgari birlik
            // tor ustunga qo'yilgan edi va katta shriftli telefonda so'z
            // ikkiga bo'linib, oxirgi harfi pastga tushib qolardi.
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${stage.count}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFeatures: AppFonts.tabular,
                    color: stage.count == 0 ? context.colorTextTertiary : null,
                  ),
                ),
                TextSpan(
                  text: ' ${stage.unit}',
                  style: theme.textTheme.bodySmall,
                ),
              ]),
              maxLines: 1,
              softWrap: false,
            ),
            Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
          ],
        ),
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
    required this.caption,
  });

  final IconData icon;
  final StageTone tone;
  final String value;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          IconTile(icon: icon, tone: tone, size: 40),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ),
          Text(label, style: theme.textTheme.labelLarge),
          Text(caption, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              fontFeatures: AppFonts.tabular,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.rank, required this.work, required this.onTap});
  final int rank;
  final EmployeeWork work;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (!work.washed.isEmpty) 'yuvdi ${work.washed.label()}',
      if (!work.packaged.isEmpty) 'qadoqladi ${work.packaged.items} ta',
      if (work.created > 0) 'qabul ${work.created}',
      if (work.pickedUp > 0) 'olib keldi ${work.pickedUp}',
      if (work.delivered > 0) 'topshirdi ${work.delivered}',
    ];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            UserAvatar(initials: initialsOf(work.name), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    work.name.isEmpty ? 'Xodim' : work.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.isEmpty ? 'Faol' : parts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (work.collected > 0) ...[
              const SizedBox(width: 8),
              Text(
                compactSom(work.collected),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: StageTone.success.ink(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
          ],
        ),
      ),
    );
  }
}

class _LabeledAmount extends StatelessWidget {
  const _LabeledAmount({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
}
