import 'package:cscrm/models/employee.dart';
import 'package:cscrm/models/measure_unit.dart';
import 'package:cscrm/models/order_history_entry.dart';
import 'package:cscrm/models/payroll.dart';
import 'package:cscrm/services/order_service.dart' show lastWasherOf;
import 'package:cscrm/services/work_ledger.dart';
import 'package:cscrm/utils/payroll_math.dart';
import 'package:cscrm/utils/unit_amounts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Maosh: narxlar, ishbayi, oylik hisob va ish hisobi yozuvlari.
///
/// Bu yerdagi xato — xodimga noto'g'ri pul degani, shuning uchun har
/// bir qoida alohida tekshiriladi.
void main() {
  const rates = PayrollRates(
    products: {
      'gilam': ProductRate(wash: 1500, pack: 500),
      'korpa': ProductRate(
          washSmall: 5000, washLarge: 9000, packSmall: 1000, packLarge: 2000),
    },
    courierPct: 5,
    dispatcherMode: DispatcherMode.percent,
    dispatcherValue: 2,
  );

  group('ishbayi narxi', () {
    test("m² xizmat: narx × hajm, so'mgacha yaxlitlanadi", () {
      expect(rates.washPay('gilam', MeasureUnit.m2, 6.5), 9750);
      expect(rates.packPay('gilam', MeasureUnit.m2, 6.5), 3250);
      expect(rates.washPay('gilam', MeasureUnit.m2, 2.333), 3500);
    });

    test('kichik/katta — o\'lchamga qarab alohida narx', () {
      expect(rates.washPay('korpa', MeasureUnit.kichik, 1), 5000);
      expect(rates.washPay('korpa', MeasureUnit.katta, 1), 9000);
      expect(rates.packPay('korpa', MeasureUnit.katta, 1), 2000);
    });

    test("o'lchanmagan yoki narxi yo'q xizmat — 0", () {
      expect(rates.washPay('gilam', null, 0), 0);
      expect(rates.washPay('gilam', MeasureUnit.m2, 0), 0);
      expect(rates.washPay('nomalum', MeasureUnit.m2, 10), 0);
    });

    test('dastavchik va dispetcher foizi', () {
      expect(rates.courierPay(1250000), 62500);
      expect(rates.dispatchPercentPay(500000), 10000);
      expect(rates.dispatchFixedPay, 0);
      const fixed = PayrollRates(
          dispatcherMode: DispatcherMode.fixed, dispatcherValue: 3000);
      expect(fixed.dispatchFixedPay, 3000);
      expect(fixed.dispatchPercentPay(500000), 0);
    });

    test('foiz 50 dan oshmaydi (tasodifiy "500" himoyasi)', () {
      final r = PayrollRates.fromMap({'courierPct': 500, 'dispatcherValue': -5});
      expect(r.courierPct, 50);
      expect(r.dispatcherValue, 0);
    });

    test('saqlash va o\'qish — bir xil natija', () {
      final back = PayrollRates.fromMap(rates.toMap());
      expect(back.washPay('korpa', MeasureUnit.katta, 1), 9000);
      expect(back.courierPct, 5);
      expect(back.dispatcherMode, DispatcherMode.percent);
    });
  });

  group('xodim ishi va oylik hisob', () {
    WorkTally tally() => WorkTally.fromMap({
          'wash': {'m2': 124.5, 'kichik': 4},
          'washN': 10,
          'washPay': 186750,
          'packN': 3,
          'packPay': 6000,
          'deliverN': 2,
          'deliverSum': 400000,
          'deliverPay': 20000,
          'createN': 5,
          'createPay': 15000,
          'dispatchN': 1,
          'dispatchPay': 4000,
          'rewashN': 1,
          'rewashPay': 9000,
        });

    test('faqat belgilangan ish turlari hisoblanadi', () {
      final w = tally();
      expect(w.piecePay({PieceKind.wash}), 186750 - 9000);
      expect(w.piecePay({PieceKind.pack}), 6000);
      expect(w.piecePay({PieceKind.courier}), 20000);
      expect(w.piecePay({PieceKind.dispatch}), 15000 + 4000);
      expect(w.allPiecePay, 186750 - 9000 + 6000 + 20000 + 19000);
    });

    test("qat'iy + ishbayi − to'lovlar = qoldiq", () {
      final row = MonthPayroll(
        employeeId: 'e1',
        name: 'Ali',
        pay: const StaffPay(
            type: SalaryType.mixed, monthly: 2000000, pieces: {PieceKind.wash}),
        work: tally(),
        payments: const [
          PayrollPayment(
              id: 'a',
              employeeId: 'e1',
              amount: 500000,
              kind: PaymentKind.advance,
              month: '2026-11',
              at: 1),
        ],
      );
      expect(row.accrued, 2000000 + 177750);
      expect(row.paid, 500000);
      expect(row.remaining, 2000000 + 177750 - 500000);
    });

    test("faqat qat'iy oylik — ishbayi qo'shilmaydi", () {
      const pay = StaffPay(
          type: SalaryType.fixed, monthly: 3000000, pieces: {PieceKind.wash});
      expect(pay.activePieces, isEmpty);
      final row = MonthPayroll(
          employeeId: 'e1', name: '', pay: pay, work: tally(), payments: const []);
      expect(row.accrued, 3000000);
    });

    test("ishbayi — oylik e'tiborga olinmaydi", () {
      const pay = StaffPay(type: SalaryType.piece, monthly: 999, pieces: {});
      expect(pay.fixedMonthly, 0);
    });

    test("qat'iy oylik kunlarga bo'linadi, kelajak kunlar hisoblanmaydi", () {
      final today = DateTime(2026, 11, 20);
      // Noyabr — 30 kun.
      expect(fixedShare(3000000, DateTime(2026, 11, 1), DateTime(2026, 11, 30),
          today: DateTime(2026, 12, 5)), 3000000);
      expect(fixedShare(3000000, DateTime(2026, 11, 20), DateTime(2026, 11, 20),
          today: today), 100000);
      // 21–30 noyabr hali kelmagan.
      expect(fixedShare(3000000, DateTime(2026, 11, 1), DateTime(2026, 11, 30),
          today: today), 2000000);
      // Ikki oy chegarasi: 31-oktabr (1/31) + 1-noyabr (1/30).
      expect(fixedShare(3100000, DateTime(2026, 10, 31), DateTime(2026, 11, 1),
          today: today), (100000 + 3100000 / 30).roundToDouble());
    });

    test('davr maoshi: faqat sozlangan va faol xodimlar', () {
      Employee e(String id, {bool active = true}) => Employee(
          id: id,
          firstName: id,
          lastName: '',
          phone: '',
          active: active,
          createdAt: 0,
          createdBy: '');
      final cost = salaryCost(
        from: DateTime(2026, 11, 20),
        to: DateTime(2026, 11, 20, 23, 59),
        staff: const {
          'e1': StaffPay(
              type: SalaryType.mixed, monthly: 3000000, pieces: {PieceKind.wash}),
          'e2': StaffPay(type: SalaryType.fixed, monthly: 3000000),
        },
        days: {
          '20261120': {
            'e1': WorkTally.fromMap({'washN': 1, 'washPay': 9000}),
            'e3': WorkTally.fromMap({'washN': 1, 'washPay': 50000}),
          },
          '20261119': {
            'e1': WorkTally.fromMap({'washN': 1, 'washPay': 7000}),
          },
        },
        employees: [e('e1'), e('e2', active: false), e('e3')],
        today: DateTime(2026, 11, 20),
      );
      // e1: 100 000 (1/30) + 9 000; e2 bloklangan; e3 sozlanmagan.
      expect(cost.fixed, 100000);
      expect(cost.piece, 9000);
    });

    test('oy ro\'yxati: o\'chirilgan xodim ishi bo\'lmasa chiqmaydi', () {
      final rows = monthPayroll(
        employees: [
          const Employee(
              id: 'e1', firstName: 'Ali', lastName: '', phone: '', active: true,
              createdAt: 0, createdBy: ''),
          const Employee(
              id: 'e2', firstName: 'Vali', lastName: '', phone: '', active: false,
              createdAt: 0, createdBy: ''),
        ],
        staff: const {},
        work: const {},
        payments: const [],
      );
      expect(rows.map((r) => r.employeeId), ['e1']);
    });
  });

  group('ish hisobi yozuvi (LedgerBatch)', () {
    const day = '20261120';

    test('yuvildi: soni, hajmi va puli — bitta yozuvda', () {
      final b = LedgerBatch()
        ..wash(const ItemCredit(
            by: 'e1', name: 'Ali', day: day, pay: 9750, unit: MeasureUnit.m2, quantity: 6.5));
      expect(b.increments, {
        'work_days/$day/e1/washN': 1,
        'work_days/$day/e1/wash/m2': 6.5,
        'work_days/$day/e1/washPay': 9750,
      });
      expect(b.names, {'work_days/$day/e1/name': 'Ali'});
    });

    test('bir odamning ikki xil ishi jamlanadi (dastavchik ham dispetcher)', () {
      final b = LedgerBatch()
        ..deliver(day, 'e3', 'Sardor', sum: 300000, pay: 15000)
        ..dispatch(day, 'e3', 'Sardor', sum: 300000, pay: 6000)
        ..deliver(day, 'e3', 'Sardor', sum: 100000, pay: 5000);
      expect(b.increments['work_days/$day/e3/deliverN'], 2);
      expect(b.increments['work_days/$day/e3/deliverSum'], 400000);
      expect(b.increments['work_days/$day/e3/deliverPay'], 20000);
      expect(b.increments['work_days/$day/e3/dispatchPay'], 6000);
    });

    test('qayta yuvish — yuvgan xodimga BUGUN ushlanma', () {
      final b = LedgerBatch()
        ..rewash('20261121',
            const ItemCredit(by: 'e1', name: 'Ali', day: day, pay: 9750));
      expect(b.increments, {
        'work_days/20261121/e1/rewashN': 1,
        'work_days/20261121/e1/rewashPay': 9750,
      });
    });

    test("o'lcham tuzatildi — faqat farq yoziladi, soni o'zgarmaydi", () {
      const before = ItemCredit(
          by: 'e1', name: 'Ali', day: day, pay: 9000, unit: MeasureUnit.m2, quantity: 6);
      const after = ItemCredit(
          by: 'e1', name: 'Ali', day: day, pay: 12000, unit: MeasureUnit.m2, quantity: 8);
      final b = LedgerBatch()..reviseWash(before, after);
      expect(b.increments, {
        'work_days/$day/e1/wash/m2': 2,
        'work_days/$day/e1/washPay': 3000,
      });
    });

    test("o'lchanmagan xizmat keyin o'lchandi — hajm va pul qo'shiladi", () {
      const before = ItemCredit(by: 'e1', name: 'Ali', day: day, pay: 0);
      const after = ItemCredit(
          by: 'e1', name: 'Ali', day: day, pay: 9000, unit: MeasureUnit.m2, quantity: 6);
      final b = LedgerBatch()..reviseWash(before, after);
      expect(b.increments, {
        'work_days/$day/e1/wash/m2': 6,
        'work_days/$day/e1/washPay': 9000,
      });
    });

    test("buyurtma o'chirildi — dispetcher ulushi qaytariladi", () {
      final b = LedgerBatch()
        ..uncreate(const CreateCredit(
            by: 'e2', day: day, pay: 3000, mode: DispatcherMode.fixed));
      expect(b.increments, {
        'work_days/$day/e2/createN': -1,
        'work_days/$day/e2/createPay': -3000,
      });
      // Faqat ayirish — ism yozilmaydi.
      expect(b.names, isEmpty);
    });

    test("noto'g'ri kalit (bo'sh yoki taqiqlangan belgi) — yozilmaydi", () {
      final b = LedgerBatch()
        ..create(day, '', 'X')
        ..create(day, 'a/b', 'X')
        ..create('bugun', 'e1', 'X');
      expect(b.isEmpty, isTrue);
    });

    test("nol summa yozilmaydi, lekin soni yoziladi", () {
      final b = LedgerBatch()..create(day, 'e1', 'Ali');
      expect(b.increments, {'work_days/$day/e1/createN': 1});
    });
  });

  group('kvitansiyalar', () {
    test('xizmat kvitansiyasi saqlanib, o\'qiladi', () {
      const c = ItemCredit(
          by: 'e1', name: 'Ali', day: '20261120', pay: 9000, unit: MeasureUnit.katta, quantity: 1);
      final back = ItemCredit.fromMap(c.toMap())!;
      expect(back.by, 'e1');
      expect(back.unit, MeasureUnit.katta);
      expect(back.pay, 9000);
      expect(ItemCredit.fromMap({'by': '', 'day': '20261120'}), isNull);
      expect(ItemCredit.fromMap('x'), isNull);
    });

    test('yuvgan xodim tarixdan topiladi (eski xizmatlar uchun)', () {
      OrderHistoryEntry h(String by, int at, String to, {String key = '1'}) =>
          OrderHistoryEntry(
            key: '$at',
            orderId: 5,
            type: 'item_status_changed',
            byEmployeeId: by,
            byName: by,
            at: at,
            toStatus: to,
            itemKey: key,
          );
      final history = [
        h('e1', 10, 'qadoqlashda'),
        h('e2', 20, 'qayta_yuvildi'),
        h('e3', 30, 'qadoqlashda'),
        h('e9', 40, 'qadoqlashda', key: '2'),
        h('e4', 35, 'tayyor'),
      ];
      expect(lastWasherOf(history, '1'), 'e3');
      expect(lastWasherOf(history, '2'), 'e9');
      expect(lastWasherOf(history, '7'), isNull);
    });
  });

  group("o'lchov yozuvi", () {
    test('aniq so\'z bilan, belgilangan tartibda', () {
      final a = UnitAmounts()
        ..add(MeasureUnit.katta, 8)
        ..add(MeasureUnit.m2, 145)
        ..add(MeasureUnit.kichik, 4)
        ..add(MeasureUnit.metr, 50)
        ..add(MeasureUnit.dona, 6)
        ..add(MeasureUnit.kg, 3);
      expect(a.label(separator: ' · ').replaceAll(' ', ' '),
          '145 m² · 50 m · 3 kg · 6 dona · 4 kichik · 8 katta');
    });

    test('kasr va minglik', () {
      expect(formatAmount(12.5), '12,5');
      expect(formatAmount(1250).replaceAll(' ', ' '), '1 250');
      expect(formatAmount(7.0), '7');
    });

    test('ayirilib nolga tushgan birlik ko\'rinmaydi', () {
      final a = UnitAmounts()
        ..add(MeasureUnit.m2, 6)
        ..add(MeasureUnit.m2, -6);
      expect(a.isEmpty, isTrue);
    });
  });
}
