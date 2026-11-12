import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../ui/uz_date_picker.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../utils/team_stats.dart';
import '../../utils/uz_dates.dart';
import '../home/app_menu.dart';
import 'dashboard_sources.dart';
import '../orders/order_detail_screen.dart';
import '../orders/widgets/order_view_common.dart';

/// Xodimning ISTALGAN kundagi ishi.
///
/// Bosh sahifadagi "Jamoa" ro'yxatidan ochiladi. Kun tanlanadi — o'sha
/// kunning tarixi va topshirilgan buyurtmalari so'raladi (faqat shu bir
/// kun, butun tarix emas) va har bir xodimning ishi hisoblanadi: nechi m²
/// yuvgani, nechta qadoqlagani, olib kelgani, topshirgani, olgan puli.
class EmployeeDayScreen extends StatefulWidget {
  const EmployeeDayScreen({
    super.key,
    required this.employees,
    required this.user,
    this.initialEmployeeId,
    this.initialName,
    this.sources,
    this.title = 'Xodimlar faoliyati',
  });

  /// Xodimning o'zi ochganda — "Mening faoliyatim".
  final String title;

  final DashboardSources? sources;

  final List<Employee> employees;
  final AppUser user;
  final String? initialEmployeeId;
  final String? initialName;

  @override
  State<EmployeeDayScreen> createState() => _EmployeeDayScreenState();
}

class _EmployeeDayScreenState extends State<EmployeeDayScreen> {
  late final DashboardSources _src =
      widget.sources ?? FirebaseDashboardSources();
  late DateTime _day = startOfDay(DateTime.now());
  late String? _employeeId = widget.initialEmployeeId;

