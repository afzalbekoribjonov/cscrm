import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../models/item_status.dart';
import '../../models/order.dart';
import '../../models/order_history_entry.dart';
import '../../models/staff_permission.dart';
import '../../models/work_section.dart';
import '../../services/employee_service.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../utils/delivery_stats.dart';
import '../../widgets/item_measurement_form.dart' show fmtSom;
import '../../widgets/phone_link.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/stream_error_view.dart';
import 'employee_form_screen.dart';

/// Xodimning bugungi ish natijalari - o'zgarishlar tarixidan hisoblanadi.
class _TodayStats {
  const _TodayStats({
    required this.created,
    required this.washed,
    required this.packaged,
    required this.rewashed,
    required this.delivery,
  });

  final int created;
  final int washed;
  final int packaged;
  final int rewashed;
  final DeliveryStats delivery;
}

_TodayStats _computeToday(
  List<Order> orders,
  List<OrderHistoryEntry> history,
  String employeeId,
) {
  final start = startOfDay(DateTime.now());
  final end = endOfDay(DateTime.now());
  var created = 0;
  var washed = 0;
  var packaged = 0;
  var rewashed = 0;

  for (final order in orders) {
    if (order.createdBy == employeeId &&
        isWithinRange(order.createdAt, start, end)) {
      created++;
    }
  }

  // Xizmat bosqichlari tarixdan sanaladi — tarix endi alohida tugunda
  // va davr bo'yicha alohida so'raladi.
  for (final h in history) {
    if (h.byEmployeeId != employeeId || !isWithinRange(h.at, start, end)) {
      continue;
    }
    if (h.type != 'item_status_changed') continue;
    if (h.toStatus == ItemStatus.qadoqlashda.key) {
      washed++;
    } else if (h.toStatus == ItemStatus.tayyor.key) {
      packaged++;
    } else if (h.toStatus == ItemStatus.qaytaYuvildi.key) {
      rewashed++;
    }
  }

  return _TodayStats(
    created: created,
    washed: washed,
    packaged: packaged,
    rewashed: rewashed,
    delivery: deliveryStatsForEmployee(orders, employeeId, DateTime.now()),
  );
}

