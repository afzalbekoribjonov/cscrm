import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/payroll.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../utils/payroll_math.dart';
import '../home/app_menu.dart';
import 'employee_payroll_screen.dart';
import 'payroll_settings_screen.dart';
import 'payroll_sources.dart';
import 'payroll_widgets.dart';

/// "Maosh" — xodimlarning oylik hisob-kitobi va bugungi ishi.
///
///  * Oy bo'yicha: har bir xodimga hisoblangan (qat'iy + ishbayi),
///    berilgan (avans, oylik) va qoldiq.
///  * Bugun: kim qancha ish qildi — "Yuvdi: 124 m² · 41 m · 4 kichik".
///
/// Ma'lumot kichik: bir oylik ish = 30 ta kunlik yig'indi yozuvi.
class PayrollScreen extends StatefulWidget {
  const PayrollScreen({
    super.key,
    required this.user,
    @visibleForTesting this.sources,
    @visibleForTesting this.now,
  });

  final AppUser user;
  final PayrollSources? sources;
  final DateTime Function()? now;

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  late final PayrollSources _src = widget.sources ?? FirebasePayrollSources();
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  late DateTime _month = DateTime(_now.year, _now.month);

  final _subs = <StreamSubscription<Object?>>[];
  final _monthSubs = <StreamSubscription<Object?>>[];

