import 'dart:math' as math;

import '../models/order.dart';

/// Yetgazishga tayyor buyurtmalarni saralash usullari.
enum DeliverySort {
  /// Tabiiy tartib — muddat bo'yicha (ro'yxat qanday kelsa shunday).
  all('Barchasi'),

  /// Dastavchikka eng yaqinidan boshlab.
  distance('Manzil'),

  /// Eng eski buyurtmadan boshlab — kutib qolgani birinchi.
  date('Sana'),

  expensive('Eng qimmat'),
  cheap('Eng arzon');

  const DeliverySort(this.label);

  final String label;
}

/// Ikki nuqta orasidagi masofa (metrda).
///
/// Haversine formulasi — Yer sharining egriligi hisobga olinadi.
///
/// NEGA O'ZIMIZNIKI, `Geolocator.distanceBetween` EMAS: u platforma
/// kanali orqali ishlaydi, ya'ni uni sinovda chaqirib bo'lmaydi.
/// Bu esa sof matematika: saralash mantig'i to'liq sinovdan o'tadi.
double distanceMeters(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  const earthRadius = 6371000.0; // metr

  double toRad(double deg) => deg * math.pi / 180;

  final dLat = toRad(toLat - fromLat);
  final dLng = toRad(toLng - fromLng);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(fromLat)) *
          math.cos(toRad(toLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);

  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Buyurtmagacha bo'lgan masofa. Koordinata saqlanmagan bo'lsa `null`.
double? distanceTo(Order order, {double? fromLat, double? fromLng}) {
  if (fromLat == null || fromLng == null) return null;
  if (!order.hasPickupLocation) return null;
  return distanceMeters(fromLat, fromLng, order.pickupLat!, order.pickupLng!);
}

/// Buyurtmalarni tanlangan usulda saralaydi.
///
/// Ro'yxat NUSXALANADI — kiruvchi ro'yxat o'zgarmaydi. Bu muhim:
/// bo'limlar `HomeShell` da bir marta hisoblanadi va ular ustida
/// joyida saralash boshqa ekranlarning tartibini ham buzib yuborardi.
List<Order> sortDeliveries(
  List<Order> orders,
  DeliverySort sort, {
  double? fromLat,
  double? fromLng,
}) {
  final sorted = [...orders];

  switch (sort) {
    case DeliverySort.all:
      break;

    case DeliverySort.distance:
      // Koordinatasi YO'Q buyurtmalar oxirida qoladi.
      //
      // Ular "cheksiz uzoqda" deb hisoblanmaydi — shunchaki alohida
      // ajratiladi va o'z tartibini saqlaydi. Aks holda ular bir-biri
      // bilan tasodifiy o'rin almashardi.
      final withGps = <(Order, double)>[];
      final withoutGps = <Order>[];

      for (final order in sorted) {
        final d = distanceTo(order, fromLat: fromLat, fromLng: fromLng);
        if (d == null) {
          withoutGps.add(order);
        } else {
          withGps.add((order, d));
        }
      }

      withGps.sort((a, b) => a.$2.compareTo(b.$2));
      return [...withGps.map((e) => e.$1), ...withoutGps];

    case DeliverySort.date:
      sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    case DeliverySort.expensive:
      sorted.sort((a, b) => b.totalPrice.compareTo(a.totalPrice));

    case DeliverySort.cheap:
      sorted.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
  }

  return sorted;
}

/// Masofani o'qishga qulay ko'rinishga keltiradi.
///
/// Kilometrdan kichik masofa metrda ko'rsatiladi: "0,4 km" degan yozuv
/// dastavchikka hech narsa demaydi, "420 m" esa aniq.
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
