import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/text.dart';
import '../../l10n/transliterate.dart';
import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../models/staff_access.dart';
import '../../models/staff_permission.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/money_calendar.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../utils/date_utils.dart';
import '../../utils/delivery_stats.dart';
import '../../utils/money.dart';
import '../../utils/month_groups.dart';
import '../../utils/phone.dart';
import '../../utils/uz_dates.dart';
import '../../widgets/payment_dialog.dart';
import '../../widgets/phone_link.dart';
import '../../widgets/stream_error_view.dart';
import '../orders/order_detail_screen.dart';

/// Qarzdorlar — KALENDAR ko'rinishida.
///
///  * Tepada — jami qarz va qarzdorlar soni.
///  * Oylar tasmasi — har bir oyda paydo bo'lgan (buyurtma topshirilgan)
///    qarzning jami, bosilsa o'sha oy.
///  * Kalendar — har bir kunda qancha qarzga qoldi ("240 ming").
///  * Pastda — tanlangan kunning (yoki butun oyning) qarzdorlari.
///
/// Qidiruv yozilsa — kalendarsiz, barcha mos qarzdorlar ro'yxati.
class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    @visibleForTesting this.debtors,
    @visibleForTesting this.now,
  });

  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  /// Faqat sinov/rasm uchun — bazasiz namunaviy ro'yxat.
  final Stream<List<Order>>? debtors;
  final DateTime Function()? now;

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  late final _service = OrderService();
  // Faqat qarzi bor buyurtmalar — `debtAmount` indeksi bo'yicha.
  late final _stream = widget.debtors ?? _service.streamDebtors();
  final _search = TextEditingController();

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  DateTime? _month;
  DateTime? _selected;

  AppUser get _user => AppUser(
        id: widget.currentUserId,
        name: widget.currentUserName,
        access: widget.access,
      );

  bool get _canSeePhone => widget.access.can(StaffPermission.viewPhone);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _settle(Order order) async {
    final result = await showAppSheet<({double amount, String method})>(
      context,
      (_) => _SettleDebtSheet(order: order),
    );
    if (result == null || !mounted) return;
    try {
      await _service.settleDebt(
        order: order,
        amount: result.amount,
        method: result.method,
        byEmployeeId: widget.currentUserId,
        byName: _user.historyName,
      );
      if (mounted) showResult(context, 'To\'lov qabul qilindi');
    } catch (_) {
      if (mounted) {
        showResult(context, 'To\'lovni saqlab bo\'lmadi. Qayta urinib ko\'ring.',
            error: true);
      }
    }
  }

  bool _matches(Order o, String q) {
    if (q.isEmpty) return true;
    final digits = digitsOnly(q);
    if (digits.isNotEmpty && digits.length == q.replaceAll(RegExp(r'[\s+№#]'), '').length) {
      return '${o.id}'.startsWith(digits) ||
          (digits.length >= 4 && digitsOnly(o.customerPhone).contains(digits));
    }
    return searchKey('${o.customerName} ${o.address}').contains(searchKey(q));
  }

  /// Qarz paydo bo'lgan kun — buyurtma topshirilgan kun.
  static int _at(Order o) => o.deliveredAt ?? o.createdAt;

  Widget _row(Order order) => _DebtorRow(
        order: order,
        canSeePhone: _canSeePhone,
        onOpen: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id, user: _user),
          ),
        ),
        onSettle: () => _settle(order),
      );

  Widget _list(List<Order> orders) => AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < orders.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 14, color: context.colorBorder),
              _row(orders[i]),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = _now;
    return Scaffold(
      appBar: AppBar(title: const Text('Qarzdorlar')),
      body: StreamBuilder<List<Order>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return StreamErrorView(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snapshot.data!.where((o) => o.hasDebt).toList()
            ..sort((a, b) => _at(b).compareTo(_at(a)));
          final total = all.fold<double>(0, (s, o) => s + o.debtAmount);
          final q = _search.text.trim();
          final groups = groupByMonth<Order>(
            all,
            at: _at,
            amount: (o) => o.debtAmount,
          );
          // Standart oy — eng so'nggi qarz paydo bo'lgan oy.
          final month = _month ??
              (groups.isEmpty ? DateTime(now.year, now.month) : groups.first.month);
          final inMonth = groups
                  .where((g) => g.month.year == month.year && g.month.month == month.month)
                  .firstOrNull
                  ?.items ??
              const <Order>[];
          final byDay = <int, double>{};
          for (final o in inMonth) {
            final d = UzDates.fromMillis(_at(o)).day;
            byDay[d] = (byDay[d] ?? 0) + o.debtAmount;
          }
          final selected = _selected;
          final shown = selected == null
              ? inMonth
              : inMonth
                  .where((o) => isSameDay(UzDates.fromMillis(_at(o)), selected))
                  .toList();
          final shownTotal = shown.fold<double>(0, (s, o) => s + o.debtAmount);
          final found = q.isEmpty ? const <Order>[] : all.where((o) => _matches(o, q)).toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page,
                32 + MediaQuery.of(context).padding.bottom),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const IconTile(
                        icon: Icons.request_quote_outlined,
                        tone: StageTone.warning,
                        size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jami qarz', style: theme.textTheme.bodySmall),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatSom(total),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: total > 0
                                    ? StageTone.warning.ink(context)
                                    : null,
                                fontFeatures: AppFonts.tabular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${all.length} ta buyurtma',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (all.isNotEmpty)
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: t('Ism, telefon yoki № bo\'yicha qidirish'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            tooltip: t('Tozalash'),
                            onPressed: () => setState(_search.clear),
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              const SizedBox(height: 14),
              if (all.isEmpty)
                const SizedBox(
                  height: 360,
                  child: EmptyState(
                    icon: Icons.verified_outlined,
                    tone: StageTone.success,
                    title: 'Qarzdor yo\'q',
                    message: 'Barcha buyurtmalar to\'liq to\'langan.',
                  ),
                )
              else if (q.isNotEmpty) ...[
                SectionHeader(
                  title: 'Qidiruv natijasi',
                  subtitle: found.isEmpty ? null : '${found.length} ta',
                ),
                if (found.isEmpty)
                  const SizedBox(
                    height: 220,
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Topilmadi',
                    ),
                  )
                else
                  _list(found),
              ] else ...[
                MonthTotalsStrip(
                  months: {for (final g in groups) g.month: g.total},
                  selected: month,
                  tone: StageTone.warning,
                  onSelected: (m) => setState(() {
                    _month = m;
                    _selected = null;
                  }),
                ),
                const SizedBox(height: 12),
                MoneyCalendar(
                  month: month,
                  totals: byDay,
                  tone: StageTone.warning,
                  selected: selected,
                  now: now,
                  onMonthChanged: (m) => setState(() {
                    _month = m;
                    _selected = null;
                  }),
                  onDaySelected: (d) => setState(() => _selected = d),
                ),
                const SizedBox(height: 18),
                SectionHeader(
                  title: selected == null
                      ? '${UzDates.monthYear(month)} — qarzga qolganlar'
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
                    child: Text(
                      selected == null
                          ? 'Bu oyda qarzga qolgan buyurtma yo\'q.'
                          : 'Bu kunda qarzga qolgan buyurtma yo\'q.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                else
                  _list(shown),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DebtorRow extends StatelessWidget {
  const _DebtorRow({
    required this.order,
    required this.canSeePhone,
    required this.onOpen,
    required this.onSettle,
  });

  final Order order;
  final bool canSeePhone;
  final VoidCallback onOpen;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delivered = order.deliveredAt;
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        order.code,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: context.colorPrimaryInk,
                          fontFeatures: AppFonts.tabular,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  PhoneLink(
                    phone: order.customerPhone,
                    masked: !canSeePhone,
                    compact: true,
                    iconSize: 13,
                  ),
                  Text(
                    [
                      if (delivered != null)
                        'Topshirildi ${UzDates.date(UzDates.fromMillis(delivered))}',
                      'to\'langan ${formatSom(order.paymentAmount ?? 0)} / ${formatSom(order.totalPrice)}',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatSom(order.debtAmount),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: StageTone.danger.ink(context),
                    fontFeatures: AppFonts.tabular,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                    onPressed: onSettle,
                    child: const Text('To\'lov olish'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettleDebtSheet extends StatefulWidget {
  const _SettleDebtSheet({required this.order});

  final Order order;

  @override
  State<_SettleDebtSheet> createState() => _SettleDebtSheetState();
}

class _SettleDebtSheetState extends State<_SettleDebtSheet> {
  late final _amountCtrl =
      TextEditingController(text: formatMoney(widget.order.debtAmount));
  String _method = cashPaymentLabel;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = parseMoney(_amountCtrl.text);
    if (amount <= 0) {
      setState(() => _error = 'Summani kiriting');
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
    return SheetFrame(
      title: 'Qarz to\'lovi',
      subtitle: '${widget.order.code} · ${widget.order.customerName}',
      actions: FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.check_rounded),
        label: const Text('Qabul qilindi'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: context.colorSurfaceMuted,
            borderColor: Colors.transparent,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: InfoRow(
              label: 'Qarz',
              value: formatSom(widget.order.debtAmount),
              emphasize: true,
              valueColor: StageTone.danger.ink(context),
            ),
          ),
          const SizedBox(height: 16),
          PaymentMethodPicker(
            value: _method,
            onChanged: (m) => setState(() => _method = m),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              const MoneyInputFormatter(),
            ],
            style: theme.textTheme.titleLarge
                ?.copyWith(fontFeatures: AppFonts.tabular),
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(
              labelText: t('To\'lanayotgan summa'),
              suffixText: t('so\'m'),
              helperText: t('Qisman to\'lansa, qolgan qarz saqlanadi'),
              errorText: _error == null ? null : t(_error!),
            ),
          ),
        ],
      ),
    );
  }
}
