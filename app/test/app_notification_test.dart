import 'package:cscrm/models/app_notification.dart';
import 'package:cscrm/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = 'xodim-1';
const _other = 'xodim-2';

/// Buyurtma yasaydi.
///
/// Bildirishnomalar endi TARIXDAN emas, buyurtmaning o'zidagi hodisa
/// belgilaridan quriladi (tarix alohida tugunga chiqarilgan).
Order order({
  int id = 7,
  String customerName = 'Ali',
  int createdAt = 1000,
  String createdBy = _other,
  Map<String, Object?> stamps = const {},
}) =>
    Order.fromMap('$id', {
      'id': id,
      'customerName': customerName,
      'status': 'yuvishda',
      'createdAt': createdAt,
      'createdBy': createdBy,
      'createdByName': createdBy == _me ? 'Men' : 'Boshqa xodim',
      ...stamps,
    });

/// `pickedUp` / `ready` / `delivered` / `lastRewash` / `lastDebtPayment`
/// belgisini yasaydi.
Map<String, Object?> stamp(
  String prefix, {
  required int at,
  String by = _other,
  String? note,
}) =>
    {
      '${prefix}At': at,
      '${prefix}By': by,
      '${prefix}ByName': by == _me ? 'Men' : 'Boshqa xodim',
      if (note != null) '${prefix}Note': note,
    };

List<AppNotification> build(
  List<Order> orders, {
  String actor = _me,
  int since = 0,
}) =>
    buildNotifications(orders: orders, currentActorId: actor, since: since);

void main() {
  group('qaysi hodisalar bildirishnoma bo\'ladi', () {
    test('yangi buyurtma', () {
      final n = build([order()]);
      expect(n, hasLength(1));
      expect(n.single.type, NotificationType.newOrder);
    });

    test('qabul qilindi', () {
      final n = build([
        order(stamps: stamp('pickedUp', at: 2000)),
      ]);
      expect(
        n.map((e) => e.type),
        containsAll([NotificationType.newOrder, NotificationType.accepted]),
      );
    });

    test('yetgazishga tayyor', () {
      final n = build([order(stamps: stamp('ready', at: 3000))]);
      expect(n.map((e) => e.type), contains(NotificationType.readyForDelivery));
    });

    test('yetgazildi', () {
      final n = build([order(stamps: stamp('delivered', at: 4000))]);
      expect(n.map((e) => e.type), contains(NotificationType.delivered));
    });

    test('qayta yuvish sababi bilan ko\'rsatiladi', () {
      final n = build([
        order(
          stamps: stamp('lastRewash', at: 5000, note: 'Gilam — Dog\' qolgan'),
        ),
      ]);
      final rewash = n.firstWhere((e) => e.type == NotificationType.rewash);
      expect(rewash.body, contains('Gilam'));
      expect(rewash.body, contains('Dog\' qolgan'));
    });

    test('qarz to\'landi', () {
      final n = build([
        order(stamps: stamp('lastDebtPayment', at: 6000, note: '50 000 so\'m')),
      ]);
      final debt =
          n.firstWhere((e) => e.type == NotificationType.debtSettled);
      expect(debt.body, contains('50 000'));
    });

    test('bitta buyurtma bir nechta hodisa berishi mumkin', () {
      final n = build([
        order(stamps: {
          ...stamp('pickedUp', at: 2000),
          ...stamp('ready', at: 3000),
          ...stamp('delivered', at: 4000),
        }),
      ]);
      expect(n, hasLength(4), reason: 'yaratildi + 3 ta bosqich');
    });
  });

  group('o\'z harakati qaytmaydi', () {
    test('o\'zi yaratgan buyurtma ro\'yxatga tushmaydi', () {
      expect(build([order(createdBy: _me)]), isEmpty);
    });

    test('har bir hodisa alohida tekshiriladi', () {
      // Buyurtmani boshqa xodim yaratgan, lekin yetgazgani - o'zim.
      final n = build([
        order(
          createdBy: _other,
          stamps: stamp('delivered', at: 4000, by: _me),
        ),
      ]);
      expect(n, hasLength(1));
      expect(
        n.single.type,
        NotificationType.newOrder,
        reason: 'o\'zim yetkazganim uchun "yetgazildi" chiqmasligi kerak',
      );
    });
  });

  group('vaqt oynasi va tartib', () {
    test('eski hodisalar chiqarib tashlanadi', () {
      final n = build(
        [
          order(
            createdAt: 1000,
            stamps: stamp('delivered', at: 9000),
          ),
        ],
        since: 5000,
      );
      expect(n, hasLength(1));
      expect(n.single.type, NotificationType.delivered);
    });

    test('eng yangisi birinchi turadi', () {
      final n = build([
        order(id: 1, createdAt: 1000),
        order(id: 2, createdAt: 9000),
        order(id: 3, createdAt: 5000),
      ]);
      expect(n.map((e) => e.orderId).toList(), [2, 3, 1]);
    });

    test('chegara qo\'llanadi', () {
      final orders = [
        for (var i = 0; i < 80; i++) order(id: i, createdAt: 1000 + i),
      ];
      expect(build(orders).length, 50);
    });
  });

  test('ID buyurtma va hodisa turidan tuziladi', () {
    final n = build([order(id: 42)]);
    expect(n.single.id, '42/newOrder');
  });

  test('belgi yo\'q bo\'lsa hodisa ham yo\'q', () {
    final n = build([order()]);
    expect(
      n.where((e) => e.type != NotificationType.newOrder),
      isEmpty,
      reason: 'faqat haqiqatda ro\'y bergan hodisalar ko\'rsatiladi',
    );
  });
}
