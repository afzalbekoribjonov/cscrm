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

  /// Berilgan davrdagi chiqimlar — eng yangisi birinchi.
  ///
  /// DAVR SHART. Ilgari bu yerda BARCHA chiqimlar o'qilardi: "chiqimlar
  /// soni kam" degan hisob bilan. Lekin ular yillar davomida
  /// to'planadi va hech qachon o'chirilmaydi — ya'ni ekran har
  /// ochilganda yuklanadigan hajm biznes yoshi bilan birga o'sib
  /// boraveradi. Uch yildan keyin foydalanuvchi bir kunlik hisobotni
  /// ko'rish uchun uch yillik yozuvni yuklab olardi.
  ///
  /// `spentAt` indeksi qoidalarda bor, shuning uchun server faqat
  /// kerakli qismini yuboradi.
  Stream<List<Expense>> streamExpensesBetween(DateTime from, DateTime to) {
    return _ref
        .orderByChild('spentAt')
        .startAt(from.millisecondsSinceEpoch)
        .endAt(to.millisecondsSinceEpoch)
        .onValue
        .map((event) {
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
