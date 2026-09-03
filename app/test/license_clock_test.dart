import 'package:cscrm/utils/license_clock.dart';
import 'package:flutter_test/flutter_test.dart';

/// Oflayn oyna mantiqini tekshiradi.
///
/// Ilova ONLAYN bo'lganda vaqt muhim emas — javobni server beradi va u
/// imzolangan. Lekin OFLAYN holatda keshning muddati o'tganini aniqlash
/// uchun vaqt kerak, va yagona manba qurilma soati bo'lib qoladi.
void main() {
  const hour = 60 * 60 * 1000;
  const serverTime = 1766793600000; // barqaror nuqta

  group('effectiveNow', () {
    test('odatiy holatda qurilma vaqti ishlatiladi', () {
      expect(
        effectiveNow(
          deviceNow: serverTime + hour,
          lastServerTime: serverTime,
        ),
        serverTime + hour,
      );
    });

    test('soat ORQAGA surilsa server vaqtiga qaytadi', () {
      // Foydalanuvchi soatni bir hafta orqaga surdi - shu bilan oflayn
      // oynani cho'zmoqchi.
      final result = effectiveNow(
        deviceNow: serverTime - 7 * 24 * hour,
        lastServerTime: serverTime,
      );
      expect(
        result,
        serverTime,
        reason: 'orqaga surilgan soat oflayn oynani cho\'za olmasligi kerak',
      );
    });

    test('soat oldinga surilsa qabul qilinadi', () {
      // Oldinga surish foyda bermaydi - u keshni tezroq eskirtiradi va
      // ilovani serverga murojaat qilishga majbur qiladi.
      final result = effectiveNow(
        deviceNow: serverTime + 100 * hour,
        lastServerTime: serverTime,
      );
      expect(result, serverTime + 100 * hour);
    });

    test('server vaqti hali ma\'lum bo\'lmasa qurilma vaqti ishlatiladi', () {
      expect(
        effectiveNow(deviceNow: serverTime, lastServerTime: 0),
        serverTime,
      );
    });
  });

  group('isCacheUsable', () {
    // TTL 6 soat.
    final validUntil = serverTime + 6 * hour;

    test('oyna ichida yaroqli', () {
      expect(
        isCacheUsable(validUntil: validUntil, now: serverTime + hour),
        isTrue,
      );
    });

    test('oyna tugagach yaroqsiz', () {
      expect(
        isCacheUsable(validUntil: validUntil, now: serverTime + 7 * hour),
        isFalse,
      );
    });

    test('aynan chegarada yaroqsiz', () {
      expect(isCacheUsable(validUntil: validUntil, now: validUntil), isFalse);
    });

    test('chegaradan bir millisekund oldin hali yaroqli', () {
      expect(
        isCacheUsable(validUntil: validUntil, now: validUntil - 1),
        isTrue,
      );
    });
  });

  group('birgalikda: soatni orqaga surish keshni cho\'za olmaydi', () {
    test('6 soatlik oyna tugagach, soatni orqaga surish yordam bermaydi', () {
      final validUntil = serverTime + 6 * hour;

      // Haqiqiy vaqt: 10 soat o'tdi, oyna allaqachon tugagan.
      final realNow = serverTime + 10 * hour;
      expect(isCacheUsable(validUntil: validUntil, now: realNow), isFalse);

      // Foydalanuvchi soatni tekshiruv paytiga qaytardi.
      final spoofed = effectiveNow(
        deviceNow: serverTime + hour,
        lastServerTime: serverTime + 10 * hour, // oxirgi ko'rilgan server vaqti
      );
      expect(
        isCacheUsable(validUntil: validUntil, now: spoofed),
        isFalse,
        reason: 'oxirgi server vaqti orqaga qaytishga yo\'l qo\'ymaydi',
      );
    });
  });
}
