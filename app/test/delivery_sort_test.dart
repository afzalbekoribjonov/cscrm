import 'package:cscrm/models/order.dart';
import 'package:cscrm/models/order_status.dart';
import 'package:cscrm/utils/delivery_sort.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yetgazishga tayyor buyurtmalarni saralash.
///
/// Eng nozik joyi — MANZIL bo'yicha saralash. Mijozning o'zi kelgan
/// buyurtmada GPS koordinatasi umuman saqlanmaydi, ya'ni ro'yxatning
/// bir qismida masofa bor, bir qismida yo'q. Ularni aralashtirib
/// yuborish dastavchikni noto'g'ri yo'lga boshlaydi.

Order order({
  required int id,
  double? lat,
  double? lng,
  double price = 100000,
  int createdAt = 1000,
}) =>
    Order(
      id: id,
      customerName: 'Mijoz $id',
      customerPhone: '998901234567',
      address: 'Manzil $id',
      deadline: null,
      deliveryType: DeliveryType.olibKelish,
      status: OrderStatus.yetgazishgaTayyor,
      createdBy: 'emp1',
      createdByName: 'Sardor',
      createdAt: createdAt,
      items: const [],
      totalPrice: price,
      comments: const [],
      pickupLat: lat,
      pickupLng: lng,
    );

/// Toshkent markazi — sinovdagi tayanch nuqta.
const _lat = 41.311081;
const _lng = 69.240562;

List<int> ids(List<Order> orders) => orders.map((o) => o.id).toList();

void main() {
  group('masofa hisobi', () {
    test('bir xil nuqta orasidagi masofa nol', () {
      expect(distanceMeters(_lat, _lng, _lat, _lng), closeTo(0, 0.001));
    });

    test('ma\'lum masofa to\'g\'ri chiqadi', () {
      // Bir daraja kenglik ~111 km.
      final d = distanceMeters(_lat, _lng, _lat + 1, _lng);
      expect(d, closeTo(111195, 500));
    });

    test('koordinatasiz buyurtmada masofa yo\'q', () {
      expect(
        distanceTo(order(id: 1), fromLat: _lat, fromLng: _lng),
        isNull,
      );
    });

    test('dastavchik joylashuvi noma\'lum bo\'lsa masofa yo\'q', () {
      expect(distanceTo(order(id: 1, lat: _lat, lng: _lng)), isNull);
    });
  });

  group('saralash', () {
    test('"Barchasi" tartibni o\'zgartirmaydi', () {
      final input = [order(id: 3), order(id: 1), order(id: 2)];
      expect(ids(sortDeliveries(input, DeliverySort.all)), [3, 1, 2]);
    });

    test('kiruvchi ro\'yxat O\'ZGARMAYDI', () {
      // Bo'limlar HomeShell'da bir marta hisoblanadi — joyida saralash
      // boshqa ekranlarning tartibini ham buzib yuborardi.
      final input = [order(id: 3), order(id: 1)];
      sortDeliveries(input, DeliverySort.cheap);
      expect(ids(input), [3, 1]);
    });

    test('"Sana" — eng eskisi birinchi', () {
      final input = [
        order(id: 1, createdAt: 300),
        order(id: 2, createdAt: 100),
        order(id: 3, createdAt: 200),
      ];
      expect(ids(sortDeliveries(input, DeliverySort.date)), [2, 3, 1]);
    });

    test('"Eng qimmat" va "Eng arzon" teskari tartibda', () {
      final input = [
        order(id: 1, price: 200000),
        order(id: 2, price: 500000),
        order(id: 3, price: 100000),
      ];
      expect(ids(sortDeliveries(input, DeliverySort.expensive)), [2, 1, 3]);
      expect(ids(sortDeliveries(input, DeliverySort.cheap)), [3, 1, 2]);
    });
  });

  group('"Manzil" bo\'yicha', () {
    test('eng yaqini birinchi', () {
      final input = [
        // ~2 km shimolda
        order(id: 1, lat: _lat + 0.018, lng: _lng),
        // ~0.5 km shimolda
        order(id: 2, lat: _lat + 0.0045, lng: _lng),
        // ~10 km shimolda
        order(id: 3, lat: _lat + 0.09, lng: _lng),
      ];

      expect(
        ids(sortDeliveries(input, DeliverySort.distance,
            fromLat: _lat, fromLng: _lng)),
        [2, 1, 3],
      );
    });

    test('GPS SAQLANMAGANLARI OXIRIDA qoladi', () {
      // Eng muhim sinov. Koordinatasi yo'q buyurtma "juda uzoq" deb
      // hisoblanmaydi — u shunchaki ajratib qo'yiladi.
      final input = [
        order(id: 1),
        order(id: 2, lat: _lat + 0.09, lng: _lng),
        order(id: 3),
        order(id: 4, lat: _lat + 0.0045, lng: _lng),
      ];

      expect(
        ids(sortDeliveries(input, DeliverySort.distance,
            fromLat: _lat, fromLng: _lng)),
        [4, 2, 1, 3],
      );
    });

    test('koordinatasizlar O\'Z tartibini saqlaydi', () {
      // Ular bir-biri bilan tasodifiy o'rin almashmasligi kerak.
      final input = [order(id: 7), order(id: 3), order(id: 5)];

      expect(
        ids(sortDeliveries(input, DeliverySort.distance,
            fromLat: _lat, fromLng: _lng)),
        [7, 3, 5],
      );
    });

    test('dastavchik joylashuvi yo\'q bo\'lsa hammasi joyida qoladi', () {
      final input = [
        order(id: 1, lat: _lat + 0.09, lng: _lng),
        order(id: 2, lat: _lat + 0.0045, lng: _lng),
      ];

      expect(ids(sortDeliveries(input, DeliverySort.distance)), [1, 2]);
    });
  });

  group('masofa yozuvi', () {
    test('kilometrdan kichigi METRDA ko\'rsatiladi', () {
      // "0,4 km" dastavchikka hech narsa demaydi.
      expect(formatDistance(420), '420 m');
      expect(formatDistance(999), '999 m');
    });

    test('kilometr bitta kasr xona bilan', () {
      expect(formatDistance(2700), '2.7 km');
      expect(formatDistance(12345), '12.3 km');
    });
  });
}
