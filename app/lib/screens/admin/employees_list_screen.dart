import 'package:flutter/material.dart';

import '../../models/employee.dart';
import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/phone_link.dart';
import 'employee_detail_screen.dart';
import 'employee_form_screen.dart';

/// Xodimlar ro'yxati. Har bir xodim kartasi bosilganda o'sha xodimning
/// shaxsiy sahifasi ochiladi - bugungi statistikasi va vakolatlari
/// (qarang: [EmployeeDetailScreen]).
class EmployeesListScreen extends StatefulWidget {
  const EmployeesListScreen({super.key});

  @override
  State<EmployeesListScreen> createState() => _EmployeesListScreenState();
}

class _EmployeesListScreenState extends State<EmployeesListScreen> {
  final _service = EmployeeService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa har bir
  // setState() ro'yxatni "waiting" holatiga qaytarib flicker qilardi.
  late final _employeesStream = _service.streamEmployees();

  Future<void> _confirmDelete(Employee employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xodimni o\'chirish'),
        content: Text(
          '${employee.fullName} butunlay o\'chiriladi va tizimga kira olmaydi. '
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
    await _service.deleteEmployee(employee.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${employee.fullName} o\'chirildi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xodimlar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmployeeFormScreen()),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Yangi xodim'),
      ),
      body: StreamBuilder<List<Employee>>(
        stream: _employeesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Xatolik: ${snapshot.error}'));
          }
          final employees = snapshot.data ?? [];
          if (employees.isEmpty) {
            return Center(
              child: Text(
                'Hali xodim qo\'shilmagan',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 96 + MediaQuery.of(context).padding.bottom),
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _EmployeeCard(
              employee: employees[index],
              onDelete: () => _confirmDelete(employees[index]),
            ),
          );
        },
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.onDelete});

  final Employee employee;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccess = employee.sections.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EmployeeDetailScreen(employee: employee),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.fullName, style: theme.textTheme.titleMedium),
                    PhoneLink(phone: employee.phone),
                    const SizedBox(height: 3),
                    Text(
                      employee.sectionsLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: hasAccess
                            ? AppColors.success
                            : context.colorTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!employee.active)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
              IconButton(
                tooltip: 'O\'chirish',
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
