import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/payroll.dart';
import '../../models/work_section.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../utils/payroll_math.dart';
import '../../utils/uz_dates.dart';
import '../../services/payroll_service.dart';
import 'payroll_sources.dart';
import 'payroll_widgets.dart';

/// Bitta xodimning maoshi: turi, oylik hisob-kitob, to'lovlar va kunlar
/// bo'yicha ish.
class EmployeePayrollScreen extends StatefulWidget {
  const EmployeePayrollScreen({
    super.key,
    required this.employee,
    required this.user,
    required this.initialMonth,
    this.sources,
    this.now,
  });

  final Employee employee;
  final AppUser user;
  final DateTime initialMonth;
  final PayrollSources? sources;
  final DateTime Function()? now;

  @override
  State<EmployeePayrollScreen> createState() => _EmployeePayrollScreenState();
}

class _EmployeePayrollScreenState extends State<EmployeePayrollScreen> {
  late final PayrollSources _src = widget.sources ?? FirebasePayrollSources();
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  late DateTime _month = widget.initialMonth;

  StreamSubscription<Object?>? _staffSub;
  final _monthSubs = <StreamSubscription<Object?>>[];

  Map<String, StaffPay>? _staff;
  Map<String, Map<String, WorkTally>>? _days;
  List<PayrollPayment>? _payments;
  Object? _error;

  String get _id => widget.employee.id;

  @override
  void initState() {
    super.initState();
    _staffSub = _src.staff().listen(
      (v) => setState(() => _staff = v),
      onError: (Object e) => setState(() => _error = e),
    );
    _listenMonth();
  }

  @override
  void dispose() {
    _staffSub?.cancel();
    for (final s in _monthSubs) {
      s.cancel();
    }
    super.dispose();
  }

  void _listenMonth() {
    for (final s in _monthSubs) {
      s.cancel();
    }
    _monthSubs.clear();
    _days = null;
    _payments = null;
    _monthSubs
      ..add(_src
          .workDays(startOfMonth(_month), endOfMonth(_month))
          .listen((v) => setState(() => _days = v),
              onError: (Object e) => setState(() => _error = e)))
      ..add(_src.payments(monthKey(_month)).listen(
          (v) => setState(() => _payments = v),
          onError: (Object e) => setState(() => _error = e)));
  }

  void _setMonth(DateTime m) {
    setState(() => _month = m);
    _listenMonth();
  }

  /// Yangi sozlamada ish turlari xodimning BO'LIMLARIGA qarab tanlanadi.
  StaffPay _defaultPay() {
    final s = widget.employee.sections;
    return StaffPay(
      type: SalaryType.piece,
      pieces: {
        if (s.contains(WorkSection.yuvish)) PieceKind.wash,
        if (s.contains(WorkSection.qadoqlash)) PieceKind.pack,
        if (s.contains(WorkSection.yetgazma)) PieceKind.courier,
        if (s.contains(WorkSection.yangi)) PieceKind.dispatch,
      },
    );
  }

  Future<void> _editPay(StaffPay? current) async {
    final saved = await showAppSheet<bool>(
      context,
      (_) => _StaffPaySheet(
        initial: current ?? _defaultPay(),
        onSave: (pay) => _src.saveStaff(_id, pay),
      ),
    );
    if (saved == true && mounted) showResult(context, 'Maosh turi saqlandi');
  }

  Future<void> _pay(PaymentKind kind, double suggested) async {
    final saved = await showAppSheet<bool>(
      context,
      (_) => _PaymentSheet(
        kind: kind,
        month: _month,
        suggested: suggested,
        onSave: (amount, note) => _src.addPayment(
          employeeId: _id,
          amount: amount,
          kind: kind,
          month: monthKey(_month),
          note: note,
          byName: widget.user.historyName,
        ),
      ),
    );
    if (saved == true && mounted) {
      showResult(context,
          kind == PaymentKind.advance ? 'Avans yozildi' : 'Oylik to\'lovi yozildi');
    }
  }

