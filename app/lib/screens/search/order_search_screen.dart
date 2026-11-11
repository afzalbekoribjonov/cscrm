import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../l10n/transliterate.dart';
import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../models/work_section.dart';
import '../../services/order_service.dart';
import '../../services/policy_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/date_utils.dart';
import '../../utils/order_sections.dart';
import '../../utils/phone.dart';
import '../../widgets/order_card.dart';
import '../../widgets/stage_visuals.dart';

enum _DeadlineFilter {
  any('Har qanday muddat'),
  overdue('Muddati o\'tgan'),
  today('Bugun'),
  tomorrow('Ertaga'),
  week('Shu hafta');

  const _DeadlineFilter(this.label);
  final String label;
}

enum _Sort {
  deadline('Muddat bo\'yicha'),
  newest('Avval yangilari'),
  oldest('Avval eskilari');

  const _Sort(this.label);
  final String label;
}

/// Buyurtma qidiruvi — filtrlar bilan.
///
/// Bitta maydonda hammasi: buyurtma raqami (№), telefon, mijoz ismi,
/// manzil yoki xizmat nomi. Lotin va kirill bir xil topiladi. Pastdagi
/// filtrlar holat va muddat bo'yicha toraytiradi.
///
/// Faol buyurtmalar qurilmada bor — ular darhol, internetsiz topiladi.
/// Topshirilgan (eski) buyurtma esa faqat ANIQ raqam yoki to'liq
/// telefon bo'yicha bazadan so'raladi: butun tarixni yuklash shart emas.
class OrderSearchScreen extends StatefulWidget {
  const OrderSearchScreen({
    super.key,
    required this.sections,
    required this.user,
    this.section,
  });

  final OrderSections sections;
  final AppUser user;
  final WorkSection? section;

  @override
  State<OrderSearchScreen> createState() => _OrderSearchScreenState();
}

