import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Obuna holati.
///
/// Qiymatlar server tomonidagi `LicenseState` bilan AYNAN mos bo'lishi
/// shart (backend/src/types/license.ts).
enum LicenseState {
  /// Faol - hech qanday cheklov yo'q.
  active('active'),

  /// Faol, lekin muddat tugashiga oz qoldi - eslatma ko'rsatiladi.
  expiring('expiring'),

  /// Muddat tugagan, lekin qo'shimcha kunlar davom etmoqda.
  ///
  /// HOZIR SERVER BU HOLATNI YUBORMAYDI: obuna tugagan zahoti
  /// bloklanadi, qo'shimcha vaqt berilmaydi. Holat protokolda
  /// ATAYLAB qoldirilgan — qoida qaytarilsa ilovani yangilash
  /// shart bo'lmasligi uchun. Eski o'rnatilgan ilovalar ham buni
  /// tushunishi kerak.
  grace('grace'),

  /// Muddat tugagan - ilova bloklanadi.
  expired('expired'),

  /// Bir umrlik, lekin yillik baza to'lovi kechikkan.
  lifetimeFeeDue('lifetime_fee_due'),

  /// Hisob qo'lda to'xtatilgan.
  suspended('suspended'),

  /// Serverdan tanimaydigan qiymat keldi - xavfsiz tomonga og'amiz.
  unknown('unknown');

  const LicenseState(this.key);

  final String key;

  static LicenseState fromKey(String? key) {
    for (final s in LicenseState.values) {
      if (s.key == key) return s;
    }
    return LicenseState.unknown;
  }
}

/// Serverdan kelgan, imzolangan obuna holati.
///
/// Muddat HAR DOIM serverda hisoblanadi - ilova o'z soatiga qarab qaror
/// qabul qilmaydi. Shu sabab qurilma vaqtini orqaga surib bloklashni
/// chetlab o'tib bo'lmaydi.
class LicenseStatus {
  const LicenseStatus({
    required this.tenantId,
    required this.state,
    required this.planId,
    required this.kind,
    required this.expiresAt,
    required this.daysLeft,
    required this.checkedAt,
    required this.ttlSeconds,
    required this.message,
    required this.blocked,
  });

  final String tenantId;
  final LicenseState state;
  final String planId;

  /// `trial` | `subscription` | `lifetime`.
  final String kind;

  /// Muddat tugash vaqti (ms). Bir umrlik uchun `null`.
  final int? expiresAt;

  /// Muddat tugashiga necha kun qolgani (manfiy - necha kun o'tgani).
  final int? daysLeft;

  /// SERVER vaqti (ms) - javob qachon yaratilgani.
  final int checkedAt;

  /// Javob qancha vaqt yaroqli - oflayn ishlash oynasi.
  final int ttlSeconds;

  /// Foydalanuvchiga ko'rsatiladigan tayyor xabar.
  final String message;

  /// `true` bo'lsa ilova ish ekranlarini bloklaydi.
  final bool blocked;

  /// Keshdagi javob qachongacha yaroqli (ms).
  int get validUntil => checkedAt + ttlSeconds * 1000;

  bool get isLifetime => kind == 'lifetime';
  bool get isTrial => kind == 'trial';

  /// Muddat tugashiga oz qolganda ogohlantirish ko'rsatiladimi.
  bool get needsWarning =>
      state == LicenseState.expiring ||
      state == LicenseState.grace ||
      state == LicenseState.lifetimeFeeDue;

  factory LicenseStatus.fromJson(Map<String, dynamic> json) {
    return LicenseStatus(
      tenantId: json['tenantId'] as String? ?? '',
      state: LicenseState.fromKey(json['state'] as String?),
      planId: json['planId'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      expiresAt: (json['expiresAt'] as num?)?.toInt(),
      daysLeft: (json['daysLeft'] as num?)?.toInt(),
      checkedAt: (json['checkedAt'] as num?)?.toInt() ?? 0,
      ttlSeconds: (json['ttlSeconds'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      // Noma'lum javobda xavfsiz tomon - bloklash.
      blocked: json['blocked'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'tenantId': tenantId,
        'state': state.key,
        'planId': planId,
        'kind': kind,
        'expiresAt': expiresAt,
        'daysLeft': daysLeft,
        'checkedAt': checkedAt,
        'ttlSeconds': ttlSeconds,
        'message': message,
        'blocked': blocked,
      };

  /// Imzolanadigan matn.
  ///
  /// Maydonlar ANIQ tartibda birlashtiriladi (JSON emas) - kalitlar
  /// tartibi o'zgarib, ilova va server turli natija olmasligi uchun.
  /// Server tomonidagi `canonical()` bilan bir xil bo'lishi SHART
  /// (backend/src/services/license.ts).
  String get canonical => [
        tenantId,
        state.key,
        planId,
        kind,
        expiresAt ?? '',
        daysLeft ?? '',
        checkedAt,
        ttlSeconds,
        blocked ? '1' : '0',
      ].join('|');
}

/// Serverdan kelgan javobning imzosini tekshiradi.
///
/// DIQQAT: kalit ilova ichida bo'ladi, ya'ni uni APK'dan ajratib olish
/// mumkin. Shuning uchun bu tekshiruv faqat "javob yo'lda
/// o'zgartirilmadimi" degan savolga javob beradi. Haqiqiy himoya
/// serverda: holatni faqat server hisoblaydi va `license` tuguniga
/// mijoz yoza olmaydi (Database qoidalari).
bool verifyLicenseSignature({
  required LicenseStatus status,
  required String signature,
  required String signingKey,
}) {
  if (signingKey.isEmpty || signature.isEmpty) return false;

  final digest = Hmac(sha256, utf8.encode(signingKey))
      .convert(utf8.encode(status.canonical));

  // Node `digest('base64url')` to'ldiruvchi `=` belgilarini qo'ymaydi,
  // Dart esa qo'yadi - shuning uchun ularni olib tashlaymiz.
  final expected = base64Url.encode(digest.bytes).replaceAll('=', '');

  return _constantTimeEquals(expected, signature);
}

/// Uzunligi teng satrlarni doimiy vaqtda solishtiradi.
///
/// Oddiy `==` birinchi farqda to'xtaydi - nazariy jihatdan javob vaqtiga
/// qarab imzoni bitta-bitta topib olish mumkin.
bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}
