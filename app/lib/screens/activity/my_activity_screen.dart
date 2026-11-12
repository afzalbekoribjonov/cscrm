import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/employee.dart';
import '../../models/staff_access.dart';
import '../dashboard/employee_day_screen.dart';

/// "Mening faoliyatim" — xodimning o'z ishi: istalgan kunda nechta olib
/// kelgani, topshirgani, yuvgani va qo'lidagi pul.
///
/// Boshqaruvchining "Xodimlar faoliyati" sahifasi bilan BIR XIL hisob:
/// faqat o'sha kunning tarixi va topshirilgan buyurtmalari so'raladi.
/// Ilgari bu yerda ikki kunlik barcha buyurtmalar va BARCHA faol
/// buyurtmalar qayta yuklanardi.
class MyActivityScreen extends StatelessWidget {
  const MyActivityScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  Widget build(BuildContext context) {
    final parts = currentUserName.trim().split(RegExp(r'\s+'));
    return EmployeeDayScreen(
      title: 'Mening faoliyatim',
      user: AppUser(id: currentUserId, name: currentUserName, access: access),
      initialEmployeeId: currentUserId,
      employees: [
        Employee(
          id: currentUserId,
          firstName: parts.isEmpty ? '' : parts.first,
          lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
          phone: '',
          active: true,
          createdAt: 0,
          createdBy: '',
        ),
      ],
    );
  }
}
