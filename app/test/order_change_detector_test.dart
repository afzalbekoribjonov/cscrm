import 'package:cscrm/models/item_status.dart';
import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/utils/order_change_detector.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = 'xodim-1';
const _other = 'xodim-2';

/// Test uchun buyurtma yasaydi.
///
/// `lastActor` — buyurtmaga OXIRGI marta kim tegingani. Ovoz chalinishi
/// aynan shunga qarab hal qilinadi.
///
/// Ilgari bu tarixdan o'qilardi; endi buyurtmaning o'zidagi
/// `lastActionBy` maydonidan — tarix alohida tugunga chiqarilgan va
/// ro'yxat so'roviga tushmaydi.
Order order({
  required int id,
  String status = 'yuvishda',
  List<String> itemStatuses = const ['yuvilmoqda'],
  String lastActor = _other,
  int comments = 0,
}) {
  return Order.fromMap('$id', {
    'id': id,
    'status': status,
    'items': {
      for (var i = 0; i < itemStatuses.length; i++)
        '${i + 1}': {'price': 1000, 'status': itemStatuses[i]},
    },
    'lastActionAt': 2000,
    'lastActionBy': lastActor,
    'comments': {
      for (var i = 0; i < comments; i++)
        'c$i': {'text': 'izoh', 'createdAt': 1000 + i},
    },
  });
}

void main() {
  late OrderChangeDetector detector;

  setUp(() {
    detector = OrderChangeDetector(currentActorId: _me);
  });

  group('birinchi yuklanish', () {
    test('ovoz chalinmaydi', () {
      final result = detector.shouldNotify([order(id: 1), order(id: 2)]);
      expect(
        result,
        isFalse,
        reason: 'ilova ochilganda butun ro\'yxat "yangi" ko\'rinadi, '
            'lekin bu o\'zgarish emas',
      );
    });

    test('bo\'sh ro\'yxat ham jim', () {
      expect(detector.shouldNotify([]), isFalse);
    });
  });

  group('o\'zgarish yo\'q', () {
    test('bir xil ro\'yxat qayta kelsa jim', () {
      detector.shouldNotify([order(id: 1)]);
      expect(detector.shouldNotify([order(id: 1)]), isFalse);
    });
  });

  group('kim o\'zgartirgani', () {
    test('BOSHQA xodim o\'zgartirsa ovoz chalinadi', () {
      detector.shouldNotify([order(id: 1, itemStatuses: ['yuvilmoqda'])]);

      final changed = order(
        id: 1,
        itemStatuses: [ItemStatus.qadoqlashda.key],
        lastActor: _other,
      );
      expect(detector.shouldNotify([changed]), isTrue);
    });

    test('O\'ZI o\'zgartirsa ovoz chalinmaydi', () {
      detector.shouldNotify([order(id: 1, itemStatuses: ['yuvilmoqda'])]);

      final changed = order(
        id: 1,
        itemStatuses: [ItemStatus.qadoqlashda.key],
        lastActor: _me,
      );
      expect(
        detector.shouldNotify([changed]),
        isFalse,
        reason: 'xodim o\'z tugmasini bosganda o\'ziga ovoz eshittirmaslik kerak',
      );
    });

    test('bir vaqtda o\'zi va boshqasi o\'zgartirsa - ovoz chalinadi', () {
      detector.shouldNotify([order(id: 1), order(id: 2)]);

      expect(
        detector.shouldNotify([
          order(id: 1, itemStatuses: ['tayyor'], lastActor: _me),
          order(id: 2, itemStatuses: ['tayyor'], lastActor: _other),
        ]),
        isTrue,
      );
    });
  });

  group('yangi buyurtma', () {
    test('boshqa xodim yaratgan buyurtma ovoz beradi', () {
      detector.shouldNotify([order(id: 1)]);
      expect(
        detector.shouldNotify([order(id: 1), order(id: 2, lastActor: _other)]),
        isTrue,
      );
    });

    test('o\'zi yaratgan buyurtma ovoz bermaydi', () {
      detector.shouldNotify([order(id: 1)]);
      expect(
        detector.shouldNotify([order(id: 1), order(id: 2, lastActor: _me)]),
        isFalse,
      );
    });
  });

  group('boshqa o\'zgarishlar', () {
    test('buyurtma holati o\'zgarsa sezadi', () {
      detector.shouldNotify([order(id: 1, status: 'yuvishda')]);
      expect(
        detector.shouldNotify([
          order(id: 1, status: OrderStatus.yetgazishgaTayyor.key),
        ]),
        isTrue,
      );
    });

    test('yangi izoh sezadi', () {
      detector.shouldNotify([order(id: 1, comments: 0)]);
      expect(detector.shouldNotify([order(id: 1, comments: 1)]), isTrue);
    });

    test('buyurtma o\'chirilsa ovoz chalinmaydi', () {
      detector.shouldNotify([order(id: 1), order(id: 2)]);
      expect(
        detector.shouldNotify([order(id: 1)]),
        isFalse,
        reason: 'o\'chirish ataylab qilinadi, ovoz kerak emas',
      );
    });
  });

  group('reset', () {
    test('qayta ulangandan keyin bir yo\'la ovoz chalinmaydi', () {
      detector.shouldNotify([order(id: 1, itemStatuses: ['yuvilmoqda'])]);
      detector.reset();

      expect(
        detector.shouldNotify([
          order(id: 1, itemStatuses: ['tayyor'], lastActor: _other),
        ]),
        isFalse,
        reason: 'oqim qayta ulanganda keyingi ro\'yxat "birinchi" hisoblanadi',
      );
    });
  });
}
