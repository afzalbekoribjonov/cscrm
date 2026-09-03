/// Sexning chiqimi (ijara, kimyo, yoqilg'i, ish haqi va h.k.).
///
/// Sof foyda shu chiqimlar yig'indisini daromaddan ayirish orqali
/// hisoblanadi - qarang: `IncomeActivityScreen`.
class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.spentAt,
    required this.note,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory Expense.fromMap(String id, Map<dynamic, dynamic> map) {
    return Expense(
      id: id,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      // Chiqim sanasi - haqiqiy sarflangan kun (yozilgan kun emas), shu
      // sabab kalendar filtri aynan shu maydon bo'yicha ishlaydi.
      spentAt: (map['spentAt'] as num?)?.toInt() ??
          (map['createdAt'] as num?)?.toInt() ??
          0,
      note: map['note'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final double amount;
  final int spentAt;
  final String note;
  final String createdBy;
  final String createdByName;
  final int createdAt;
}