  StreamSubscription<Object?>? _historySub;
  StreamSubscription<Object?>? _ordersSub;
  List<OrderHistoryEntry>? _history;
  List<Order>? _delivered;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }

  void _load() {
    _historySub?.cancel();
    _ordersSub?.cancel();
    setState(() {
      _history = null;
      _delivered = null;
    });
    final end = endOfDay(_day);
    _historySub = _src.history(_day, end).listen(
          (v) => mounted ? setState(() => _history = v) : null,
          onError: (Object _) => mounted ? setState(() => _history = const []) : null,
        );
    _ordersSub = _src.delivered(_day, end).listen(
          (v) => mounted ? setState(() => _delivered = v) : null,
          onError: (Object _) => mounted ? setState(() => _delivered = const []) : null,
        );
  }

  void _shift(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(startOfDay(DateTime.now()))) return;
    _day = next;
    _load();
  }

  Future<void> _pickDay() async {
    final picked = await showUzDatePicker(
      context,
      title: 'Kunni tanlang',
      initial: _day,
      last: startOfDay(DateTime.now()),
      quickDays: const [QuickDay('Bugun', 0), QuickDay('Kecha', -1)],
    );
    if (picked == null) return;
    _day = startOfDay(picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _history != null && _delivered != null;
    final team = !ready
        ? const <EmployeeWork>[]
        : teamWork(
            history: _history!,
            delivered: _delivered!,
            start: _day,
            end: endOfDay(_day),
            ordersById: {for (final o in _delivered!) o.id: o},
            names: {for (final e in widget.employees) e.id: e.fullName},
          );
    final selected = team.where((w) => w.id == _employeeId).firstOrNull;
    final isToday = isSameDay(_day, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            Gap.page, 4, Gap.page, 28 + MediaQuery.of(context).padding.bottom),
        children: [
          // Kun tanlash.
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: t('Oldingi kun'),
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickDay,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            UzDates.relativeDay(_day),
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            '${UzDates.weekdays[_day.weekday - 1]}, ${UzDates.date(_day)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('Keyingi kun'),
                  onPressed: isToday ? null : () => _shift(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!ready)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (team.isEmpty)
            const SizedBox(
              height: 320,
              child: EmptyState(
                icon: Icons.event_busy_outlined,
                title: 'Bu kunda ish belgilanmagan',
                message: 'Boshqa kunni tanlab ko\'ring.',
              ),
            )
          else ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final w in team)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: w.id == (selected?.id ?? team.first.id),
                        onSelected: (_) => setState(() => _employeeId = w.id),
                        avatar: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            initialsOf(w.name),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                        label: Text(w.name.isEmpty ? 'Xodim' : w.name),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _WorkCard(work: selected ?? team.first),
            const SizedBox(height: 16),
            SectionHeader(
              title: 'Bajarilgan ishlar',
              subtitle: '${(selected ?? team.first).log.length} ta yozuv',
            ),
            _LogList(entries: (selected ?? team.first).log, user: widget.user),
          ],
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work});

  final EmployeeWork work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tiles = <Widget>[
      if (!work.washed.isEmpty)
        _Metric(
          icon: Icons.local_laundry_service_rounded,
          tone: StageTone.washing,
          value: work.washed.label(),
          label: 'Yuvdi · ${work.washed.items} ta xizmat',
        ),
      if (!work.packaged.isEmpty)
        _Metric(
          icon: Icons.inventory_2_rounded,
          tone: StageTone.packaging,
          value: work.packaged.label(),
          label: 'Qadoqladi · ${work.packaged.items} ta xizmat',
        ),
      if (work.washStarted > 0)
        _Metric(
          icon: Icons.play_circle_outline_rounded,
          tone: StageTone.queued,
          value: '${work.washStarted} ta',
          label: 'Yuvishni boshladi',
        ),
      if (work.rewashed > 0)
        _Metric(
          icon: Icons.replay_rounded,
          tone: StageTone.rewash,
          value: '${work.rewashed} ta',
          label: 'Qayta yuvishga qaytardi',
        ),
      if (work.created > 0)
        _Metric(
          icon: Icons.note_add_outlined,
          tone: StageTone.brand,
          value: '${work.created} ta',
          label: 'Buyurtma qabul qildi',
        ),
      if (work.pickedUp > 0)
        _Metric(
          icon: Icons.moped_rounded,
          tone: StageTone.pickup,
          value: '${work.pickedUp} ta',
          label: 'Mijozdan olib keldi',
        ),
      if (work.delivered > 0)
        _Metric(
          icon: Icons.task_alt_rounded,
          tone: StageTone.ready,
          value: '${work.delivered} ta',
          label: 'Mijozga topshirdi',
        ),
      if (work.partial > 0)
        _Metric(
          icon: Icons.call_split_rounded,
          tone: StageTone.almost,
          value: '${work.partial} marta',
          label: 'Bo\'lib topshirdi',
        ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(initials: initialsOf(work.name), size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  work.name.isEmpty ? 'Xodim' : work.name,
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final tile in tiles) tile,
          if (work.collected > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: StageTone.success.soft(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  InfoRow(
                    label: 'Olgan puli',
                    value: formatSom(work.collected),
                    emphasize: true,
                    valueColor: StageTone.success.ink(context),
                  ),
                  if (work.cash > 0) InfoRow(label: 'Naqd', value: formatSom(work.cash)),
                  if (work.card > 0) InfoRow(label: 'Karta', value: formatSom(work.card)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.tone,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final StageTone tone;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          IconTile(icon: icon, tone: tone, size: 38, radius: 11),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.entries, required this.user});

  final List<OrderHistoryEntry> entries;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Text('Yozuv yo\'q', style: theme.textTheme.bodySmall);
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 60, color: context.colorBorder),
            _LogRow(entry: entries[i], user: user),
          ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.user});

  final OrderHistoryEntry entry;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = historyVisual(entry);
    final volume = entry.quantity != null && entry.unit != null
        ? ' · ${formatQuantity(entry.quantity!)} ${entry.unit!.short}'
        : '';
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: entry.orderId, user: user),
      )),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            IconTile(icon: visual.icon, tone: visual.tone, size: 34, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${visual.text}$volume',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                  Text(
                    '№ ${entry.orderId} · ${UzDates.time(UzDates.fromMillis(entry.at))}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
          ],
        ),
      ),
    );
  }
}
