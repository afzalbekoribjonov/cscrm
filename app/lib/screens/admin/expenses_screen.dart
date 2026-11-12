import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../models/expense.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/month_section.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../ui/uz_date_picker.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../utils/month_groups.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/stream_error_view.dart';

/// Chiqimlar — OYLAR bo'yicha.
///
/// Har bir oy sarlavhasida oy nomi va o'sha oydagi jami chiqim; oy
/// ochilsa — kunma-kun yozuvlar. Dastlab oxirgi 3 oy yuklanadi, eskirog'i
/// faqat so'ralganda (butun tarix bir yo'la yuklanmaydi).
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    @visibleForTesting this.expensesOf,
  });

  final String currentUserId;
  final String currentUserName;

  /// Faqat sinov/rasm uchun — bazasiz namunaviy chiqimlar.
  final Stream<List<Expense>> Function(DateTime from, DateTime to)? expensesOf;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const _step = 3;
  static const _maxMonths = 24;

  late final _service = ExpenseService();
  var _months = _step;
  late Stream<List<Expense>> _stream = _build();

  DateTime get _from {
    final now = DateTime.now();
    return DateTime(now.year, now.month - (_months - 1));
  }

  Stream<List<Expense>> _build() {
    final to = endOfDay(DateTime.now());
    return widget.expensesOf?.call(_from, to) ??
        _service.streamExpensesBetween(_from, to);
  }

  void _more() {
    setState(() {
      _months = (_months + _step).clamp(_step, _maxMonths);
      _stream = _build();
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
    final now = DateTime.now();
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
          final groups = groupByMonth<Expense>(
            snapshot.data!,
            at: (e) => e.spentAt,
            amount: (e) => e.amount,
          );
          final thisMonth = groups
              .where((g) => g.month.year == now.year && g.month.month == now.month)
              .firstOrNull;
          final todayTotal = snapshot.data!
              .where((e) => isSameDay(UzDates.fromMillis(e.spentAt), now))
              .fold<double>(0, (s, e) => s + e.amount);

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
                          Text('${UzDates.monthName(now.month)} oyida',
                              style: theme.textTheme.bodySmall),
                          Text(
                            formatSom(thisMonth?.total ?? 0),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: StageTone.danger.ink(context),
                              fontFeatures: AppFonts.tabular,
                            ),
                          ),
                          Text('${thisMonth?.items.length ?? 0} ta chiqim',
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
              const SizedBox(height: 16),
              if (groups.isEmpty)
                const SizedBox(
                  height: 320,
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Chiqim yozilmagan',
                    message: 'Ijara, kimyo vositalari, yoqilg\'i — har bir '
                        'sarfni "+" tugmasi orqali yozing.',
                  ),
                )
              else
                for (var i = 0; i < groups.length; i++) ...[
                  MonthSection(
                    key: ValueKey(groups[i].month),
                    month: groups[i].month,
                    count: groups[i].items.length,
                    countLabel: 'ta chiqim',
                    total: groups[i].total,
                    tone: StageTone.danger,
                    initiallyOpen: i == 0,
                    children: [
                      for (final e in groups[i].items)
                        _ExpenseRow(expense: e, onTap: () => _openForm(expense: e)),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              if (_months < _maxMonths)
                Center(
                  child: TextButton.icon(
                    onPressed: _more,
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Oldingi oylarni ko\'rsatish'),
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
