import 'package:cscrm/models/item_status.dart';
import 'package:cscrm/utils/order_totals.dart';
import 'package:flutter_test/flutter_test.dart';

/// Buyurtma hisob-kitoblari — pul bilan bog'liq bo'lgani uchun alohida
/// tekshiriladi. Bu funksiyalar tranzaksiya ichida, serverdagi joriy
/// holat ustida ishlaydi.

Map<String, dynamic> item({
  double price = 0,
  String status = 'yuvilmoqda',
}) =>
    {'price': price, 'status': status};

void main() {
  group('sumItemPrices', () {
    test('bo\'sh buyurtmada 0', () {
      expect(sumItemPrices({}), 0);
    });

    test('xizmatlar narxini qo\'shadi', () {
      final items = {
        '1': item(price: 50000),
        '2': item(price: 30000),
        '3': item(price: 20000),
      };
      expect(sumItemPrices(items), 100000);
    });

    test('narxi yo\'q xizmat 0 deb hisoblanadi', () {
      final items = {
        '1': item(price: 50000),
        '2': <String, dynamic>{'status': 'yuvilmoqda'},
      };
      expect(sumItemPrices(items), 50000);
    });

    test('buzilgan yozuv butun summani yo\'qotmaydi', () {
      final items = <String, dynamic>{
        '1': item(price: 50000),
        '2': 'buzilgan',
        '3': item(price: 25000),
      };
      expect(sumItemPrices(items), 75000);
    });

    test('butun son ham, kasr son ham qabul qilinadi', () {
      final items = <String, dynamic>{
        '1': {'price': 1000},
        '2': {'price': 1500.5},
      };
      expect(sumItemPrices(items), 2500.5);
    });
  });

  group('allItemsReady', () {
    test('bo\'sh buyurtma tayyor emas', () {
      expect(
        allItemsReady({}),
        isFalse,
        reason:
            'xizmati kiritilmagan buyurtma yetgazishga tayyor bo\'lmasligi kerak',
      );
    });

    test('barcha xizmat tayyor bo\'lsa true', () {
      final items = {
        '1': item(status: ItemStatus.tayyor.key),
        '2': item(status: ItemStatus.tayyor.key),
      };
      expect(allItemsReady(items), isTrue);
    });

    test('bittasi tayyor bo\'lmasa false', () {
      final items = {
        '1': item(status: ItemStatus.tayyor.key),
        '2': item(status: ItemStatus.yuvilmoqda.key),
      };
      expect(allItemsReady(items), isFalse);
    });
  });

  group('applyDebtPayment', () {
    test('qisman to\'lov qarzni kamaytiradi', () {
      final r = applyDebtPayment(
        currentDebt: 100000,
        currentPaid: 50000,
        amount: 30000,
      );
      expect(r.applied, 30000);
      expect(r.remainingDebt, 70000);
      expect(r.totalPaid, 80000);
      expect(r.fullySettled, isFalse);
    });

    test('to\'liq to\'lov qarzni yopadi', () {
      final r = applyDebtPayment(
        currentDebt: 100000,
        currentPaid: 0,
        amount: 100000,
      );
      expect(r.remainingDebt, 0);
      expect(r.fullySettled, isTrue);
    });

    test('qarzdan ORTIQ to\'lov qirqiladi — qarz manfiy bo\'lmaydi', () {
      final r = applyDebtPayment(
        currentDebt: 40000,
        currentPaid: 60000,
        amount: 100000,
      );
      expect(r.applied, 40000, reason: 'faqat haqiqiy qarz hisobga olinadi');
      expect(r.remainingDebt, 0);
      expect(
        r.totalPaid,
        100000,
        reason: 'to\'langan summa buyurtma narxidan oshib ketmasligi kerak',
      );
    });

    test('ikki xodim bir vaqtda yopsa, ikkinchisi ortiqcha yozmaydi', () {
      // Birinchi xodim to'liq yopdi.
      final first = applyDebtPayment(
        currentDebt: 50000,
        currentPaid: 0,
        amount: 50000,
      );
      expect(first.remainingDebt, 0);

      // Ikkinchi xodim ham 50 000 kiritdi, lekin server holati allaqachon 0.
      final second = applyDebtPayment(
        currentDebt: first.remainingDebt,
        currentPaid: first.totalPaid,
        amount: 50000,
      );
      expect(second.applied, 0, reason: 'ikkinchi to\'lov hisobga olinmaydi');
      expect(
        second.totalPaid,
        50000,
        reason: 'jami to\'lov ikkilanmasligi kerak',
      );
    });

    test('manfiy summa e\'tiborga olinmaydi', () {
      final r = applyDebtPayment(
        currentDebt: 50000,
        currentPaid: 10000,
        amount: -30000,
      );
      expect(r.applied, 0);
      expect(r.remainingDebt, 50000);
      expect(r.totalPaid, 10000);
    });
  });

  group('splitDeliveryPayment', () {
    test('to\'liq to\'lov - qarz ham, skidka ham yo\'q', () {
      final r = splitDeliveryPayment(
        orderTotal: 100000,
        paid: 100000,
        shortfallIsDiscount: false,
      );
      expect(r.paid, 100000);
      expect(r.debt, 0);
      expect(r.discount, 0);
    });

    test('kam to\'lov qarz sifatida yoziladi', () {
      final r = splitDeliveryPayment(
        orderTotal: 100000,
        paid: 60000,
        shortfallIsDiscount: false,
      );
      expect(r.paid, 60000);
      expect(r.debt, 40000);
      expect(r.discount, 0);
    });

    test('kam to\'lov skidka sifatida ham yozilishi mumkin', () {
      final r = splitDeliveryPayment(
        orderTotal: 100000,
        paid: 60000,
        shortfallIsDiscount: true,
      );
      expect(r.debt, 0);
      expect(r.discount, 40000);
    });

    test('OYNA OCHIQ TURGANDA narx oshsa, farq yo\'qolmaydi', () {
      // Dastavchik oynani 100 000 so'm bilan ochdi va shuni oldi. Shu payt
      // sexdagi xodim yangi xizmat qo'shdi - narx 150 000 bo'lib qoldi.
      final r = splitDeliveryPayment(
        orderTotal: 150000, // serverdagi JORIY narx
        paid: 100000,
        shortfallIsDiscount: false,
      );
      expect(
        r.debt,
        50000,
        reason: 'qo\'shilgan xizmat puli qarz sifatida qayd etilishi kerak',
      );
      expect(r.paid + r.debt + r.discount, 150000);
    });

    test('narx noma\'lum bo\'lsa farq hisoblanmaydi', () {
      final r = splitDeliveryPayment(
        orderTotal: 0,
        paid: 50000,
        shortfallIsDiscount: false,
      );
      expect(r.paid, 50000);
      expect(r.debt, 0);
      expect(r.discount, 0);
    });

    test('ortiqcha to\'lov narx bilan chegaralanadi', () {
      final r = splitDeliveryPayment(
        orderTotal: 100000,
        paid: 130000,
        shortfallIsDiscount: false,
      );
      expect(r.paid, 100000);
      expect(r.debt, 0);
    });

    test('taqsimot har doim narxga teng bo\'ladi', () {
      const amounts = [0.0, 25000.0, 99999.0, 100000.0];
      for (final paid in amounts) {
        for (final asDiscount in [true, false]) {
          final r = splitDeliveryPayment(
            orderTotal: 100000,
            paid: paid,
            shortfallIsDiscount: asDiscount,
          );
          expect(
            r.paid + r.debt + r.discount,
            100000,
            reason: 'paid=$paid, skidka=$asDiscount',
          );
        }
      }
    });
  });
}
