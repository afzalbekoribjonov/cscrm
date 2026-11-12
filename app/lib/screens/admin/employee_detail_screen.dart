import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../models/staff_access.dart';
import '../../models/staff_permission.dart';
import '../../models/work_section.dart';
import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/action_menu.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../utils/date_utils.dart';
import '../../utils/money.dart';
import '../../utils/team_stats.dart';
import '../../widgets/phone_link.dart';
import '../dashboard/dashboard_sources.dart';
import '../dashboard/employee_day_screen.dart';
import '../home/app_menu.dart';
import '../settings/widgets/settings_group.dart';
import 'employee_form_screen.dart';

/// Bitta xodimning sahifasi: bugungi ishi va vakolatlari.
///
/// Amallar (tahrirlash, faoliyat, bloklash, o'chirish) yuqori o'ngdagi
/// BITTA "⋮" menyuda — nomi va izohi bilan.
class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({
    super.key,
    required this.employee,
    this.sources,
    @visibleForTesting this.employeeStream,
  });

  final Employee employee;
  final DashboardSources? sources;

  /// Faqat sinov/rasm uchun.
  final Stream<Employee?>? employeeStream;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late final _service = EmployeeService();
  late final _employeeStream =
      widget.employeeStream ?? _service.streamEmployee(widget.employee.id);
  late final DashboardSources _src = widget.sources ?? FirebaseDashboardSources();

  StreamSubscription<Object?>? _historySub;
  StreamSubscription<Object?>? _deliveredSub;
  List<OrderHistoryEntry>? _history;
  List<Order> _delivered = const [];
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final today = startOfDay(DateTime.now());
    final end = endOfDay(today);
    _historySub = _src.history(today, end).listen(
          (v) => mounted ? setState(() => _history = v) : null,
          onError: (Object _) => mounted ? setState(() => _history = const []) : null,
        );
    _deliveredSub = _src.delivered(today, end).listen(
          (v) => mounted ? setState(() => _delivered = v) : null,
          onError: (Object _) {},
        );
  }

  @override
  void dispose() {
    _historySub?.cancel();
    _deliveredSub?.cancel();
    super.dispose();
  }

  Future<void> _apply(Future<void> Function() action, String done) async {
    setState(() => _saving = true);
    try {
      await action();
      if (mounted) showResult(context, done);
    } catch (e) {
      if (mounted) {
        showResult(
          context,
          e is EmployeeServiceException ? e.message : 'Saqlab bo\'lmadi. Qayta urinib ko\'ring.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleActive(Employee e) async {
    if (e.active) {
      final ok = await confirmAction(
        context,
        title: 'Xodimni bloklash',
        message: '${e.fullName} tizimdan darhol chiqariladi va qayta kira '
            'olmaydi. Keyin yana faollashtirish mumkin.',
        confirmLabel: 'Bloklash',
        destructive: true,
        icon: Icons.block_rounded,
      );
      if (!ok) return;
    }
    await _apply(() => _service.setActive(e.id, !e.active),
        e.active ? 'Xodim bloklandi' : 'Xodim faollashtirildi');
  }

  Future<void> _delete(Employee e) async {
    final ok = await confirmAction(
      context,
      title: 'Xodimni o\'chirish',
      message: '${e.fullName} butunlay o\'chiriladi va tizimga kira olmaydi. '
          'Bu amalni ortga qaytarib bo\'lmaydi.',
      confirmLabel: 'O\'chirish',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.deleteEmployee(e.id);
      if (!mounted) return;
      showResult(context, '${e.fullName} o\'chirildi');
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => _saving = false);
        showResult(
          context,
          err is EmployeeServiceException
              ? err.message
              : 'O\'chirib bo\'lmadi. Qayta urinib ko\'ring.',
          error: true,
        );
      }
    }
  }

  void _openMenu(Employee e) {
    showActionMenu(
      context,
      title: e.fullName,
      groups: [
        MenuGroup(actions: [
          MenuAction(
            icon: Icons.edit_outlined,
            label: 'Ma\'lumotlarni tahrirlash',
            subtitle: 'Ism, familiya va PIN-kod',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EmployeeFormScreen(employee: e),
            )),
          ),
          MenuAction(
            icon: Icons.event_note_outlined,
            label: 'Faoliyatini ko\'rish',
            subtitle: 'Istalgan kundagi ishi',
            tone: StageTone.info,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EmployeeDayScreen(
                employees: [e],
                user: const AppUser(
                  id: 'owner',
                  name: '',
                  access: StaffAccess.admin(),
                ),
                initialEmployeeId: e.id,
                sources: _src,
              ),
            )),
          ),
        ]),
        MenuGroup(actions: [
          MenuAction(
            icon: e.active ? Icons.block_rounded : Icons.check_circle_outline_rounded,
            label: e.active ? 'Bloklash' : 'Faollashtirish',
            subtitle: e.active
                ? 'Vaqtincha tizimga kira olmaydi'
                : 'Yana tizimga kira oladi',
            tone: e.active ? StageTone.warning : StageTone.success,
            onTap: () => _toggleActive(e),
          ),
          MenuAction(
            icon: Icons.delete_outline_rounded,
            label: 'Xodimni o\'chirish',
            destructive: true,
            onTap: () => _delete(e),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Employee?>(
      stream: _employeeStream,
      initialData: widget.employee,
      builder: (context, snap) {
        final e = snap.data;
        if (e == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Xodim')),
            body: const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Bu xodim o\'chirilgan',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(e.fullName.isEmpty ? 'Xodim' : e.fullName),
            actions: [
              MoreButton(onPressed: () => _openMenu(e)),
              const SizedBox(width: 4),
            ],
            bottom: _saving
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: _body(e),
        );
      },
    );
  }

  Widget _body(Employee e) {
    final theme = Theme.of(context);
    final history = _history;
    final work = history == null
        ? null
        : teamWork(
            history: history,
            delivered: _delivered,
            start: startOfDay(DateTime.now()),
            end: endOfDay(DateTime.now()),
            names: {e.id: e.fullName},
          ).where((w) => w.id == e.id).firstOrNull;

    return ListView(
      padding: EdgeInsets.fromLTRB(
          Gap.page, 4, Gap.page, 32 + MediaQuery.of(context).padding.bottom),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              UserAvatar(initials: initialsOf(e.fullName), size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.fullName, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    PhoneLink(phone: e.phone, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 6),
                    TonePill(
                      label: e.active ? 'Faol' : 'Bloklangan',
                      tone: e.active ? StageTone.success : StageTone.danger,
                      dot: true,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Bugungi ish',
          actionLabel: 'Boshqa kunlar',
          onAction: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EmployeeDayScreen(
              employees: [e],
              user: const AppUser(id: 'owner', name: '', access: StaffAccess.admin()),
              initialEmployeeId: e.id,
              sources: _src,
            ),
          )),
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: history == null
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : work == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Bugun hali ish belgilanmagan',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: context.colorTextSecondary)),
                    )
                  : Column(
                      children: [
                        if (!work.washed.isEmpty)
                          InfoRow(
                              icon: Icons.local_laundry_service_outlined,
                              label: 'Yuvdi',
                              value: work.washed.label()),
                        if (!work.packaged.isEmpty)
                          InfoRow(
                              icon: Icons.inventory_2_outlined,
                              label: 'Qadoqladi',
                              value: '${work.packaged.items} ta'),
                        if (work.created > 0)
                          InfoRow(
                              icon: Icons.note_add_outlined,
                              label: 'Qabul qildi',
                              value: '${work.created} ta'),
                        if (work.pickedUp > 0)
                          InfoRow(
                              icon: Icons.moped_outlined,
                              label: 'Olib keldi',
                              value: '${work.pickedUp} ta'),
                        if (work.delivered > 0)
                          InfoRow(
                              icon: Icons.task_alt_rounded,
                              label: 'Topshirdi',
                              value: '${work.delivered} ta'),
                        if (work.collected > 0)
                          InfoRow(
                            icon: Icons.payments_outlined,
                            label: 'Olgan puli',
                            value: formatSom(work.collected),
                            valueColor: StageTone.success.ink(context),
                          ),
                      ],
                    ),
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          title: 'Bo\'lim vakolatlari',
          footer: 'Xodim faqat vakolat berilgan bo\'limni ochadi va faqat o\'sha '
              'bo\'lim ichidan ish qiladi. O\'zgarish darhol kuchga kiradi.',
          children: [
            for (final s in WorkSection.values)
              SettingsTile(
                icon: s.icon,
                tone: e.sections.contains(s) ? StageTone.success : StageTone.neutral,
                label: s.label,
                value: s.accessHint,
                trailing: Switch(
                  value: e.sections.contains(s),
                  onChanged: _saving
                      ? null
                      : (v) => _apply(
                            () => _service.setSectionAccess(e.id, s, v),
                            v ? '"${s.label}" vakolati berildi' : '"${s.label}" vakolati olindi',
                          ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          title: 'Qo\'shimcha vakolatlar',
          footer: 'Bo\'lim vakolatiga qo\'shimcha beriladi — masalan o\'lchash '
              'uchun ham Yuvish bo\'limi, ham "O\'lchash va narx" kerak.',
          children: [
            for (final p in StaffPermission.values)
              SettingsTile(
                icon: p.icon,
                tone: e.permissions.contains(p) ? StageTone.success : StageTone.neutral,
                label: p.label,
                value: p.hint,
                trailing: Switch(
                  value: e.permissions.contains(p),
                  onChanged: _saving
                      ? null
                      : (v) => _apply(
                            () => _service.setPermission(e.id, p, v),
                            v ? '"${p.label}" vakolati berildi' : '"${p.label}" vakolati olindi',
                          ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