/// Bitta xodimning sahifasi: bugungi statistikasi (faqat vakolatiga mos
/// ko'rsatkichlar) va vakolatlarni yoqib-o'chirish tugmalari.
class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.employee});

  final Employee employee;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final _employeeService = EmployeeService();
  late final _employeeStream =
      _employeeService.streamEmployee(widget.employee.id);
  // Ekran faqat BUGUNGI ko'rsatkichni ko'rsatadi. Buyurtmalar va tarix
  // birga keladi - ular bir-biriga mos bo'lishi kerak.
  late final _reportStream = OrderService().streamReport(
    startOfDay(DateTime.now()),
    endOfDay(DateTime.now()),
  );
  bool _saving = false;

  Future<void> _toggleSection(Employee employee, WorkSection section) async {
    final granted = !employee.sections.contains(section);
    await _apply(
      () => _employeeService.setSectionAccess(employee.id, section, granted),
      section.label,
      granted,
    );
  }

  Future<void> _togglePermission(
      Employee employee, StaffPermission permission) async {
    final granted = !employee.permissions.contains(permission);
    await _apply(
      () => _employeeService.setPermission(employee.id, permission, granted),
      permission.label,
      granted,
    );
  }

  Future<void> _apply(
      Future<void> Function() action, String label, bool granted) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? '"$label" vakolati berildi'
                : '"$label" vakolati bekor qilindi',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Employee?>(
      stream: _employeeStream,
      initialData: widget.employee,
      builder: (context, empSnap) {
        final employee = empSnap.data;
        if (employee == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Xodim')),
            body: const Center(child: Text('Bu xodim o\'chirilgan')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(employee.fullName),
            actions: [
              IconButton(
                tooltip: 'Tahrirlash',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EmployeeFormScreen(employee: employee),
                  ),
                ),
              ),
            ],
          ),
          body: StreamBuilder<
              ({List<Order> orders, List<OrderHistoryEntry> history})>(
            stream: _reportStream,
            builder: (context, snap) {
              if (snap.hasError) {
                return StreamErrorView(error: snap.error!);
              }
              final data = snap.data;
              final stats = _computeToday(
                data?.orders ?? const [],
                data?.history ?? const [],
                employee.id,
              );
              return _buildBody(context, employee, stats);
            },
          ),
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, Employee employee, _TodayStats stats) {
    final theme = Theme.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  child: Text(
                    employee.firstName.isEmpty
                        ? '?'
                        : employee.firstName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.fullName,
                          style: theme.textTheme.titleMedium),
                      PhoneLink(phone: employee.phone),
                    ],
                  ),
                ),
                if (!employee.active)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Nofaol',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Bugungi ish', style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Faqat vakolat berilgan bo\'limlar bo\'yicha ko\'rsatiladi.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ..._buildStatTiles(employee, stats),
        const SizedBox(height: 22),
        Text('Bo\'lim vakolatlari', style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Xodim faqat vakolat berilgan bo\'limda va faqat o\'sha bo\'lim '
          'ichidan turib ish qila oladi. O\'zgarish xodim qayta kirganda '
          'kuchga kiradi.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final section in WorkSection.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccessTile(
              icon: section.icon,
              label: section.label,
              hint: section.accessHint,
              granted: employee.sections.contains(section),
              enabled: !_saving,
              onTap: () => _toggleSection(employee, section),
            ),
          ),
        const SizedBox(height: 22),
        Text('Qo\'shimcha vakolatlar', style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Bo\'lim vakolatiga qo\'shimcha ravishda beriladi - masalan '
          'o\'lchash uchun ham Yuvish bo\'limi, ham "O\'lchash va narx" '
          'vakolati kerak.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final permission in StaffPermission.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AccessTile(
              icon: permission.icon,
              label: permission.label,
              hint: permission.hint,
              granted: employee.permissions.contains(permission),
              enabled: !_saving,
              onTap: () => _togglePermission(employee, permission),
            ),
          ),
      ],
    );
  }

  /// Statistika kartalari faqat tegishli vakolat bo'lganda ko'rsatiladi -
  /// vakolatsiz bo'limning ko'rsatkichi har doim nol bo'lgani uchun
  /// ekranni behuda to'ldirmaydi.
  List<Widget> _buildStatTiles(Employee employee, _TodayStats stats) {
    final tiles = <Widget>[];

    if (employee.sections.contains(WorkSection.yangi)) {
      tiles.add(StatTile(
        icon: Icons.note_add_rounded,
        color: AppColors.primary,
        value: '${stats.created}',
        label: 'Yaratgan buyurtma',
      ));
    }
    if (employee.sections.contains(WorkSection.yuvish)) {
      tiles.add(StatTile(
        icon: Icons.local_laundry_service_rounded,
        color: AppColors.statusWashing,
        value: '${stats.washed}',
        label: 'Yuvib qadoqlashga bergan',
      ));
    }
    if (employee.sections.contains(WorkSection.qadoqlash)) {
      tiles.add(StatTile(
        icon: Icons.inventory_2_rounded,
        color: AppColors.statusReadyDelivery,
        value: '${stats.packaged}',
        label: 'Qadoqlagan',
      ));
      tiles.add(StatTile(
        icon: Icons.replay_rounded,
        color: AppColors.danger,
        value: '${stats.rewashed}',
        label: 'Qayta yuvishga qaytargan',
      ));
    }
    if (employee.sections.contains(WorkSection.yetgazma)) {
      tiles.add(StatTile(
        icon: Icons.move_to_inbox_rounded,
        color: AppColors.statusPickup,
        value: '${stats.delivery.pickedUpCount}',
        label: 'Olib kelgan',
      ));
      tiles.add(StatTile(
        icon: Icons.local_shipping_rounded,
        color: AppColors.statusDelivered,
        value: '${stats.delivery.deliveredCount}',
        label: 'Yetkazgan',
      ));
      tiles.add(StatTile(
        icon: Icons.payments_rounded,
        color: AppColors.success,
        value: fmtSom(stats.delivery.cashTotal),
        label: 'Naqd pul',
      ));
      tiles.add(StatTile(
        icon: Icons.credit_card_rounded,
        color: AppColors.accent,
        value: fmtSom(stats.delivery.cardTotal),
        label: 'Karta orqali',
      ));
    }

    if (tiles.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorSurfaceMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Vakolat berilmagan - xodim buyurtmalarni faqat ko\'ra oladi.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }

    // Ikkitadan qatorga joylaymiz.
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 10),
              if (i + 1 < tiles.length)
                Expanded(child: tiles[i + 1])
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ));
    }
    return rows;
  }
}

class _AccessTile extends StatelessWidget {
  const _AccessTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.granted,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool granted;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = granted ? AppColors.success : context.colorTextSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: granted
              ? AppColors.success.withValues(alpha: 0.08)
              : context.colorSurfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: granted
                ? AppColors.success.withValues(alpha: 0.5)
                : context.colorBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(hint, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Switch.adaptive(
              value: granted,
              onChanged: enabled ? (_) => onTap() : null,
            ),
          ],
        ),
      ),
    );
  }
}
