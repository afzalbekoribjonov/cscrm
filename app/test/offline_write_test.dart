import 'dart:async';

import 'package:cscrm/utils/offline_write.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// `awaitOrQueue` xatoliklarni to'g'ri ajratayotganini tekshiradi.
///
/// Bu mantiq muhim: ilgari HAMMA xatolik jim yutilardi, shu jumladan
/// `permission-denied` ham. Natijada ekran "saqlandi" deb yopilardi,
/// o'zgarish esa keyinroq keshdan qaytib yo'qolardi.
void main() {
  /// Testlar davomida oqimga tushgan xatoliklarni yig'ib boradi.
  late List<LateWriteFailure> reported;
  late StreamSubscription<LateWriteFailure> sub;

  setUp(() {
    reported = [];
    sub = WriteFailures.stream.listen(reported.add);
  });

  tearDown(() async {
    await sub.cancel();
  });

  /// Oqim broadcast bo'lgani uchun xabar mikrotask'da yetadi.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('muvaffaqiyatli yozuv', () {
    test('xatolik xabar qilinmaydi', () async {
      await awaitOrQueue(Future<void>.value());
      await settle();
      expect(reported, isEmpty);
    });
  });

  group('vaqtinchalik (tarmoq) xatoliklari', () {
    test('unavailable jim navbatga qo\'yiladi', () async {
      await awaitOrQueue(
        Future<void>.error(
          FirebaseException(plugin: 'database', code: 'unavailable'),
        ),
      );
      await settle();
      expect(
        reported,
        isEmpty,
        reason: 'tarmoq xatosida foydalanuvchini bezovta qilmaslik kerak - '
            'Firebase yozuvni aloqa tiklanganda o\'zi yuboradi',
      );
    });

    test('network-error ham jim o\'tadi', () async {
      await awaitOrQueue(
        Future<void>.error(
          FirebaseException(plugin: 'database', code: 'network-error'),
        ),
      );
      await settle();
      expect(reported, isEmpty);
    });
  });

  group('haqiqiy rad etishlar', () {
    test('permission-denied xabar qilinadi', () async {
      await awaitOrQueue(
        Future<void>.error(
          FirebaseException(plugin: 'database', code: 'permission-denied'),
        ),
      );
      await settle();

      expect(reported, hasLength(1));
      expect(reported.single.message, contains('ruxsatingiz yo\'q'));
      expect(reported.single.message, contains('saqlanmadi'));
    });

    test('sessiya tugaganda tushunarli xabar beriladi', () async {
      await awaitOrQueue(
        Future<void>.error(
          FirebaseException(plugin: 'database', code: 'expired-token'),
        ),
      );
      await settle();

      expect(reported, hasLength(1));
      expect(reported.single.message, contains('qaytadan kiring'));
    });

    test('noma\'lum Firebase xatosi ham yutilmaydi', () async {
      await awaitOrQueue(
        Future<void>.error(
          FirebaseException(plugin: 'database', code: 'operation-failed'),
        ),
      );
      await settle();
      expect(reported, hasLength(1));
    });
  });

  group('javob kelmaganda', () {
    test('belgilangan vaqtda qaytadi, ekranni qotirmaydi', () async {
      final never = Completer<void>();
      final stopwatch = Stopwatch()..start();

      await awaitOrQueue(
        never.future,
        timeout: const Duration(milliseconds: 60),
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      await settle();
      expect(reported, isEmpty, reason: 'kutish - bu hali xatolik emas');

      never.complete();
    });

    test('vaqt tugagandan KEYIN kelgan rad etish ham ko\'rsatiladi', () async {
      final late$ = Completer<void>();

      await awaitOrQueue(
        late$.future,
        timeout: const Duration(milliseconds: 40),
      );
      await settle();
      expect(reported, isEmpty, reason: 'hozircha faqat kutildi');

      // Server javobi ekran yopilgandan keyin keldi.
      late$.completeError(
        FirebaseException(plugin: 'database', code: 'permission-denied'),
      );
      await settle();

      expect(
        reported,
        hasLength(1),
        reason: 'kech kelgan rad etish ham foydalanuvchiga yetishi shart',
      );
    });
  });
}
