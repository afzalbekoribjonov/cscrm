import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/expense.dart';
import '../../services/expense_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/item_measurement_form.dart' show fmtSom;
import '../../widgets/period_calendar.dart';
import '../../widgets/stream_error_view.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// Sex chiqimlari: kalendar davri bo'yicha filtrlangan ro'yxat, jami
/// summa banneri va qo'shish/tahrirlash/o'chirish imkoniyati.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _service = ExpenseService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa, davr
  // almashtirilganda ro'yxat "waiting" holatiga qaytib flicker qilardi.
  late final _expensesStream = _service.streamExpenses();

  /// Standart: BUGUN. Tanlov ekran holatida - aylantirganda qaytmaydi.
  PeriodSelection _selection = PeriodSelection.today();

  DateTime get _start => _selection.range.$1;
  DateTime get _end => _selection.range.$2;

  Future<void> _openForm({Expense? expense}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExpenseFormSheet(
        expense: expense,
        service: _service,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
    );
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chiqimni o\'chirish'),
        content: Text(
          '"${expense.title}" (${fmtSom(expense.amount)}) o\'chiriladi. '
          'Bu amalni ortga qaytarib bo\'lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteExpense(expense.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chiqimlar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Chiqim qo\'shish'),
      ),
      body: StreamBuilder<List<Expense>>(
        stream: _expensesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!;
          final filtered =
              all.where((e) => isWithinRange(e.spentAt, _start, _end)).toList();
          final total = filtered.fold<double>(0, (sum, e) => sum + e.amount);

          return ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
            children: [
              _TotalBanner(count: filtered.length, total: total),
              const SizedBox(height: 16),
              PeriodBar(
                value: _selection,
                onChanged: (s) => setState(() => _selection = s),
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text(
                      'Bu davrda chiqim yozilmagan',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ...filtered.map(
                  (expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExpenseCard(
                      expense: expense,
                      onEdit: () => _openForm(expense: expense),
                      onDelete: () => _confirmDelete(expense),
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

class _TotalBanner extends StatelessWidget {
  const _TotalBanner({required this.count, required this.total});

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.danger, AppColors.danger.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Davr bo\'yicha chiqim',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  fmtSom(total),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$count ta yozuv',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_dateFormat.format(DateTime.fromMillisecondsSinceEpoch(expense.spentAt))}'
                    '${expense.createdByName.isEmpty ? '' : ' · ${expense.createdByName}'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (expense.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(expense.note, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtSom(expense.amount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Tahrirlash',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      icon: Icon(Icons.edit_outlined,
                          size: 17, color: context.colorTextSecondary),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      tooltip: 'O\'chirish',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints(minWidth: 34, minHeight: 34),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 17, color: AppColors.danger),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chiqim qo'shish/tahrirlash oynasi. [expense] berilsa tahrirlash
/// rejimida ochiladi.
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
  late final _titleCtrl =
      TextEditingController(text: widget.expense?.title ?? '');
  late final _amountCtrl = TextEditingController(
    text:
        widget.expense == null ? '' : widget.expense!.amount.toStringAsFixed(0),
  );
  late final _noteCtrl =
      TextEditingController(text: widget.expense?.note ?? '');
  late DateTime _spentAt = widget.expense == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(widget.expense!.spentAt);

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.expense != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      helpText: 'Chiqim sanasini tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
    );
    if (picked != null && mounted) setState(() => _spentAt = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (title.isEmpty) {
      setState(() => _error = 'Chiqim nomini kiriting');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Summani to\'g\'ri kiriting');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
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
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = 'Saqlab bo\'lmadi. Qayta urining.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Chiqimni tahrirlash' : 'Yangi chiqim',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nomi',
                hintText: 'masalan: Kimyo vositalari',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Summa',
                suffixText: 'so\'m',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Sana',
                  prefixIcon: Icon(Icons.event_rounded),
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                child: Text(_dateFormat.format(_spentAt)),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Izoh',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }
}
