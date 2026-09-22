import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Barmoq izi so'rovining natijasi.
enum BiometricResult {
  ok,

  /// Foydalanuvchi o'zi bekor qildi — bu xatolik emas, xabar ham
  /// ko'rsatilmaydi.
  cancelled,

  /// Qurilmada barmoq izi umuman sozlanmagan.
  notEnrolled,

  /// Qurilma qo'llab-quvvatlamaydi yoki imkoniyat o'chirilgan.
  unavailable,

  /// Ketma-ket ko'p xato — Android vaqtincha bloklagan.
  lockedOut,

  /// Boshqa xatolik.
  failed;

  /// Foydalanuvchiga ko'rsatiladigan sabab. Muvaffaqiyat va bekor
  /// qilishda `null` — aytadigan gap yo'q.
  String? get message => switch (this) {
        BiometricResult.ok || BiometricResult.cancelled => null,
        BiometricResult.notEnrolled =>
          'Telefoningizda barmoq izi sozlanmagan. Avval uni telefon '
              'sozlamalaridan qo\'shing.',
        BiometricResult.unavailable =>
          'Bu telefon barmoq izi bilan ochishni qo\'llab-quvvatlamaydi.',
        BiometricResult.lockedOut =>
          'Ko\'p marta xato bo\'ldi. Biroz kutib, qayta urining.',
        BiometricResult.failed =>
          'Barmoq izini tekshirib bo\'lmadi. Qayta urining.',
      };
}

/// Ilovaning MAHALLIY qulfi: PIN-kod va barmoq izi.
///
/// BU HISOBGA KIRISH EMAS. Hisobga kirish PIN-kodi serverda
/// tekshiriladi va kim ekanligingizni aniqlaydi. Bu yerdagi qulf esa
/// shunchaki telefonni boshqa qo'lga o'tganda ilovani ochib
/// ko'rmasliklari uchun — sessiya allaqachon ochilgan.
///
/// Shuning uchun u BUTUNLAY QURILMADA ishlaydi: serverga hech narsa
/// yuborilmaydi, internet kerak emas.
///
/// PIN ochiq holda SAQLANMAYDI. Saqlanadigan narsa — tasodifiy tuz
/// (salt) bilan, ko'p marta takrorlangan hash. Qurilma ildiz huquqi
/// bilan ochilgan taqdirda ham 4 xonali PIN'ni shu hashdan tiklash
/// sezilarli vaqt talab qiladi.
class AppLockService {
  AppLockService._();

  static final AppLockService instance = AppLockService._();

  static const _kHash = 'app_lock_hash';
  static const _kSalt = 'app_lock_salt';
  static const _kBiometrics = 'app_lock_biometrics';

  /// PIN uzunligi chegarasi — hisob PIN-kodi bilan bir xil.
  static const minLength = 4;
  static const maxLength = 8;

  /// Hash takrorlanish soni.
  ///
  /// Qancha ko'p bo'lsa, tekshiruv shuncha sekin — ya'ni PIN'ni
  /// saralab topish ham shuncha qiyin. 12 000 zamonaviy telefonda
  /// ~20 ms beradi: foydalanuvchi sezmaydi, saralovchi esa 10 000 ta
  /// variantni bir necha daqiqada emas, soatlarda o'tadi.
  static const _iterations = 12000;

  final _auth = LocalAuthentication();

  /// Qulf yoqilganmi.
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kHash) != null;
  }

  /// Barmoq izi bilan ochish yoqilganmi.
  Future<bool> biometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometrics) ?? false;
  }

  /// Qurilmada barmoq izi yoki yuz bilan ochish mavjudmi.
  ///
  /// Xatolik jim yutiladi: imkoniyatni aniqlab bo'lmasa, uni yo'q deb
  /// hisoblaymiz — sozlamalarda ishlamaydigan tugmani ko'rsatgandan
  /// ko'ra umuman ko'rsatmagan yaxshiroq.
  Future<bool> biometricsAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Barmoq izini tekshirib bo\'lmadi: $e');
      return false;
    }
  }

  /// Qulfni yoqadi yoki PIN'ni almashtiradi.
  Future<void> setPin(String pin) async {
    assert(pin.length >= minLength && pin.length <= maxLength);

    final salt = _randomSalt();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSalt, base64Encode(salt));
    await prefs.setString(_kHash, base64Encode(_derive(pin, salt)));
  }

  /// Qulfni butunlay o'chiradi.
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHash);
    await prefs.remove(_kSalt);
    await prefs.remove(_kBiometrics);
  }

  Future<void> setBiometrics(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometrics, enabled);
  }

  /// PIN to'g'rimi.
  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_kHash);
    final storedSalt = prefs.getString(_kSalt);
    if (storedHash == null || storedSalt == null) return false;

    final actual = _derive(pin, base64Decode(storedSalt));
    // Taqqoslash UZUNLIGIGA QARAB emas, har doim to'liq bajariladi:
    // "qaysi belgida farq qildi" degan ma'lumot vaqt orqali sizib
    // chiqmasligi kerak.
    return _constantTimeEquals(base64Decode(storedHash), actual);
  }

  /// Barmoq izi so'raydi.
  ///
  /// Natija ATAYLAB `bool` emas. Ilgari shunday edi va har qanday
  /// muvaffaqiyatsizlik — bekor qilishmi, qurilmada barmoq izi
  /// sozlanmaganmi, ilovaning o'zi noto'g'ri yig'ilganmi — bir xil
  /// `false` bo'lib qaytardi. Sozlamalardagi kalit esa jimgina
  /// qaytib tushardi va foydalanuvchi sababini bilolmasdi.
  Future<BiometricResult> authenticateBiometric() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Ilovani ochish uchun tasdiqlang',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok ? BiometricResult.ok : BiometricResult.cancelled;
    } on PlatformException catch (e) {
      debugPrint('Barmoq izi bilan ochilmadi: ${e.code} ${e.message}');
      return switch (e.code) {
        'NotEnrolled' => BiometricResult.notEnrolled,
        'NotAvailable' => BiometricResult.unavailable,
        'LockedOut' || 'PermanentlyLockedOut' => BiometricResult.lockedOut,
        _ => BiometricResult.failed,
      };
    } catch (e) {
      debugPrint('Barmoq izi bilan ochilmadi: $e');
      return BiometricResult.failed;
    }
  }

  // -------------------------------------------------------------------
  // Ichki
  // -------------------------------------------------------------------

  Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  /// PBKDF2 ga o'xshash takroriy hash.
  ///
  /// Har bir bosqichda oldingi natija tuz bilan birga yana hash
  /// qilinadi — natijani oldindan hisoblab qo'yib bo'lmaydi.
  Uint8List _derive(String pin, Uint8List salt) {
    final hmac = Hmac(sha256, salt);
    var value = Uint8List.fromList(utf8.encode(pin));
    for (var i = 0; i < _iterations; i++) {
      value = Uint8List.fromList(hmac.convert(value).bytes);
    }
    return value;
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
