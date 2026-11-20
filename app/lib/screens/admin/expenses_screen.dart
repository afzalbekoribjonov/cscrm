import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../models/expense.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/money_calendar.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../ui/uz_date_picker.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../utils/month_groups.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/stream_error_view.dart';

/// Chiqimlar — KALENDAR ko'rinishida.
///
///  * Oylar tasmasi — har bir oyning jami chiqimi, bosilsa o'sha oy.
///  * Kalendar — har bir kun katagida o'sha kungi chiqim ("180 ming"),
///    ko'p sarf qilingan kun to'qroq rangda.
///  * Pastda — tanlangan kunning (yoki butun oyning) yozuvlari.
///
/// Dastlab oxirgi 6 oy yuklanadi; eskiroq oyga o'tilganda oraliq
/// kengayadi (butun tarix bir yo'la yuklanmaydi).
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    @visibleForTesting this.expensesOf,
    @visibleForTesting this.now,
  });

  final String currentUserId;
  final String currentUserName;

  /// Faqat sinov/rasm uchun — bazasiz namunaviy chiqimlar.
  final Stream<List<Expense>> Function(DateTime from, DateTime to)? expensesOf;
  final DateTime Function()? now;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const _window = 6;
  static const _maxMonths = 36;

  late final _service = ExpenseService();
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  late DateTime _month = DateTime(_now.year, _now.month);
  DateTime? _selected;

  /// Yuklangan oraliqning boshi (oy).
  late DateTime _from = DateTime(_now.year, _now.month - (_window - 1));
  late Stream<List<Expense>> _stream = _build();

  DateTime get _oldest => DateTime(_now.year, _now.month - (_maxMonths - 1));

  Stream<List<Expense>> _build() {
    final to = endOfDay(_now);
    return widget.expensesOf?.call(_from, to) ??
        _service.streamExpensesBetween(_from, to);
  }

  void _showMonth(DateTime m) {
    setState(() {
      _month = DateTime(m.year, m.month);
      _selected = null;
      if (_month.isBefore(_from)) {
        _from = _month;
        _stream = _build();
      }
    });
  }

  Future<void> _openForm({Expense? expense}) async {
    final saved = await showAppSheet<bool>(
      context,
      (_) => _ExpenseFormSheet(
        expense: expense,
        service: _service,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
    );
    if (saved == true && mounted) {
      showResult(context, expense == null ? 'Chiqim qo\'shildi' : 'Saqlandi');
    } else if (saved == false && mounted) {
      showResult(context, 'Chiqim o\'chirildi');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = _now;
    return Scaffold(
      appBar: AppBar(title: const Text('Chiqimlar')),
      floatingActionButton: FloatingActionButton(
        tooltip: t('Chiqim qo\'shish'),
        onPressed: () => _openForm(),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return StreamErrorView(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final groups = groupByMonth<Expense>(
            all,
            at: (e) => e.spentAt,
            amount: (e) => e.amount,
          );
          final monthTotals = <DateTime, double>{
            DateTime(now.year, now.month): 0,
            for (final g in groups) g.month: g.total,
          };
          final inMonth = groups
                  .where((g) =>
                      g.month.year == _month.year && g.month.month == _month.month)
                  .firstOrNull
                  ?.items ??
              const <Expense>[];
          final byDay = <int, double>{};
          final countByDay = <int, int>{};
          for (final e in inMonth) {
            final d = UzDates.fromMillis(e.spentAt).day;
            byDay[d] = (byDay[d] ?? 0) + e.amount;
            countByDay[d] = (countByDay[d] ?? 0) + 1;
          }
          final selected = _selected;
          final shown = selected == null
              ? inMonth
              : inMonth
                  .where((e) => isSameDay(UzDates.fromMillis(e.spentAt), selected))
                  .toList();
          final shownTotal = shown.fold<double>(0, (s, e) => s + e.amount);
          final todayTotal = all
              .where((e) => isSameDay(UzDates.fromMillis(e.spentAt), now))
              .fold<double>(0, (s, e) => s + e.amount);
          final monthTotal = monthTotals[_month] ?? 0;

          return ListView(
            padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page,
                100 + MediaQuery.of(context).padding.bottom),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${UzDates.monthYear(_month)} chiqimi',
                              style: theme.textTheme.bodySmall),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatSom(monthTotal),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: StageTone.danger.ink(context),
                                fontFeatures: AppFonts.tabular,
                              ),
                            ),
                          ),
                          Text('${inMonth.length} ta chiqim',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 52, color: context.colorBorder),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bugun', style: theme.textTheme.bodySmall),
                        Text(
                          formatSom(todayTotal),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: AppFonts.tabular,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              MonthTotalsStrip(
                months: monthTotals,
                selected: _month,
                tone: StageTone.danger,
                onSelected: _showMonth,
              ),
              const SizedBox(height: 12),
              MoneyCalendar(
                month: _month,
                totals: byDay,
                counts: countByDay,
                tone: StageTone.danger,
                selected: selected,
                now: now,
                canGoBack: _month.isAfter(_oldest),
                onMonthChanged: _showMonth,
                onDaySelected: (d) => setState(() => _selected = d),
              ),
              const SizedBox(height: 18),
              SectionHeader(
                title: selected == null
                    ? '${UzDates.monthYear(_month)} — barcha chiqimlar'
                    : '${UzDates.relativeDay(selected, now: now)}, '
                        '${UzDates.weekdays[selected.weekday - 1]}',
                subtitle: shown.isEmpty
                    ? null
                    : '${shown.length} ta · ${formatSom(shownTotal)}',
                actionLabel: selected == null ? null : 'Butun oy',
                onAction: selected == null
                    ? null
                    : () => setState(() => _selected = null),
              ),
              if (shown.isEmpty)
                AppCard(
                  child: Row(
                    children: [
                      const IconTile(
                          icon: Icons.receipt_long_outlined,
                          tone: StageTone.neutral),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selected == null
                              ? 'Bu oyda chiqim yozilmagan. Har bir sarfni "+" '
                                  'tugmasi orqali yozing.'
                              : 'Bu kunda chiqim yo\'q.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, indent: 14, color: context.colorBorder),
                        _ExpenseRow(
                          expense: shown[i],
                          onTap: () => _openForm(expense: shown[i]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense, required this.onTap});

  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = UzDates.fromMillis(expense.spentAt);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    [
                      UzDates.relativeDay(day),
                      if (expense.createdByName.isNotEmpty)
                        expense.createdByName == 'Admin'
                            ? 'Boshqaruvchi'
                            : expense.createdByName,
                      if (expense.note.isNotEmpty) expense.note,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              formatSom(expense.amount),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chiqim qo'shish/tahrirlash. Natija: `true` — saqlandi, `false` —
/// o'chirildi, `null` — bekor qilindi.
class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.service,
    required this.currentUserId,
    required this.currentUserName,
    this.expense,
  });

  final ExpenseService service;
  final String currentUserId;
  final String currentUserName;
  final Expense? expense;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  late final _titleCtrl = TextEditingController(text: widget.expense?.title ?? '');
  late final _amountCtrl = TextEditingController(
    text: widget.expense == null ? '' : formatMoney(widget.expense!.amount),
  );
  late final _noteCtrl = TextEditingController(text: widget.expense?.note ?? '');
  late DateTime _spentAt = widget.expense == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(widget.expense!.spentAt);

  var _saving = false;
  var _showErrors = false;

  bool get _isEdit => widget.expense != null;

  /// Tez tanlash — eng ko'p uchraydigan sarflar.
  static const _suggestions = [
    'Kimyo vositalari',
    'Ijara',
    'Elektr',
    'Suv',
    'Yoqilg\'i',
    'Ish haqi',
    'Ta\'mirlash',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showUzDatePicker(
      context,
      title: 'Chiqim sanasi',
      initial: _spentAt,
      last: DateTime.now(),
      quickDays: const [QuickDay('Bugun', 0), QuickDay('Kecha', -1)],
    );
    if (picked != null && mounted) setState(() => _spentAt = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = parseMoney(_amountCtrl.text);
    if (title.isEmpty || amount <= 0) {
      setState(() => _showErrors = true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.service.updateExpense(
          id: widget.expense!.id,
          title: title,
          amount: amount,
          spentAt: _spentAt,
          note: _noteCtrl.text,
        );
      } else {
        await widget.service.addExpense(
          title: title,
          amount: amount,
          spentAt: _spentAt,
          note: _noteCtrl.text,
          createdBy: widget.currentUserId,
          createdByName: widget.currentUserName,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        showResult(context, 'Saqlab bo\'lmadi. Qayta urinib ko\'ring.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Chiqimni o\'chirish',
      message: '"${widget.expense!.title}" (${formatSom(widget.expense!.amount)}) '
          'o\'chiriladi.',
      confirmLabel: 'O\'chirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await widget.service.deleteExpense(widget.expense!.id);
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SheetFrame(
      title: _isEdit ? 'Chiqimni tahrirlash' : 'Yangi chiqim',
      actions: Row(
        children: [
          if (_isEdit) ...[
            IconButton.outlined(
              tooltip: t('O\'chirish'),
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Saqlash'),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t('Nima uchun'),
              prefixIcon: const Icon(Icons.edit_note_rounded),
              errorText: _showErrors && _titleCtrl.text.trim().isEmpty
                  ? t('Chiqim nomini yozing')
                  : null,
            ),
          ),
          if (!_isEdit) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in _suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => setState(() => _titleCtrl.text = s),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              const MoneyInputFormatter(),
            ],
            onChanged: (_) => setState(() {}),
            style: theme.textTheme.titleLarge?.copyWith(fontFeatures: AppFonts.tabular),
            decoration: InputDecoration(
              labelText: t('Summa'),
              suffixText: t('so\'m'),
              prefixIcon: const Icon(Icons.payments_outlined),
              errorText: _showErrors && parseMoney(_amountCtrl.text) <= 0
                  ? t('Summani kiriting')
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(Radii.md),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: t('Sana'),
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: const Icon(Icons.expand_more_rounded),
              ),
              child: Text(
                '${UzDates.relativeDay(_spentAt)}'
                '${isSameDay(_spentAt, DateTime.now()) ? '' : ', ${UzDates.weekdays[_spentAt.weekday - 1]}'}',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteCtrl,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: t('Izoh (ixtiyoriy)'),
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