  Future<void> _deletePayment(PayrollPayment p) async {
    final ok = await confirmAction(
      context,
      title: '${p.kind.label}ni o\'chirish',
      message: '${formatSom(p.amount)} — ${UzDates.date(UzDates.fromMillis(p.at))}. '
          'Bu yozuv hisobdan olib tashlanadi.',
      confirmLabel: 'O\'chirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _src.deletePayment(p.id);
    } on PayrollException catch (e) {
      if (mounted) showResult(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showResult(context, 'O\'chirib bo\'lmadi. Qayta urinib ko\'ring.',
            error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.employee.fullName;
    final appBar = AppBar(
      title: Text(name.isEmpty ? 'Xodim' : name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
    );
    final error = _error;
    if (error != null) {
      return Scaffold(appBar: appBar, body: PayrollUnavailable(error: error));
    }
    final staff = _staff;
    final days = _days;
    final payments = _payments;
    if (staff == null || days == null || payments == null) {
      return Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final pay = staff[_id];
    final work = tallyByEmployee(days)[_id] ?? WorkTally();
    final mine = payments.where((p) => p.employeeId == _id).toList();
    final row = MonthPayroll(
      employeeId: _id,
      name: name,
      pay: pay,
      work: work,
      payments: mine,
    );
    final dayRows = [
      for (final d in days.entries)
        if (d.value[_id] != null && !d.value[_id]!.isEmpty)
          (day: dayFromKey(d.key), work: d.value[_id]!),
    ]..sort((a, b) =>
        (b.day ?? DateTime(0)).compareTo(a.day ?? DateTime(0)));
    final bottom = MediaQuery.of(context).padding.bottom;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: appBar,
      body: ListView(
        padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, 32 + bottom),
        children: [
          _PayTypeCard(pay: pay, onEdit: () => _editPay(pay)),
          const SizedBox(height: 12),
          MonthSwitcher(month: _month, onChanged: _setMonth, now: _now),
          const SizedBox(height: 12),
          _AccountCard(row: row),
          if (pay != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _pay(PaymentKind.advance, 0),
                    icon: const Icon(Icons.add_card_rounded),
                    label: const Text('Avans berish'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: () => _pay(PaymentKind.salary,
                        row.remaining > 0 ? row.remaining : 0),
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text('Oylik to\'lash'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          SectionHeader(
            title: 'To\'lovlar',
            subtitle: mine.isEmpty
                ? 'Bu oyda hali to\'lov yo\'q'
                : '${mine.length} ta · jami ${formatSom(row.paid)}',
          ),
          if (mine.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < mine.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, indent: 62, color: context.colorBorder),
                    _PaymentRow(
                      payment: mine[i],
                      onDelete: () => _deletePayment(mine[i]),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Kunlar bo\'yicha',
            subtitle: dayRows.isEmpty
                ? 'Bu oyda ish yozilmagan'
                : '${dayRows.length} kun ishladi',
          ),
          if (dayRows.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < dayRows.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: context.colorBorder),
                    _DayRow(
                      day: dayRows[i].day,
                      work: dayRows[i].work,
                      earned: pay == null
                          ? dayRows[i].work.allPiecePay
                          : dayRows[i].work.piecePay(pay.activePieces),
                    ),
                  ],
                ],
              ),
            ),
          if (pay == null && dayRows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Maosh turi belgilanmagan — summalar barcha ish turlari '
                'bo\'yicha taxminiy ko\'rsatilgan.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _PayTypeCard extends StatelessWidget {
  const _PayTypeCard({required this.pay, required this.onEdit});

  final StaffPay? pay;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = pay;
    if (p == null) {
      return AppCard(
        onTap: onEdit,
        borderColor: StageTone.warning.fill.withValues(alpha: 0.5),
        child: Row(
          children: [
            const IconTile(icon: Icons.badge_outlined, tone: StageTone.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maosh turi belgilanmagan',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text('Ishbayi, qat\'iy oylik yoki ikkalasi — tanlang',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton(onPressed: onEdit, child: const Text('Belgilash')),
          ],
        ),
      );
    }
    final pieces = p.activePieces;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.badge_rounded, tone: StageTone.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maosh turi', style: theme.textTheme.bodySmall),
                    Text(p.type.label, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('O\'zgartirish'),
              ),
            ],
          ),
          if (p.type.hasFixed) ...[
            const SizedBox(height: 10),
            InfoRow(label: 'Oylik', value: formatSom(p.monthly)),
          ],
          if (p.type.hasPiece) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (pieces.isEmpty)
                  const TonePill(
                    label: 'Ish turi tanlanmagan',
                    tone: StageTone.warning,
                    dense: true,
                  ),
                for (final k in PieceKind.values)
                  if (pieces.contains(k))
                    TonePill(
                      label: k.label,
                      icon: k.icon,
                      tone: StageTone.success,
                      dense: true,
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.row});

  final MonthPayroll row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = row;
    final p = r.pay;
    final w = r.work;
    final kinds = p?.activePieces ?? const <PieceKind>{};
    final remaining = r.remaining;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Oylik hisob', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          if (p == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Maosh turi belgilangach hisob shu yerda chiqadi.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: context.colorTextSecondary),
              ),
            )
          else ...[
            if (p.type.hasFixed)
              AmountLine(label: 'Qat\'iy oylik', amount: p.monthly),
            if (kinds.contains(PieceKind.wash))
              AmountLine(
                label: 'Yuvish',
                caption: w.wash.label(
                    empty: w.washN > 0 ? '${w.washN} ta xizmat' : 'Ish yo\'q'),
                amount: w.washPay,
              ),
            if (kinds.contains(PieceKind.wash) && w.rewashN > 0)
              AmountLine(
                label: 'Qayta yuvish ushlanmasi',
                caption: '${w.rewashN} ta xizmat qaytdi',
                amount: w.rewashPay,
                negative: true,
              ),
            if (kinds.contains(PieceKind.pack))
              AmountLine(
                label: 'Qadoqlash',
                caption: w.pack.label(
                    empty: w.packN > 0 ? '${w.packN} ta xizmat' : 'Ish yo\'q'),
                amount: w.packPay,
              ),
            if (kinds.contains(PieceKind.courier))
              AmountLine(
                label: 'Yetkazish',
                caption: w.deliverN > 0
                    ? '${w.deliverN} marta · ${formatSom(w.deliverSum)}'
                    : 'Ish yo\'q',
                amount: w.deliverPay,
              ),
            if (kinds.contains(PieceKind.dispatch))
              AmountLine(
                label: 'Dispetcherlik',
                caption: w.createN > 0
                    ? '${w.createN} ta buyurtma qabul qildi'
                    : 'Ish yo\'q',
                amount: w.createPay + w.dispatchPay,
              ),
            Divider(height: 18, color: context.colorBorder),
            AmountLine(label: 'Jami hisoblangan', amount: r.accrued, strong: true),
            if (r.paid > 0)
              AmountLine(
                label: 'Berilgan',
                caption: r.advances > 0 && r.advances < r.paid
                    ? 'shundan avans: ${formatSom(r.advances)}'
                    : null,
                amount: r.paid,
                negative: true,
              ),
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (remaining < 0 ? StageTone.danger : StageTone.success)
                    .soft(context),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: AmountLine(
                label: remaining < 0 ? 'Ortiqcha berilgan' : 'Qoldiq (beriladi)',
                amount: remaining.abs(),
                strong: true,
                color: (remaining < 0 ? StageTone.danger : StageTone.success)
                    .ink(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onDelete});

  final PayrollPayment payment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = payment;
    final advance = p.kind == PaymentKind.advance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          IconTile(
            icon: advance ? Icons.add_card_rounded : Icons.payments_rounded,
            tone: advance ? StageTone.warning : StageTone.success,
            size: 36,
            radius: 10,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatSom(p.amount),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontFeatures: AppFonts.tabular),
                ),
                Text(
                  [
                    p.kind.label,
                    UzDates.dateTime(UzDates.fromMillis(p.at)),
                    if (p.note.isNotEmpty && p.note != p.kind.label) p.note,
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t('O\'chirish'),
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded,
                color: context.colorTextTertiary),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.work, required this.earned});

  final DateTime? day;
  final WorkTally work;
  final double earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = day;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  d == null
                      ? '—'
                      : '${UzDates.relativeDay(d)}, ${UzDates.weekdays[d.weekday - 1]}',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                formatSom(earned),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: earned > 0 ? StageTone.success.ink(context) : null,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          for (final l in workLines(work))
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l.label}: ', style: theme.textTheme.bodySmall),
                TextSpan(
                  text: l.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.colorTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Maosh turini belgilash oynasi.
class _StaffPaySheet extends StatefulWidget {
  const _StaffPaySheet({required this.initial, required this.onSave});

  final StaffPay initial;
  final Future<void> Function(StaffPay pay) onSave;

  @override
  State<_StaffPaySheet> createState() => _StaffPaySheetState();
}

class _StaffPaySheetState extends State<_StaffPaySheet> {
  late SalaryType _type = widget.initial.type;
  late final _monthly = TextEditingController(
    text: widget.initial.monthly > 0 ? formatMoney(widget.initial.monthly) : '',
  );
  late final Set<PieceKind> _pieces = {...widget.initial.pieces};
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _monthly.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final monthly = parseMoney(_monthly.text);
    if (_type.hasFixed && monthly <= 0) {
      setState(() => _error = 'Oylik summani kiriting');
      return;
    }
    if (_type.hasPiece && _pieces.isEmpty) {
      setState(() => _error = 'Kamida bitta ish turini tanlang');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(StaffPay(
        type: _type,
        monthly: _type.hasFixed ? monthly : 0,
        pieces: _pieces,
      ));
      if (mounted) Navigator.of(context).pop(true);
    } on PayrollException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Saqlab bo\'lmadi. Qayta urinib ko\'ring.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetFrame(
      title: 'Maosh turi',
      subtitle: 'Hisob kalendar oyi bo\'yicha yuritiladi',
      actions: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Saqlash'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final type in SalaryType.values) ...[
            _TypeOption(
              type: type,
              selected: _type == type,
              onTap: () => setState(() {
                _type = type;
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
          ],
          if (_type.hasFixed) ...[
            const SizedBox(height: 8),
            MoneyField(controller: _monthly, label: 'Oylik summa'),
          ],
          if (_type.hasPiece) ...[
            const SizedBox(height: 16),
            Text('Ishbayi qaysi ishlar uchun',
                style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Narxlar "Maosh sozlamasi"da belgilanadi.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in PieceKind.values)
                  FilterChip(
                    avatar: Icon(k.icon, size: 18),
                    label: Text(k.label),
                    selected: _pieces.contains(k),
                    onSelected: (on) => setState(() {
                      on ? _pieces.add(k) : _pieces.remove(k);
                      _error = null;
                    }),
                  ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: StageTone.danger.ink(context)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final SalaryType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      borderColor: selected ? color : null,
      color: selected ? context.colorPrimarySoft : null,
      child: Row(
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: selected ? color : context.colorTextTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label, style: theme.textTheme.titleSmall),
                Text(type.hint, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Avans yoki oylik to'lovi oynasi.
class _PaymentSheet extends StatefulWidget {
  const _PaymentSheet({
    required this.kind,
    required this.month,
    required this.suggested,
    required this.onSave,
  });

  final PaymentKind kind;
  final DateTime month;
  final double suggested;
  final Future<void> Function(double amount, String note) onSave;

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final _amount = TextEditingController(
    text: widget.suggested > 0 ? formatMoney(widget.suggested) : '',
  );
  final _note = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseMoney(_amount.text);
    if (amount <= 0) {
      setState(() => _error = 'Summani kiriting');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(amount, _note.text);
      if (mounted) Navigator.of(context).pop(true);
    } on PayrollException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Saqlab bo\'lmadi. Qayta urinib ko\'ring.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final advance = widget.kind == PaymentKind.advance;
    return SheetFrame(
      title: advance ? 'Avans berish' : 'Oylik to\'lash',
      subtitle: '${UzDates.monthYear(widget.month)} hisobidan',
      actions: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Saqlash'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyField(controller: _amount, label: 'Summa', autofocus: true),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: t('Izoh (ixtiyoriy)'),
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: StageTone.danger.ink(context)),
            ),
          ],
        ],
      ),
    );
  }
}
