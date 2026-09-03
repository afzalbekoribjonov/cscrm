import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Rad etilgan yozuv haqida xabar.
class LateWriteFailure {
  const LateWriteFailure(this.message, this.cause);

  final String message;
  final Object cause;
}

/// Rad etilgan yozuvlar oqimi.
///
/// NEGA ISTISNO EMAS, OQIM: bu yozuvlar "yubor va kutma" uslubida
/// ishlaydi — Firebase o'zgarishni mahalliy keshga darhol qo'llaydi,
/// ekran esa server javobini kutmay yopiladi. Server javobi ko'pincha
/// ekran yopilgandan KEYIN keladi, ya'ni istisnoni qaytaradigan joy
/// qolmaydi.
///
/// Bundan tashqari chaqiruvchi ekranlarning aksari `try { } finally { }`
/// ishlatadi (`catch` siz) — istisno tashlansa u ushlanmay qolardi.
///
/// Shuning uchun barcha rad etishlar shu oqimga tushadi va ilova qobig'i
/// (HomeShell) ularni bitta joyda ko'rsatadi. Muhimi: xatolik endi JIM
/// YO'QOLMAYDI — ilgari `catchError` uni butunlay yutib yuborardi va
/// foydalanuvchi "saqlandi" deb o'ylab qolardi.
class WriteFailures {
  WriteFailures._();

  static final _controller = StreamController<LateWriteFailure>.broadcast();

  static Stream<LateWriteFailure> get stream => _controller.stream;

  static void report(LateWriteFailure failure) {
    if (!_controller.isClosed) _controller.add(failure);
  }
}

/// Xatolik vaqtinchalik (tarmoq) mi yoki haqiqiy rad etishmi.
///
/// Bu farq juda muhim:
///  * TARMOQ — Firebase o'zgarishni mahalliy keshda saqlab, aloqa
///    tiklanganda o'zi yuboradi. Foydalanuvchini bezovta qilishning
///    hojati yo'q.
///  * RAD ETISH (masalan `permission-denied`) — o'zgarish HECH QACHON
///    saqlanmaydi. Buni aytmaslik ma'lumot yo'qolishiga olib keladi.
bool _isTransient(Object error) {
  if (error is! FirebaseException) return false;
  const transient = {
    'unavailable',
    'network-error',
    'disconnected',
    'deadline-exceeded',
    'cancelled',
    'timeout',
  };
  return transient.contains(error.code);
}

String _messageFor(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Bu amalga ruxsatingiz yo\'q. O\'zgarish saqlanmadi.';
      case 'expired-token':
      case 'invalid-token':
        return 'Sessiya muddati tugagan. Chiqib, qaytadan kiring.';
      default:
        return 'O\'zgarishni saqlab bo\'lmadi: ${error.message ?? error.code}';
    }
  }
  return 'O\'zgarishni saqlab bo\'lmadi.';
}

/// Firebase Realtime Database yozuvining `Future`'i faqat SERVER tasdiqlagach
/// tugaydi. Internet uzilib qolsa u umuman tugamaydi — natijada `await`
/// qilgan ekran abadiy "kutish" holatida qotib qolardi.
///
/// Ayni paytda Firebase o'zgarishni mahalliy keshga darhol yozadi va jonli
/// oqim shu zahoti yangilanadi — ya'ni foydalanuvchi natijani darhol
/// ko'radi. Yozuvning o'zi navbatda turadi va aloqa tiklanganda avtomatik
/// yuboriladi.
///
/// Shu sabab yozuvni cheksiz kutmaymiz: qisqa muddat kutamiz, ulgurmasa
/// "navbatga qo'yildi" deb hisoblab, ekranni bo'shatamiz.
///
/// MUHIM: ilgari bu funksiya HAMMA xatolikni jim yutardi — shu jumladan
/// `permission-denied` ni ham. Natijada ekran "bajarildi" deb yopilardi,
/// o'zgarish esa keshdan qaytib yo'qolardi va buni hech kim bilmasdi.
///
/// Endi ikkisi ajratiladi:
///  * vaqtinchalik (tarmoq) — jim navbatga qo'yiladi, bu normal holat
///  * haqiqiy rad etish — [WriteFailures.stream] orqali ko'rsatiladi
///
/// Bu funksiya HECH QACHON istisno tashlamaydi (sababi: [WriteFailures]
/// izohiga qarang), shuning uchun chaqiruvchi ekranlarni o'zgartirish
/// shart emas.
Future<void> awaitOrQueue(
  Future<void> write, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final settled = Completer<void>();

  // Xatolik "unhandled" bo'lib qolmasligi uchun darhol ushlab qo'yamiz —
  // bu future timeout'dan keyin ham davom etadi.
  unawaited(write.then<void>(
    (_) {
      if (!settled.isCompleted) settled.complete();
    },
    onError: (Object error, StackTrace stack) {
      if (_isTransient(error)) {
        debugPrint('Firebase yozuvi navbatga qo\'yildi (tarmoq): $error');
      } else {
        debugPrint('Firebase yozuvi RAD ETILDI: $error\n$stack');
        WriteFailures.report(LateWriteFailure(_messageFor(error), error));
      }
      if (!settled.isCompleted) settled.complete();
    },
  ));

  try {
    await settled.future.timeout(timeout);
  } on TimeoutException {
    // Aloqa yo'q yoki sekin — o'zgarish mahalliy keshda, Firebase uni
    // aloqa tiklanganda o'zi yuboradi. Keyinroq rad etilsa, xatolik
    // yuqoridagi `onError` orqali oqimga tushadi.
    debugPrint('Firebase yozuvi navbatga qo\'yildi (javob kelmadi).');
  }
}

/// Qiymat qaytaradigan yozuvlar (masalan buyurtma yaratish) uchun.
/// Bularni navbatga qo'yib bo'lmaydi — ID serverdan olinadi — shu sabab
/// belgilangan muddatda javob kelmasa [TimeoutException] chiqadi va
/// chaqiruvchi foydalanuvchiga tushunarli xabar ko'rsatadi.
Future<T> awaitOrFail<T>(
  Future<T> work, {
  Duration timeout = const Duration(seconds: 12),
}) {
  return work.timeout(timeout);
}
