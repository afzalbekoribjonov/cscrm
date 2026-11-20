import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/payroll.dart';
import '../utils/firebase_map.dart';
import '../utils/offline_write.dart';
import 'tenant_scope.dart';

/// Maosh bo'limi hali ochilmagan (baza qoidalari yangilanmagan) yoki
/// saqlab bo'lmadi — foydalanuvchiga tushunarli xabar bilan.
class PayrollException implements Exception {
  const PayrollException(this.message, {this.unavailable = false});

  final String message;

  /// Tizim hali yangilanmagan — bo'lim umuman ishlamaydi.
  final bool unavailable;

  @override
  String toString() => message;
}

PayrollException _friendly(Object error, String action) {
  if (error is FirebaseException && error.code == 'permission-denied') {
    return const PayrollException(
      'Maosh bo\'limi tizim yangilangach ishlaydi. Birozdan keyin qayta '
      'urinib ko\'ring.',
      unavailable: true,
    );
  }
  if (error is TimeoutException) {
    return PayrollException(
        'Internet aloqasi yo\'q. $action aloqa tiklanganda saqlanadi.');
  }
  return PayrollException('$action saqlanmadi. Qayta urinib ko\'ring.');
}

/// Maosh ma'lumotlari — FAQAT biznes egasi uchun (narxlardan tashqari:
/// ularni hamma o'qiydi, qarang: [PayrollCenter]).
class PayrollService {
  PayrollService({TenantScope? scope}) : _scope = scope ?? TenantScope.current;

  final TenantScope _scope;

  Stream<T> _guard<T>(Stream<T> stream) => stream.handleError(
        (Object e) => throw _friendly(e, 'Ma\'lumot'),
        test: (e) => e is FirebaseException,
      );

  // ------------------------------------------------------------- narxlar

  Stream<PayrollRates> streamRates() => _guard(_scope
      .ref('payroll_rates')
      .onValue
      .map((e) => PayrollRates.fromMap(e.snapshot.value)));

  Future<void> saveRates(PayrollRates rates) async {
    try {
      await awaitOrFail(
        _scope.ref('payroll_rates').set({
          ...rates.toMap(),
          'updatedAt': ServerValue.timestamp,
        }),
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      throw _friendly(e, 'Narxlar');
    }
  }

  // ------------------------------------------------- xodim maosh sozlamasi

  Stream<Map<String, StaffPay>> streamStaff() =>
      _guard(_scope.ref('payroll_staff').onValue.map((e) {
        final raw = asFirebaseMap(e.snapshot.value);
        return {
          for (final entry in raw.entries)
            if (entry.value is Map) entry.key: StaffPay.fromMap(entry.value),
        };
      }));

  Future<void> saveStaff(String employeeId, StaffPay pay) async {
    try {
      await awaitOrFail(
        _scope.ref('payroll_staff/$employeeId').set({
          ...pay.toMap(),
          'updatedAt': ServerValue.timestamp,
        }),
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      throw _friendly(e, 'Maosh sozlamasi');
    }
  }

  // ---------------------------------------------------------- ish hisobi

  /// Kunlar oralig'idagi ish: kun ("20261120") → xodim → yig'indi.
  ///
  /// Kalit bo'yicha so'rov — indeks shart emas. Bir oy = 30 ta kichik
  /// yozuv, tarixdagi minglab yozuv o'rniga.
  Stream<Map<String, Map<String, WorkTally>>> streamWorkDays(
    DateTime from,
    DateTime to,
  ) =>
      _guard(_scope
          .ref('work_days')
          .orderByKey()
          .startAt(dayKey(from))
          .endAt(dayKey(to))
          .onValue
          .map((e) => parseWorkDays(e.snapshot.value)));

  // ------------------------------------------------------------ to'lovlar

  Stream<List<PayrollPayment>> streamPayments(String month) =>
      _guard(_scope
          .ref('payroll_payments')
          .orderByChild('month')
          .equalTo(month)
          .onValue
          .map((e) {
        final raw = asFirebaseMap(e.snapshot.value);
        final list = <PayrollPayment>[
          for (final entry in raw.entries)
            if (entry.value is Map)
              PayrollPayment.fromMap(entry.key, entry.value as Map),
        ]..sort((a, b) => b.at.compareTo(a.at));
        return list;
      }));

  Future<void> addPayment({
    required String employeeId,
    required double amount,
    required PaymentKind kind,
    required String month,
    String note = '',
    String byName = '',
  }) async {
    try {
      await awaitOrFail(
        _scope.ref('payroll_payments').push().set({
          'employeeId': employeeId,
          'amount': amount,
          'kind': kind.key,
          'month': month,
          'at': ServerValue.timestamp,
          if (note.trim().isNotEmpty) 'note': note.trim(),
          if (byName.isNotEmpty) 'byName': byName,
        }),
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      throw _friendly(e, 'To\'lov');
    }
  }

  Future<void> deletePayment(String id) async {
    try {
      await awaitOrFail(
        _scope.ref('payroll_payments/$id').remove(),
        timeout: const Duration(seconds: 10),
      );
    } catch (e) {
      throw _friendly(e, 'O\'chirish');
    }
  }
}

/// `work_days` snapshot'ini o'qiydi. Buzilgan yozuv o'tkazib yuboriladi.
Map<String, Map<String, WorkTally>> parseWorkDays(Object? raw) {
  final out = <String, Map<String, WorkTally>>{};
  for (final day in asFirebaseMap(raw).entries) {
    if (day.key.length != 8 || day.value is! Map) continue;
    final byEmployee = <String, WorkTally>{};
    for (final e in asFirebaseMap(day.value).entries) {
      if (e.value is! Map) continue;
      byEmployee[e.key] = WorkTally.fromMap(e.value);
    }
    out[day.key] = byEmployee;
  }
  return out;
}
