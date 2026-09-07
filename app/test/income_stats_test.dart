import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_history_entry.dart';
import 'package:cscrm/utils/income_stats.dart';
import 'package:flutter_test/flutter_test.dart';

/// Daromad "pul QAYSI KUNI OLINGAN" bo'yicha hisoblanadi.
///
/// Ilgari buyurtmaning jamlanma `paymentAmount`i yetkazilgan kunga
/// yozilardi — qarz keyin to'lansa, o'sha pul ham o'tgan kunga qo'shilib
/// ketardi.

final dushanba = DateTime(2026, 3, 2);
final juma = DateTime(2026, 3, 6);

int ms(DateTime d) => d.millisecondsSinceEpoch;

Order order({
  int id = 1,
  required DateTime deliveredAt,
  required String method,
  required double paidAtDelivery,
  double? cumulativePaid,
}) =>
    Order.fromMap('$id', {
      'id': id,
      'customerName': 'Mijoz',
      'status': 'yetgazildi',
      'createdAt': ms(dushanba) - 86400000,
      'createdBy': 'x',
      'deliveredAt': ms(deliveredAt),
      'deliveredBy': 'x',
      'deliveredByName': 'Xodim',
      'paymentMethod': method,
      // Jamlanma summa — qarz to'langan sari o'sadi.
      'paymentAmount': cumulativePaid ?? paidAtDelivery,
      'deliveryPaidAmount': paidAtDelivery,
    });

OrderHistoryEntry debtPaid({
  required DateTime at,
  required double amount,
  required String method,
  int orderId = 1,
}) =>
    OrderHistoryEntry.fromMap('k', {
      'orderId': orderId,
      'type': 'debt_settled',
      'at': ms(at),
      'amount': amount,
      'method': method,
      'byEmployeeId': 'x',
      'byName': 'Xodim',
    });

(DateTime, DateTime) day(DateTime d) =>
    (DateTime(d.year, d.month, d.day), DateTime(d.year, d.month, d.day, 23, 59, 59));

void main() {
  test('qarz to\'lovi TO\'LANGAN kunga yoziladi', () {
    // Dushanba: 100 000 dan 60 000 olindi, 40 000 qarz qoldi.
    // Juma: qarz naqd to'landi.
    final orders = [
      order(
        deliveredAt: dushanba,
        method: 'Karta',
        paidAtDelivery: 60000,
        cumulativePaid: 100000, // qarz to'langach shunday bo'ldi
      ),
    ];
    final history = [
      debtPaid(at: juma, amount: 40000, method: 'Naqd pul'),
    ];

    final (ds, de) = day(dushanba);
    final dushanbaIncome = incomeForRange(orders, history, ds, de);
    expect(dushanbaIncome.total, 60000,
        reason: 'dushanbada faqat 60 000 olingan');
    expect(dushanbaIncome.card, 60000);

    final (js, je) = day(juma);
    final jumaIncome = incomeForRange(orders, history, js, je);
    expect(jumaIncome.total, 40000, reason: 'qarz juma kuni olingan');
    expect(jumaIncome.cash, 40000, reason: 'qarz NAQD to\'langan');
    expect(jumaIncome.debtPayments, 40000);
  });

  test('qarz to\'lovi o\'z usuliga yoziladi, buyurtmanikiga emas', () {
    final orders = [
      order(deliveredAt: dushanba, method: 'Karta', paidAtDelivery: 10000),
    ];
    final history = [
      debtPaid(at: juma, amount: 5000, method: 'Naqd pul'),
    ];

    final (js, je) = day(juma);
    final r = incomeForRange(orders, history, js, je);
    expect(r.cash, 5000);
    expect(r.card, 0, reason: 'buyurtma kartali bo\'lsa ham, qarz naqd');
  });

  test('notanish usul bilan olingan pul YO\'QOLMAYDI', () {
    // Ilgari naqd ham, karta ham bo'lmagan pul hech qaysi ustunga
    // tushmay, jamidan jim yo'qolardi.
    final orders = [
      order(deliveredAt: dushanba, method: 'Perevod', paidAtDelivery: 25000),
    ];

    final (ds, de) = day(dushanba);
    final r = incomeForRange(orders, const [], ds, de);
    expect(r.other, 25000);
    expect(r.total, 25000, reason: 'jami daromaddan tushib qolmasligi kerak');
  });

  test('davrdan tashqaridagi pul hisobga olinmaydi', () {
    final orders = [
      order(deliveredAt: juma, method: 'Naqd pul', paidAtDelivery: 70000),
    ];

    final (ds, de) = day(dushanba);
    expect(incomeForRange(orders, const [], ds, de).total, 0);
  });

  test('yetkazilmagan buyurtma daromadga tushmaydi', () {
    final open = Order.fromMap('9', {
      'id': 9,
      'customerName': 'Mijoz',
      'status': 'yuvishda',
      'createdAt': ms(dushanba),
      'createdBy': 'x',
      'paymentAmount': 50000,
      'paymentMethod': 'Naqd pul',
    });

    final (ds, de) = day(dushanba);
    expect(incomeForRange([open], const [], ds, de).total, 0);
  });

  test('summasiz eski qarz yozuvi hisobni buzmaydi', () {
    // Eski yozuvlarda summa faqat izoh matnida edi. Ularni o'qib
    // bo'lmaydi — lekin ular hisobni buzmasligi ham kerak.
    final eski = OrderHistoryEntry.fromMap('k', {
      'orderId': 1,
      'type': 'debt_settled',
      'at': ms(juma),
      'note': 'Naqd pul orqali 40000 so\'m qabul qilindi',
    });

    final (js, je) = day(juma);
    final r = incomeForRange(const [], [eski], js, je);
    expect(r.total, 0);
  });

  test('bir necha manba qo\'shiladi', () {
    final orders = [
      order(id: 1, deliveredAt: juma, method: 'Naqd pul', paidAtDelivery: 30000),
      order(id: 2, deliveredAt: juma, method: 'Karta', paidAtDelivery: 20000),
    ];
    final history = [
      debtPaid(at: juma, amount: 10000, method: 'Naqd pul', orderId: 3),
    ];

    final (js, je) = day(juma);
    final r = incomeForRange(orders, history, js, je);
    expect(r.cash, 40000);
    expect(r.card, 20000);
    expect(r.total, 60000);
  });
}
