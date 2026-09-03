import '../utils/firebase_map.dart';
import 'staff_access.dart';
import 'staff_permission.dart';
import 'work_section.dart';

class Employee {
  const Employee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.active,
    required this.createdAt,
    required this.createdBy,
    this.sections = const {},
    this.permissions = const {},
  });

  factory Employee.fromMap(String id, Map<dynamic, dynamic> map) {
    final sections = <WorkSection>{};
    for (final entry in asFirebaseMap(map['sections']).entries) {
      if (entry.value != true) continue;
      final section = WorkSection.fromKey(entry.key);
      if (section != null) sections.add(section);
    }

    final permissions = <StaffPermission>{};
    for (final entry in asFirebaseMap(map['permissions']).entries) {
      if (entry.value != true) continue;
      final permission = StaffPermission.fromKey(entry.key);
      if (permission != null) permissions.add(permission);
    }

    return Employee(
      id: id,
      firstName: map['firstName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      active: map['active'] as bool? ?? true,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      createdBy: map['createdBy'] as String? ?? '',
      sections: sections,
      permissions: permissions,
    );
  }

  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final bool active;
  final int createdAt;
  final String createdBy;

  /// Xodim ishlashi mumkin bo'lgan bo'limlar. Bo'sh bo'lsa - xodim
  /// buyurtmalarni faqat ko'ra oladi, hech narsani o'zgartira olmaydi.
  final Set<WorkSection> sections;

  /// Bo'lim vakolatidan tashqari beriladigan qo'shimcha huquqlar
  /// (skidka, o'lchash, o'chirish va h.k.).
  final Set<StaffPermission> permissions;

  StaffAccess get access => StaffAccess(
        isAdmin: false,
        sections: sections,
        permissions: permissions,
      );

  String get fullName => '$firstName $lastName'.trim();

  /// Vakolatlar ro'yxatining qisqa matni - xodimlar ro'yxatida ko'rsatiladi.
  String get sectionsLabel {
    if (sections.isEmpty && permissions.isEmpty) return 'Vakolat berilmagan';
    final parts = WorkSection.values
        .where(sections.contains)
        .map((s) => s.label)
        .toList();
    if (parts.isEmpty) parts.add('Bo\'lim yo\'q');
    if (permissions.isNotEmpty) {
      parts.add('+${permissions.length} qo\'shimcha');
    }
    return parts.join(' · ');
  }

  /// DIQQAT: `pinHash` ATAYLAB yo'q. PIN hash'i hech qachon qurilmaga
  /// yuborilmaydi va qurilmadan yozilmaydi - u faqat serverda (bcrypt
  /// bilan) hisoblanadi va Database qoidalari uni o'qishni taqiqlaydi.
  Map<String, Object?> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'active': active,
        'createdAt': createdAt,
        'createdBy': createdBy,
        'sections': {
          for (final s in WorkSection.values) s.key: sections.contains(s),
        },
        'permissions': {
          for (final p in StaffPermission.values)
            p.key: permissions.contains(p),
        },
      };
}