  List<Employee>? _employees;
  Map<String, StaffPay>? _staff;
  PayrollRates? _rates;
  Map<String, Map<String, WorkTally>>? _days;
  List<PayrollPayment>? _payments;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _subs
      ..add(_listen<List<Employee>>(_src.employees(), (v) => _employees = v))
      ..add(_listen<Map<String, StaffPay>>(_src.staff(), (v) => _staff = v))
      ..add(_listen<PayrollRates>(_src.rates(), (v) => _rates = v));
    _listenMonth();
  }

  @override
  void dispose() {
    for (final s in [..._subs, ..._monthSubs]) {
      s.cancel();
    }
    super.dispose();
  }

  StreamSubscription<T> _listen<T>(Stream<T> stream, void Function(T v) on) =>
      stream.listen(
        (v) {
          if (mounted) setState(() => on(v));
        },
        onError: (Object e) {
          if (mounted) setState(() => _error = e);
        },
      );

  void _listenMonth() {
    for (final s in _monthSubs) {
      s.cancel();
    }
    _monthSubs.clear();
    _days = null;
    _payments = null;
    _monthSubs
      ..add(_listen<Map<String, Map<String, WorkTally>>>(
          _src.workDays(startOfMonth(_month), endOfMonth(_month)),
          (v) => _days = v))
      ..add(_listen<List<PayrollPayment>>(
          _src.payments(monthKey(_month)), (v) => _payments = v));
  }

  void _setMonth(DateTime m) {
    setState(() => _month = m);
    _listenMonth();
  }

  void _openEmployee(MonthPayroll p) {
    final employee = _employees?.where((e) => e.id == p.employeeId).firstOrNull;
    if (employee == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EmployeePayrollScreen(
        employee: employee,
        user: widget.user,
        initialMonth: _month,
        sources: _src,
        now: widget.now,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final appBar = AppBar(
      title: const Text('Maosh'),
      actions: [
        IconButton(
          tooltip: t('Maosh sozlamasi'),
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PayrollSettingsScreen(sources: widget.sources),
          )),
        ),
        const SizedBox(width: 4),
      ],
    );
    if (error != null) {
      return Scaffold(appBar: appBar, body: PayrollUnavailable(error: error));
    }
    final employees = _employees;
    final staff = _staff;
    final days = _days;
    final payments = _payments;
    if (employees == null || staff == null || days == null || payments == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final work = tallyByEmployee(days);
    final rows = monthPayroll(
      employees: employees,
      staff: staff,
      work: work,
      payments: payments,
    );
    final accrued = rows.fold<double>(0, (s, r) => s + r.accrued);
    final paid = rows.fold<double>(0, (s, r) => s + r.paid);
    final now = _now;
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final today = isCurrent
        ? todayRanking(
            today: days[dayKey(now)] ?? const {},
            employees: employees,
            staff: staff,
          )
        : const <({String id, String name, WorkTally work, double earned})>[];
    final unconfigured = rows.where((r) => !r.configured).length;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, 32 + bottom),
        children: [
          MonthSwitcher(month: _month, onChanged: _setMonth, now: now),
          const SizedBox(height: 12),
          _SummaryCard(accrued: accrued, paid: paid, isCurrent: isCurrent),
          if (_rates != null && !_rates!.isConfigured) ...[
            const SizedBox(height: 12),
            _SetupCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PayrollSettingsScreen(sources: widget.sources),
              )),
            ),
          ],
          if (isCurrent) ...[
            const SizedBox(height: 22),
            SectionHeader(
              title: 'Bugun',
              subtitle: today.isEmpty
                  ? 'Hali ish yozilmagan'
                  : '${today.length} ta xodim ishladi',
              live: true,
            ),
            if (today.isEmpty)
              AppCard(
                child: Row(
                  children: [
                    const IconTile(
                        icon: Icons.schedule_rounded, tone: StageTone.neutral),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Xizmat yuvilib, qadoqlanib, topshirilganda bu yerda '
                        'ko\'rinadi.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < today.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, indent: 66, color: context.colorBorder),
                      TodayWorkRow(
                        name: today[i].name,
                        work: today[i].work,
                        earned: today[i].earned,
                        onTap: () {
                          final row = rows
                              .where((r) => r.employeeId == today[i].id)
                              .firstOrNull;
                          if (row != null) _openEmployee(row);
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Xodimlar',
            subtitle: unconfigured == 0
                ? 'Oylik hisob · bosib batafsil ko\'ring'
                : '$unconfigured ta xodimning maoshi sozlanmagan',
          ),
          if (rows.isEmpty)
            AppCard(
              child: Text('Hali xodim qo\'shilmagan.',
                  style: Theme.of(context).textTheme.bodyMedium),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 66, color: context.colorBorder),
                    _EmployeeRow(row: rows[i], onTap: () => _openEmployee(rows[i])),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.accrued,
    required this.paid,
    required this.isCurrent,
  });

  final double accrued;
  final double paid;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = accrued - paid;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCurrent ? 'Shu oy hisoblangan maosh' : 'Oy bo\'yicha hisoblangan',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatSom(accrued),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroCell(label: 'Berilgan', value: formatSom(paid)),
              ),
              Container(width: 1, height: 34, color: Colors.white24),
              const SizedBox(width: 14),
              Expanded(
                child: _HeroCell(
                  label: remaining < 0 ? 'Ortiqcha berilgan' : 'Qoldiq',
                  value: formatSom(remaining.abs()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCell extends StatelessWidget {
  const _HeroCell({required this.label, required this.value});

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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      borderColor: StageTone.warning.fill.withValues(alpha: 0.5),
      child: Row(
        children: [
          const IconTile(icon: Icons.tune_rounded, tone: StageTone.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ishbayi narxlari kiritilmagan',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  'Har bir xizmat uchun yuvish va qadoqlash narxini, '
                  'dastavchik va dispetcher ulushini kiriting.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.row, required this.onTap});

  final MonthPayroll row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = row;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            UserAvatar(initials: initialsOf(r.name), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name.isEmpty ? 'Xodim' : r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SalaryTypePill(pay: r.pay),
                      if (r.configured && r.paid > 0)
                        Text(
                          'Qoldiq: ${formatSom(r.remaining)}',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatSom(r.configured ? r.accrued : r.work.allPiecePay),
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFeatures: AppFonts.tabular,
                    color: r.configured ? null : context.colorTextTertiary,
                  ),
                ),
                Text(
                  r.configured ? 'hisoblangan' : 'sozlanmagan',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
          ],
        ),
      ),
    );
  }
}

/// Bugungi ish qatori: ism, ish turlari bo'yicha hajm va ishlagan puli.
/// Bosh sahifada ham ishlatiladi.
class TodayWorkRow extends StatelessWidget {
  const TodayWorkRow({
    super.key,
    required this.name,
    required this.work,
    required this.earned,
    this.onTap,
  });

  final String name;
  final WorkTally work;
  final double earned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = workLines(work);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(initials: initialsOf(name), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'Xodim' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        earned > 0 ? '+${formatSom(earned)}' : formatSom(earned),
                        maxLines: 1,
                        softWrap: false,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: earned > 0
                              ? StageTone.success.ink(context)
                              : context.colorTextTertiary,
                          fontFeatures: AppFonts.tabular,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '${l.label}: ',
                            style: theme.textTheme.bodySmall,
                          ),
                          TextSpan(
                            text: l.value,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.colorTextPrimary,
                              fontWeight: FontWeight.w600,
                              fontFeatures: AppFonts.tabular,
                            ),
                          ),
                        ]),
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
