import '../models/order.dart';
import '../models/order_history_entry.dart';
import 'date_utils.dart';
import 'delivery_stats.dart';

/// Davr bo'yicha PUL KIRIMI.
///
/// Asosiy qoida: pul QAYSI KUNI OLINGAN bo'lsa, o'sha kunning daromadi.
///
/// Ilgari hisob boshqacha edi — buyurtmaning jamlanma `paymentAmount`i
/// yetkazilgan kunga yozilardi. Qarz keyin to'lansa, o'sha summa ham
/// yetkazilgan kunga qo'shilib ketardi:
///
///  * qarz to'langan kunning daromadi NOL ko'rinardi;
///  * ancha oldin yopilgan kunning daromadi o'z-o'zidan o'sib borardi;
///  * qarz naqd to'lansa ham, buyurtma karta bilan yopilgan bo'lsa,
///    pul "karta" ustuniga tushardi.
///
/// Endi ikki manba alohida qo'shiladi:
///  * yetkazishda olingan pul — yetkazilgan sanaga;
///  * qarz to'lovlari — to'langan sanaga, o'z usuli bilan.
class IncomeStats {
  const IncomeStats({
    required this.cash,
    required this.card,
    required this.other,
    required this.debtPayments,
  });

  static const empty =
      IncomeStats(cash: 0, card: 0, other: 0, debtPayments: 0);

  final double cash;
  final double card;

  /// Naqd ham, karta ham bo'lmagan usul bilan olingan pul.
  ///
  /// Ataylab alohida: ilgari bunday pul hech qaysi ustunga tushmay,
  /// jami daromaddan JIM yo'qolardi.
  final double other;

  /// Shu davrda qarz hisobiga tushgan pul (yuqoridagilar ichida).
  final double debtPayments;

  double get total => cash + card + other;
}

IncomeStats incomeForRange(
  List<Order> orders,
  List<OrderHistoryEntry> history,
  DateTime start,
  DateTime end,
) {
  var cash = 0.0;
  var card = 0.0;
  var other = 0.0;
  var debtPayments = 0.0;

  void add(String? method, double amount) {
    if (amount <= 0) return;
    if (method == cashPaymentLabel) {
      cash += amount;
    } else if (method == cardPaymentLabel) {
      card += amount;
    } else {
      other += amount;
    }
  }

  // 1) Yetkazishda olingan pul.
  for (final order in orders) {
    final at = order.deliveredAt;
    if (at == null || !isWithinRange(at, start, end)) continue;
    add(order.paymentMethod, order.paidAtDelivery);
  }

  // 2) Qarz to'lovlari — o'z sanasi va o'z usuli bilan.
  for (final entry in history) {
    if (entry.type != 'debt_settled') continue;
    if (!isWithinRange(entry.at, start, end)) continue;
    final amount = entry.amount;
    if (amount == null || amount <= 0) continue;
    add(entry.method, amount);
    debtPayments += amount;
  }

  return IncomeStats(
    cash: cash,
    card: card,
    other: other,
    debtPayments: debtPayments,
  );
}
