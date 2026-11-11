import 'package:cscrm/models/business_policies.dart';
import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_history_entry.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/utils/delivery_stats.dart';
import 'package:cscrm/utils/income_stats.dart';
import 'package:cscrm/utils/uz_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Ilova qonuniyatlari', () {
    test('sozlama yo\'q — standart qiymatlar (eski xatti-harakat)', () {
      final p = BusinessPolicies.fromMap(null);
      expect(p, BusinessPolicies.defaults);
      expect(p.measureBeforePackaging, isTrue);
      expect(p.measureBeforeWash, isFalse);
      expect(p.warehouseDays, 15);
    });

    test('noto\'g\'ri turdagi qiymat standartga tushadi', () {
      final p = BusinessPolicies.fromMap({
        'warehouseDays': 'yigirma',
        'addressRequired': 'ha',
        'debtAllowed': false,
      });
      expect(p.warehouseDays, 15);
      expect(p.addressRequired, isFalse);
      expect(p.debtAllowed, isFalse);
    });

    test('chegaradan tashqari kunlar qisqartiriladi', () {
      final p = BusinessPolicies.fromMap({'warehouseDays': 900, 'deadlineDays': -4});
      expect(p.warehouseDays, BusinessPolicies.warehouseDaysRange.max);
      expect(p.deadlineDays, 0);
    });

    test('saqlash va o\'qish bir xil natija beradi', () {
      const p = BusinessPolicies(
        deadlineDays: 5,
        addressRequired: true,
        warehouseDays: 20,
        partialHandoverEnabled: false,
      );
      expect(BusinessPolicies.fromMap(p.toMap()), p);
    });
  });

  group('bo\'lib topshirishdagi tushum', () {
    final day = DateTime(2026, 11, 12);
    final dayStart = day.millisecondsSinceEpoch;
    final dayEnd = DateTime(2026, 11, 12, 23, 59).millisecondsSinceEpoch;

    Order delivered(double paidNow) => Order(
          id: 1,
          customerName: '',
          customerPhone: '',
          address: '',
          deadline: null,
          deliveryType: DeliveryType.oziKeldi,
          status: OrderStatus.yetgazildi,
          createdBy: '',
          createdByName: '',
          createdAt: 0,
          items: const [],
          totalPrice: 300000,
          comments: const [],
          delivered: ActorStamp(at: dayStart + 5000, employeeId: 'e', name: 'S'),
          paymentMethod: cashPaymentLabel,
          paymentAmount: 300000,
          deliveryPaidAmount: paidNow,
          prepaidAmount: 100000,
        );

    OrderHistoryEntry partial(int at, double amount, String method) =>
        OrderHistoryEntry(
          key: 'h$at',
          orderId: 1,
          type: 'partial_delivery',
          byEmployeeId: 'e',
          byName: 'S',
          at: at,
          amount: amount,
          method: method,
        );

    test('oldindan olingan pul o\'z kunida, qoldiq topshirilgan kunda', () {
      final income = incomeForRange(
        [delivered(200000)],
        [partial(dayStart + 1000, 100000, cardPaymentLabel)],
        DateTime.fromMillisecondsSinceEpoch(dayStart),
        DateTime.fromMillisecondsSinceEpoch(dayEnd),
      );
      expect(income.total, 300000, reason: 'ikki marta sanalmaydi');
      expect(income.card, 100000);
      expect(income.cash, 200000);
      expect(income.debtPayments, 0,
          reason: 'bo\'lib topshirish — qarz to\'lovi emas');
    });

    test('boshqa kundagi bo\'lib topshirish shu kunga kirmaydi', () {
      final income = incomeForRange(
        const [],
        [partial(dayStart - 3600 * 1000, 100000, cashPaymentLabel)],
        DateTime.fromMillisecondsSinceEpoch(dayStart),
        DateTime.fromMillisecondsSinceEpoch(dayEnd),
      );
      expect(income.total, 0);
    });
  });

  group('qolgan vaqt', () {
    test('1 soat qolganda "1 kun" EMAS', () {
      expect(formatRemaining(const Duration(minutes: 59)), '59 daqiqa');
      expect(formatRemaining(const Duration(hours: 1)), '1 soat');
      expect(formatRemaining(const Duration(hours: 1, minutes: 20)),
          '1 soat 20 daqiqa');
    });

    test('kunlar va soatlar', () {
      expect(formatRemaining(const Duration(days: 2, hours: 5)), '2 kun 5 soat');
      expect(formatRemaining(const Duration(days: 3)), '3 kun');
      expect(formatRemaining(const Duration(days: 12, hours: 3)), '12 kun');
    });

    test('tugagan muddat', () {
      expect(formatRemaining(Duration.zero), '0 daqiqa');
      expect(formatRemaining(const Duration(minutes: -5)), '0 daqiqa');
      expect(formatRemaining(const Duration(seconds: 20)), '1 daqiqa');
    });
  });
}
