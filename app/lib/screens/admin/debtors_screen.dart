import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/order.dart';
import '../../models/staff_access.dart';
import '../../models/staff_permission.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/item_measurement_form.dart' show fmtSom;
import '../../widgets/period_calendar.dart';
import '../../widgets/phone_link.dart';
import '../../widgets/stream_error_view.dart';

final _dateFormat = DateFormat('dd.MM.yyyy');

/// To'liq to'lanmagan buyurtmalar. Dastavchik topshirish paytida farqni
/// "Qarz" deb belgilaganda buyurtma shu ro'yxatga tushadi.
class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final _service = OrderService();
  // Faqat qarzi bor buyurtmalar - `debtAmount` indeksi bo'yicha.
  late final _ordersStream = _service.streamDebtors();

  /// Standart: BUGUN. Tanlov ekran holatida - aylantirganda qaytmaydi.
  PeriodSelection _selection = PeriodSelection.today();

  DateTime get _start => _selection.range.$1;
  DateTime get _end => _selection.range.$2;

  bool get _canSeePhone => widget.access.can(StaffPermission.viewPhone);

  Future<void> _settle(Order order) async {
    final result = await showModalBottomSheet<({double amount, String method})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SettleDebtSheet(order: order),
    );
    if (result == null || !mounted) return;
    await _service.settleDebt(
      order: order,
      amount: result.amount,
      method: result.method,
      byEmployeeId: widget.currentUserId,
      byName: widget.access.isAdmin ? 'Admin' : widget.currentUserName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Qarzdorlar')),
      body: StreamBuilder<List<Order>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Qarz yetkazilgan sana bo'yicha filtrlanadi - qarz aynan
          // topshirish paytida paydo bo'ladi.
          final debtors = snapshot.data!
              .where((o) =>
                  o.hasDebt &&
                  o.deliveredAt != null &&
                  isWithinRange(o.deliveredAt!, _start, _end))
              .toList()
            ..sort((a, b) => b.debtAmount.compareTo(a.debtAmount));
          final total = debtors.fold<double>(0, (sum, o) => sum + o.debtAmount);

          return ListView(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
            children: [
              _DebtTotalBanner(count: debtors.length, total: total),
              const SizedBox(height: 16),
              PeriodBar(
                value: _selection,
                onChanged: (s) => setState(() => _selection = s),
              ),
              const SizedBox(height: 18),
              if (debtors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 40, color: AppColors.success),
                        const SizedBox(height: 10),
                        Text(
                          'Bu davrda qarzdorlik yo\'q',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...debtors.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DebtorCard(
                      order: order,
                      maskPhone: !_canSeePhone,
                      onSettle: () => _settle(order),
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

class _DebtTotalBanner extends StatelessWidget {
  const _DebtTotalBanner({required this.count, required this.total});

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
          colors: [AppColors.danger, AppColors.danger.withValues(alpha: 0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Umumiy qarzdorlik',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  fmtSom(total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$count ta buyurtma',
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

class _DebtorCard extends StatelessWidget {
  const _DebtorCard({
    required this.order,
    required this.maskPhone,
    required this.onSettle,
  });

  final Order order;
  final bool maskPhone;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.code,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.customerName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            PhoneLink(phone: order.customerPhone, masked: maskPhone),
            if (order.address.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 15, color: context.colorTextSecondary),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(order.address,
                        style: theme.textTheme.bodySmall, maxLines: 2),
                  ),
                ],
              ),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qarz summasi', style: theme.textTheme.bodySmall),
                      Text(
                        fmtSom(order.debtAmount),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onSettle,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 17),
                  label: const Text('To\'lov'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Buyurtma narxi ${fmtSom(order.totalPrice)} · olingan '
              '${fmtSom(order.paymentAmount ?? 0)}'
              '${order.deliveredAt != null ? ' · ${_dateFormat.format(DateTime.fromMillisecondsSinceEpoch(order.deliveredAt!))}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Qarzni to'liq yoki qisman yopish oynasi.
class _SettleDebtSheet extends StatefulWidget {
  const _SettleDebtSheet({required this.order});

  final Order order;

  @override
  State<_SettleDebtSheet> createState() => _SettleDebtSheetState();
}

class _SettleDebtSheetState extends State<_SettleDebtSheet> {
  late final _amountCtrl =
      TextEditingController(text: widget.order.debtAmount.toStringAsFixed(0));
  String _method = 'Naqd pul';
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Summani to\'g\'ri kiriting');
      return;
    }
    if (amount > widget.order.debtAmount) {
      setState(() => _error = 'Summa qarzdan ko\'p bo\'lmasin');
      return;
    }
    Navigator.of(context).pop((amount: amount, method: _method));
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Qarzni yopish', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${widget.order.code} · ${widget.order.customerName} · '
            'qarz ${fmtSom(widget.order.debtAmount)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'Naqd pul',
                label: Text('Naqd pul'),
                icon: Icon(Icons.payments_outlined),
              ),
              ButtonSegment(
                value: 'Karta',
                label: Text('Karta'),
                icon: Icon(Icons.credit_card_rounded),
              ),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => setState(() => _error = null),
            decoration: const InputDecoration(
              labelText: 'To\'lanayotgan summa',
              suffixText: 'so\'m',
              helperText: 'Qisman to\'lansa, qolgan qarz saqlanadi',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
              onPressed: _submit, child: const Text('Qabul qilindi')),
        ],
      ),
    );
  }
}
