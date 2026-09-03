import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../utils/firebase_map.dart';
import '../utils/offline_write.dart';
import 'tenant_scope.dart';

class ExpenseService {
  ExpenseService({TenantScope? scope})
      : _ref = (scope ?? TenantScope.current).ref('expenses');

  final DatabaseReference _ref;

  /// Barcha chiqimlar - eng yangisi birinchi. Filtrlash ekran tomonida
  /// (kalendar oralig'i bo'yicha) bajariladi, chunki chiqimlar soni kam
  /// va shu bilan davr almashtirilganda qayta so'rov ketmaydi.
  Stream<List<Expense>> streamExpenses() {
    return _ref.onValue.map((event) {
      final raw = asFirebaseMap(event.snapshot.value);
      final expenses = <Expense>[];
      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        try {
          expenses.add(Expense.fromMap(entry.key, entry.value as Map));
        } catch (e, st) {
          debugPrint('Chiqimni o\'qib bo\'lmadi (${entry.key}): $e\n$st');
        }
      }
      expenses.sort((a, b) => b.spentAt.compareTo(a.spentAt));
      return expenses;
    });
  }

  Future<void> addExpense({
    required String title,
    required double amount,
    required DateTime spentAt,
    required String note,
    required String createdBy,
    required String createdByName,
  }) async {
    await awaitOrQueue(_ref.push().set({
      'title': title.trim(),
      'amount': amount,
      'spentAt': spentAt.millisecondsSinceEpoch,
      'note': note.trim(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': ServerValue.timestamp,
    }));
  }

  Future<void> updateExpense({
    required String id,
    required String title,
    required double amount,
    required DateTime spentAt,
    required String note,
  }) async {
    await awaitOrQueue(_ref.child(id).update({
      'title': title.trim(),
      'amount': amount,
      'spentAt': spentAt.millisecondsSinceEpoch,
      'note': note.trim(),
    }));
  }

  Future<void> deleteExpense(String id) async {
    await awaitOrQueue(_ref.child(id).remove());
  }
}
