import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/work_section.dart';
import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/phone.dart';
import '../../widgets/stream_error_view.dart';
import '../home/app_menu.dart';
import 'employee_detail_screen.dart';
import 'employee_form_screen.dart';

/// Xodimlar ro'yxati.
class EmployeesListScreen extends StatefulWidget {
  const EmployeesListScreen({super.key, @visibleForTesting this.employees});

  /// Faqat sinov/rasm uchun.
  final Stream<List<Employee>>? employees;

  @override
  State<EmployeesListScreen> createState() => _EmployeesListScreenState();
}

class _EmployeesListScreenState extends State<EmployeesListScreen> {
  late final _stream = widget.employees ?? EmployeeService().streamEmployees();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Xodimlar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Xodim qo\'shish'),
      ),
      body: StreamBuilder<List<Employee>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return StreamErrorView(error: snapshot.error!);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final employees = [...snapshot.data!]
            ..sort((a, b) {
              if (a.active != b.active) return a.active ? -1 : 1;
              return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
            });
          if (employees.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              tone: StageTone.brand,
              title: 'Hali xodim qo\'shilmagan',
              message: 'Xodim qo\'shib, unga kerakli bo\'limlarga vakolat '
                  'bering — u telefon raqami va PIN-kod bilan kiradi.',
            );
          }
          final active = employees.where((e) => e.active).length;
          return ListView(
            padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page,
                100 + MediaQuery.of(context).padding.bottom),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  '${employees.length} ta xodim · $active ta faol',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < employees.length; i++) ...[
                      if (i > 0) Divider(height: 1, indent: 72, color: context.colorBorder),
                      _EmployeeRow(employee: employees[i]),
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

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = [
      for (final s in WorkSection.values)
        if (employee.sections.contains(s)) s.shortLabel,
    ];
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(employee: employee),
      )),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Opacity(
              opacity: employee.active ? 1 : 0.45,
              child: UserAvatar(initials: initialsOf(employee.fullName), size: 44),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          employee.fullName.isEmpty ? 'Xodim' : employee.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      if (!employee.active) ...[
                        const SizedBox(width: 8),
                        const TonePill(
                            label: 'Bloklangan', tone: StageTone.danger, dense: true),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatPhoneForDisplay(employee.phone),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: AppFonts.tabular,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sections.isEmpty ? 'Bo\'lim vakolati yo\'q' : sections.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: sections.isEmpty
                          ? StageTone.warning.ink(context)
                          : context.colorTextSecondary,
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
