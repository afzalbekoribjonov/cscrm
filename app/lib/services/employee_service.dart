import 'package:firebase_database/firebase_database.dart';

import '../models/employee.dart';
import '../models/staff_permission.dart';
import '../models/work_section.dart';
import '../utils/firebase_map.dart';
import 'api_client.dart';
import 'tenant_scope.dart';

class EmployeeServiceException implements Exception {
  EmployeeServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Xodimlarni boshqarish.
///
/// O'QISH bazadan to'g'ridan-to'g'ri (jonli oqim kerak), lekin PIN bilan
/// bog'liq har qanday AMAL serverdan o'tadi:
///
///  * PIN bcrypt bilan hash'lanadi — buni qurilma qila olmaydi
///  * telefon indeksi (`employee_phone_index`) mijozga berk tugun, uni
///    faqat Admin SDK yozadi
///
/// Shu sabab `createEmployee` va `setPin` HTTP orqali ishlaydi.
class EmployeeService {
  EmployeeService({TenantScope? scope, ApiClient? api})
      : _ref = (scope ?? TenantScope.current).ref('employees'),
        _api = api ?? ApiClient.instance;

  final DatabaseReference _ref;
  final ApiClient _api;

  Stream<List<Employee>> streamEmployees() {
    return _ref.onValue.map((event) {
      final raw = asFirebaseMap(event.snapshot.value);
      final employees = <Employee>[];
      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        employees.add(Employee.fromMap(entry.key, entry.value as Map));
      }
      employees.sort((a, b) =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      return employees;
    });
  }

  /// Bitta xodimni jonli kuzatadi — vakolat tugmalari bosilganda ekran
  /// darhol yangilanishi uchun.
  Stream<Employee?> streamEmployee(String id) {
    return _ref.child(id).onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return null;
      return Employee.fromMap(id, raw);
    });
  }

  /// Yangi xodim qo'shadi (server orqali).
  ///
  /// Telefon takrorlanmasligi ham SERVERDA tekshiriladi — ilovadagi
  /// tekshiruv ikki xodim bir vaqtda qo'shilganda ishlamas edi.
  Future<String> createEmployee({
    required String firstName,
    required String lastName,
    required String phone,
    required String pin,
    List<WorkSection> sections = const [],
    List<StaffPermission> permissions = const [],
  }) async {
    try {
      final response = await _api.post('/api/v1/employees', body: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'phone': phone.trim(),
        'pin': pin,
        'sections': sections.map((s) => s.key).toList(),
        'permissions': permissions.map((p) => p.key).toList(),
      });
      return response['employeeId'] as String;
    } on ApiException catch (e) {
      throw EmployeeServiceException(e.message);
    }
  }

  /// Ism/familiya/telefonni yangilaydi.
  ///
  /// PIN bu yerda O'ZGARMAYDI — buning uchun [setPin] ishlatiladi, chunki
  /// hash faqat serverda hisoblanadi.
  Future<void> updateEmployee({
    required String id,
    required String firstName,
    required String lastName,
  }) async {
    await _ref.child(id).update({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
    });
  }

  /// PIN-kodni almashtiradi (server orqali).
  Future<void> setPin({required String id, required String pin}) async {
    try {
      await _api.post('/api/v1/employees/$id/pin', body: {'pin': pin});
    } on ApiException catch (e) {
      throw EmployeeServiceException(e.message);
    }
  }

  Future<void> setActive(String id, bool active) async {
    await _ref.child(id).update({'active': active});
  }

  /// Bitta bo'lim bo'yicha vakolatni beradi yoki qaytarib oladi.
  Future<void> setSectionAccess(
    String id,
    WorkSection section,
    bool granted,
  ) async {
    await _ref.child(id).update({'sections/${section.key}': granted});
  }

  /// Bo'lim vakolatidan tashqari beriladigan qo'shimcha huquqni yoqadi
  /// yoki bekor qiladi.
  Future<void> setPermission(
    String id,
    StaffPermission permission,
    bool granted,
  ) async {
    await _ref.child(id).update({'permissions/${permission.key}': granted});
  }

  /// Xodimni o'chiradi (server orqali — telefon indeksi ham tozalanadi).
  Future<void> deleteEmployee(String id) async {
    try {
      await _api.delete('/api/v1/employees/$id');
    } on ApiException catch (e) {
      throw EmployeeServiceException(e.message);
    }
  }
}