class _OrderSearchScreenState extends State<OrderSearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  OrderPlace? _place;
  var _deadline = _DeadlineFilter.any;
  var _sort = _Sort.deadline;

  List<Order> _remote = const [];
  var _remoteBusy = false;
  String _remoteFor = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQuery(String _) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _searchRemote);
  }

  /// Bazadan qidirish — faqat aniq raqam yoki to'liq telefon bo'yicha.
  Future<void> _searchRemote() async {
    final q = _ctrl.text.trim();
    final digits = digitsOnly(q);
    final stripped = q.replaceAll(RegExp(r'[\s+№#]'), '');
    final isDigits = stripped.isNotEmpty && digits.length == stripped.length;
    if (!isDigits || q == _remoteFor) return;
    _remoteFor = q;

    final service = OrderService();
    final local = {for (final o in widget.sections.all) o.id};
    setState(() => _remoteBusy = true);
    try {
      final found = <Order>[];
      final id = int.tryParse(digits);
      if (id != null && digits.length <= 7 && !local.contains(id)) {
        final o = await service.fetchOrder(id);
        if (o != null) found.add(o);
      }
      if (digits.length >= 9) {
        found.addAll(await service.ordersOfCustomer(
          digits,
          indexReady: PolicyCenter.instance.serverReady.value,
        ));
      }
      if (!mounted || _remoteFor != q) return;
      setState(() => _remote = [
            for (final o in found)
              if (!local.contains(o.id)) o,
          ]);
    } catch (_) {
      if (mounted) setState(() => _remote = const []);
    } finally {
      if (mounted) setState(() => _remoteBusy = false);
    }
  }

  bool _matches(Order o, String q) {
    if (q.isEmpty) return true;
    final digits = digitsOnly(q);
    final onlyDigits = digits.isNotEmpty &&
        digits.length == q.replaceAll(RegExp(r'[\s+№#]'), '').length;
    if (onlyDigits) {
      if ('${o.id}' == digits || '${o.id}'.startsWith(digits)) return true;
      return digits.length >= 4 && digitsOnly(o.customerPhone).contains(digits);
    }
    final key = searchKey(q);
    final haystack = searchKey([
      o.customerName,
      o.address,
      for (final i in o.items) i.productName,
    ].join(' '));
    return key.split(' ').every(haystack.contains);
  }

  bool _deadlineOk(Order o, DateTime now) {
    if (_deadline == _DeadlineFilter.any) return true;
    final d = o.deadline;
    if (d == null) return false;
    final day = startOfDay(DateTime.fromMillisecondsSinceEpoch(d));
    final today = startOfDay(now);
    final diff = day.difference(today).inDays;
    return switch (_deadline) {
      _DeadlineFilter.overdue => diff < 0,
      _DeadlineFilter.today => diff == 0,
      _DeadlineFilter.tomorrow => diff == 1,
      _DeadlineFilter.week => diff >= 0 && diff <= 6,
      _DeadlineFilter.any => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final policies = widget.sections.policies;
    final q = _ctrl.text.trim();

    OrderPlace place(Order o) => placeOf(o, policies, now);

    final all = [...widget.sections.all, ..._remote];
    final results = all
        .where((o) => _matches(o, q))
        .where((o) => _place == null || place(o) == _place)
        .where((o) => _deadlineOk(o, now))
        .toList();
    switch (_sort) {
      case _Sort.deadline:
        results.sort((a, b) {
          final ad = a.deadline ?? 1 << 62;
          final bd = b.deadline ?? 1 << 62;
          return ad != bd ? ad.compareTo(bd) : b.id.compareTo(a.id);
        });
      case _Sort.newest:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _Sort.oldest:
        results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final counts = <OrderPlace, int>{};
    for (final o in widget.sections.all) {
      final p = place(o);
      counts[p] = (counts[p] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: t('№, telefon, ism, manzil yoki xizmat'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t('Tozalash'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _ctrl.clear();
                        _onQuery('');
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              children: [
                _chip(
                  label: 'Hammasi',
                  count: widget.sections.all.length,
                  selected: _place == null,
                  onTap: () => setState(() => _place = null),
                ),
                for (final p in OrderPlace.values)
                  if (p != OrderPlace.delivered || counts.containsKey(p))
                    _chip(
                      label: placeVisual(p).label,
                      icon: placeVisual(p).icon,
                      tone: placeVisual(p).tone,
                      count: counts[p] ?? 0,
                      selected: _place == p,
                      onTap: () => setState(() => _place = _place == p ? null : p),
                    ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 4, Gap.page, 4),
            child: Row(
              children: [
                Expanded(
                  child: _MenuChip<_DeadlineFilter>(
                    icon: Icons.event_outlined,
                    value: _deadline,
                    values: _DeadlineFilter.values,
                    labelOf: (v) => v.label,
                    active: _deadline != _DeadlineFilter.any,
                    onChanged: (v) => setState(() => _deadline = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MenuChip<_Sort>(
                    icon: Icons.sort_rounded,
                    value: _sort,
                    values: _Sort.values,
                    labelOf: (v) => v.label,
                    active: false,
                    onChanged: (v) => setState(() => _sort = v),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 6, Gap.page, 2),
            child: Row(
              children: [
                Text(
                  results.isEmpty ? 'Topilmadi' : '${results.length} ta buyurtma',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: context.colorTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_remoteBusy) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text('arxivdan qidirilmoqda', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? EmptyState(
                    icon: Icons.manage_search_rounded,
                    title: 'Buyurtma topilmadi',
                    message: q.isEmpty
                        ? 'Filtrni o\'zgartirib ko\'ring.'
                        : 'Topshirilgan eski buyurtmani topish uchun uning '
                            'raqamini yoki mijozning to\'liq telefon raqamini '
                            'kiriting.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(Gap.page, 6, Gap.page,
                        24 + MediaQuery.of(context).padding.bottom),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => OrderCard(
                      order: results[i],
                      user: widget.user,
                      section: widget.section,
                      place: place(results[i]),
                      showPrice: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    StageTone tone = StageTone.brand,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        avatar: icon == null
            ? null
            : Icon(icon, size: 16, color: tone.ink(context)),
        label: Text('$label · $count'),
      ),
    );
  }
}

/// Bosilganda variantlar ro'yxati chiqadigan ixcham tugma.
class _MenuChip<T> extends StatelessWidget {
  const _MenuChip({
    required this.icon,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.active,
    required this.onChanged,
  });

  final IconData icon;
  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final bool active;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = active ? context.colorPrimaryInk : context.colorTextPrimary;
    return PopupMenuButton<T>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final v in values)
          PopupMenuItem(value: v, child: Text(labelOf(v))),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? context.colorPrimarySoft : context.colorSurface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: context.colorBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                labelOf(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: ink),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: ink),
          ],
        ),
      ),
    );
  }
}
