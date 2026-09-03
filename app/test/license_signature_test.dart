import 'package:cscrm/models/license_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// Imzo tekshiruvi — ILOVA va SERVER bir xil natija berishini tasdiqlaydi.
///
/// Quyidagi imzolar haqiqiy backend kodi (`backend/src/services/license.ts`)
/// tomonidan, shu kalit bilan hosil qilingan. Agar ikkala tomondagi
/// `canonical` formati bir-biridan uzoqlashsa, shu testlar yiqiladi —
/// aks holda xato faqat ishlab chiqarishda, "litsenziya yaroqsiz" degan
/// tushunarsiz xabar ko'rinishida chiqardi.
const _secret = 'cscrm-test-secret-key-32-bytes-min-000000';

LicenseStatus status({
  String tenantId = 'abc123xyz789',
  LicenseState state = LicenseState.expiring,
  String planId = 'm3',
  String kind = 'subscription',
  int? expiresAt = 1767225600000,
  int? daysLeft = 5,
  int checkedAt = 1766793600000,
  int ttlSeconds = 21600,
  bool blocked = false,
}) {
  return LicenseStatus(
    tenantId: tenantId,
    state: state,
    planId: planId,
    kind: kind,
    expiresAt: expiresAt,
    daysLeft: daysLeft,
    checkedAt: checkedAt,
    ttlSeconds: ttlSeconds,
    message: 'Obuna muddati tugashiga 5 kun qoldi.',
    blocked: blocked,
  );
}

void main() {
  group('server imzosi bilan moslik', () {
    test('faol obuna imzosi mos keladi', () {
      expect(
        verifyLicenseSignature(
          status: status(),
          signature: 'dAiHEDWGAGvaPWfNnNDeb7prtFA0yQaMydXRyI60yig',
          signingKey: _secret,
        ),
        isTrue,
        reason: 'Dart va Node bir xil imzo hosil qilishi shart',
      );
    });

    test('bloklangan holat imzosi mos keladi', () {
      expect(
        verifyLicenseSignature(
          status: status(
            state: LicenseState.expired,
            daysLeft: -2,
            blocked: true,
            expiresAt: 1766448000000,
          ),
          signature: 'wO2zdISBD6eQwSk7fpvZ8C3FrwSQ69k-q1uZUF9HYEc',
          signingKey: _secret,
        ),
        isTrue,
      );
    });

    test('null maydonlar (bir umrlik) ham bir xil kodlanadi', () {
      expect(
        verifyLicenseSignature(
          status: status(
            state: LicenseState.active,
            planId: 'lifetime',
            kind: 'lifetime',
            expiresAt: null,
            daysLeft: null,
          ),
          signature: '7Bd3geczCLh9-VUGtUe6EUt8xGp1Iel0bcTAEEc1zFs',
          signingKey: _secret,
        ),
        isTrue,
      );
    });
  });

  group('soxtalashtirishga urinish', () {
    const validSignature = 'wO2zdISBD6eQwSk7fpvZ8C3FrwSQ69k-q1uZUF9HYEc';

    LicenseStatus blockedOne() => status(
          state: LicenseState.expired,
          daysLeft: -2,
          blocked: true,
          expiresAt: 1766448000000,
        );

    test('"bloklanmagan" deb o\'zgartirish aniqlanadi', () {
      final tampered = LicenseStatus(
        tenantId: blockedOne().tenantId,
        state: LicenseState.active,
        planId: blockedOne().planId,
        kind: blockedOne().kind,
        expiresAt: blockedOne().expiresAt,
        daysLeft: blockedOne().daysLeft,
        checkedAt: blockedOne().checkedAt,
        ttlSeconds: blockedOne().ttlSeconds,
        message: blockedOne().message,
        blocked: false,
      );
      expect(
        verifyLicenseSignature(
          status: tampered,
          signature: validSignature,
          signingKey: _secret,
        ),
        isFalse,
      );
    });

    test('muddatni cho\'zishga urinish aniqlanadi', () {
      final tampered = status(
        state: LicenseState.expired,
        daysLeft: -2,
        blocked: true,
        expiresAt: 9999999999999,
      );
      expect(
        verifyLicenseSignature(
          status: tampered,
          signature: validSignature,
          signingKey: _secret,
        ),
        isFalse,
      );
    });

    test('boshqa biznesning javobini ishlatib bo\'lmaydi', () {
      final tampered = status(tenantId: 'boshqa-tenant');
      expect(
        verifyLicenseSignature(
          status: tampered,
          signature: 'dAiHEDWGAGvaPWfNnNDeb7prtFA0yQaMydXRyI60yig',
          signingKey: _secret,
        ),
        isFalse,
      );
    });

    test('noto\'g\'ri kalit bilan tekshiruvdan o\'tmaydi', () {
      expect(
        verifyLicenseSignature(
          status: status(),
          signature: 'dAiHEDWGAGvaPWfNnNDeb7prtFA0yQaMydXRyI60yig',
          signingKey: 'boshqa-kalit-32-bayt-uzunlikda-0000000000',
        ),
        isFalse,
      );
    });
  });

  group('chegaraviy holatlar', () {
    test('bo\'sh imzo rad etiladi', () {
      expect(
        verifyLicenseSignature(
          status: status(),
          signature: '',
          signingKey: _secret,
        ),
        isFalse,
      );
    });

    test('kalit sozlanmagan bo\'lsa rad etiladi', () {
      expect(
        verifyLicenseSignature(
          status: status(),
          signature: 'dAiHEDWGAGvaPWfNnNDeb7prtFA0yQaMydXRyI60yig',
          signingKey: '',
        ),
        isFalse,
      );
    });

    test('kalta imzo yiqilmaydi, faqat false qaytaradi', () {
      expect(
        verifyLicenseSignature(
          status: status(),
          signature: 'qisqa',
          signingKey: _secret,
        ),
        isFalse,
      );
    });
  });

  group('LicenseState', () {
    test('noma\'lum qiymat unknown bo\'ladi', () {
      expect(LicenseState.fromKey('yangi_holat'), LicenseState.unknown);
      expect(LicenseState.fromKey(null), LicenseState.unknown);
    });

    test('javobda blocked bo\'lmasa - xavfsiz tomonga, bloklanadi', () {
      final s = LicenseStatus.fromJson({'tenantId': 't', 'state': 'active'});
      expect(
        s.blocked,
        isTrue,
        reason: 'tushunarsiz javobda ilovani ochiq qoldirish xavfli',
      );
    });
  });
}
