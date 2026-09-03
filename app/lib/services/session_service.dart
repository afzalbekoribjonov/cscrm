import 'package:shared_preferences/shared_preferences.dart';

import '../models/staff_access.dart';

enum SessionRole { none, employee, owner }

class Session {
  const Session.none()
      : role = SessionRole.none,
        tenantId = null,
        tenantName = null,
        userId = null,
        displayName = null,
        employeeId = null,
        access = const StaffAccess.none();

  const Session.employee({
    required this.tenantId,
    required this.tenantName,
    required this.userId,
    required this.employeeId,
    required this.displayName,
    required this.access,
  }) : role = SessionRole.employee;

  const Session.owner({
    required this.tenantId,
    required this.tenantName,
    required this.userId,
    required this.displayName,
  })  : role = SessionRole.owner,
        employeeId = null,
        access = const StaffAccess.admin();

  final SessionRole role;

  /// Qaysi biznesga tegishli. Kirilmagan bo'lsa `null`.
  final String? tenantId;
  final String? tenantName;

  /// Firebase UID.
  final String? userId;
  final String? displayName;

  /// Xodim uchun `/employees/{id}` kaliti.
  final String? employeeId;

  /// Bo'limlar bo'yicha vakolatlar.
  ///
  /// DIQQAT: bu qurilmada saqlangan NUSXA. Boshqaruvchi vakolatni
  /// o'zgartirsa, xodim qayta kirmaguncha eski qiymat qoladi. Shu sabab
  /// vakolat FAQAT ko'rinishni boshqaradi — haqiqiy cheklov Database
  /// qoidalarida va serverda.
  final StaffAccess access;

  bool get isSignedIn => role != SessionRole.none;
  bool get isOwner => role == SessionRole.owner;

  /// Buyurtma tarixida "kim qildi" deb yoziladigan ID.
  String get actorId => employeeId ?? userId ?? '';
}

/// Sessiyani qurilmada saqlaydi — ilova qayta ochilganda chiqmaguncha
/// login talab qilinmasligi shu orqali ta'minlanadi.
class SessionService {
  static const _kRole = 'session_role';
  static const _kTenantId = 'session_tenant_id';
  static const _kTenantName = 'session_tenant_name';
  static const _kUserId = 'session_user_id';
  static const _kDisplayName = 'session_display_name';
  static const _kEmployeeId = 'session_employee_id';
  static const _kSections = 'session_sections';
  static const _kPermissions = 'session_permissions';

  Future<Session> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString(_kRole);
    final tenantId = prefs.getString(_kTenantId);

    // Tenant yo'q bo'lsa sessiya yaroqsiz — eski (ijarachiliksiz)
    // versiyadan qolgan yozuv ham shu yerda tushib qoladi.
    if (tenantId == null) return const Session.none();

    switch (role) {
      case 'owner':
        return Session.owner(
          tenantId: tenantId,
          tenantName: prefs.getString(_kTenantName) ?? '',
          userId: prefs.getString(_kUserId) ?? '',
          displayName: prefs.getString(_kDisplayName) ?? '',
        );
      case 'employee':
        final employeeId = prefs.getString(_kEmployeeId);
        if (employeeId == null) return const Session.none();
        return Session.employee(
          tenantId: tenantId,
          tenantName: prefs.getString(_kTenantName) ?? '',
          userId: prefs.getString(_kUserId) ?? '',
          employeeId: employeeId,
          displayName: prefs.getString(_kDisplayName) ?? '',
          access: StaffAccess.fromKeys(
            prefs.getStringList(_kSections) ?? const [],
            permissionKeys: prefs.getStringList(_kPermissions) ?? const [],
          ),
        );
      default:
        return const Session.none();
    }
  }

  Future<void> save(Session session) async {
    final prefs = await SharedPreferences.getInstance();
    if (!session.isSignedIn || session.tenantId == null) {
      await clearSession();
      return;
    }

    await prefs.setString(
      _kRole,
      session.role == SessionRole.owner ? 'owner' : 'employee',
    );
    await prefs.setString(_kTenantId, session.tenantId!);
    await prefs.setString(_kTenantName, session.tenantName ?? '');
    await prefs.setString(_kUserId, session.userId ?? '');
    await prefs.setString(_kDisplayName, session.displayName ?? '');

    if (session.role == SessionRole.employee) {
      await prefs.setString(_kEmployeeId, session.employeeId ?? '');
      await prefs.setStringList(_kSections, session.access.sectionKeys);
      await prefs.setStringList(_kPermissions, session.access.permissionKeys);
    } else {
      await prefs.remove(_kEmployeeId);
      await prefs.remove(_kSections);
      await prefs.remove(_kPermissions);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kRole,
      _kTenantId,
      _kTenantName,
      _kUserId,
      _kDisplayName,
      _kEmployeeId,
      _kSections,
      _kPermissions,
    ]) {
      await prefs.remove(key);
    }
  }
}
