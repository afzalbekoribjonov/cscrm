import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/license_status.dart';
import '../utils/license_clock.dart';
import 'api_client.dart';

/// Obuna holatini aniqlash natijasi.
class LicenseResolution {
  const LicenseResolution({
    required this.status,
    required this.fromCache,
    this.error,
  });

  /// Aniqlangan holat. Hech narsa aniqlanmasa `null`.
  final LicenseStatus? status;

  /// Javob serverdan emas, keshdan olindimi.
  final bool fromCache;

  /// Serverga murojaat qilib bo'lmagan bo'lsa — sababi.
  final String? error;

  /// Ish ekranlari bloklanadimi.
  ///
  /// Holat umuman aniqlanmagan bo'lsa BLOKLAMAYMIZ: bu odatda birinchi
  /// ishga tushirish yoki tarmoq muammosi bo'ladi, va biznesni ishdan
  /// to'xtatib qo'yish xatolikdan ko'ra qimmatroq. Server javob berganda
  /// haqiqiy holat baribir qo'llanadi.
  bool get blocked => status?.blocked ?? false;
}

/// Bitta to'lov kartasi.
///
/// [type] serverda RAQAMDAN aniqlanadi (9860 - Humo, 8600/5614 - Uzcard),
/// shuning uchun yorliq raqamga har doim mos keladi.
class PaymentCardInfo {
  const PaymentCardInfo({required this.number, required this.type});

  final String number;

  /// "Humo" · "Uzcard" · aniqlanmasa bo'sh satr.
  final String type;

  /// Ro'yxatda ko'rsatiladigan sarlavha.
  String get label => type.isEmpty ? 'Karta raqami' : '$type kartasi';

  factory PaymentCardInfo.fromJson(Map<String, dynamic> json) =>
      PaymentCardInfo(
        number: json['number'] as String? ?? '',
        type: json['type'] as String? ?? '',
      );
}

/// To'lov ma'lumotlari (serverdan keladi, ilovada qattiq yozilmagan).
class PaymentInfo {
  const PaymentInfo({
    required this.cards,
    required this.cardHolder,
    required this.phone,
    required this.email,
    required this.telegram,
    required this.note,
    required this.configured,
  });

  /// Bir nechta bo'lishi mumkin - mijoz o'z bankiga mos kartani tanlaydi.
  final List<PaymentCardInfo> cards;

  final String cardHolder;
  final String phone;
  final String email;
  final String telegram;
  final String note;

  /// Server tomonida to'lov ma'lumotlari to'ldirilganmi.
  final bool configured;

  static const empty = PaymentInfo(
    cards: [],
    cardHolder: '',
    phone: '',
    email: '',
    telegram: '',
    note: '',
    configured: false,
  );

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['cards'];
    return PaymentInfo(
      cards: [
        if (raw is List)
          for (final c in raw)
            if (c is Map)
              PaymentCardInfo.fromJson(Map<String, dynamic>.from(c)),
      ],
      cardHolder: json['cardHolder'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      telegram: json['telegram'] as String? ?? '',
      note: json['note'] as String? ?? '',
      configured: json['configured'] as bool? ?? false,
    );
  }
}

/// Reja (narxlar sahifasi uchun).
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.kind,
    required this.months,
    required this.highlight,
    this.lifetimeAnnualFeeUsd,
  });

  final String id;
  final String name;
  final double price;
  final String description;
  final String kind;
  final int? months;
  final bool highlight;
  final num? lifetimeAnnualFeeUsd;

  bool get isTrial => kind == 'trial';

  /// Narx hali belgilanmagan (server `plans.json` da 0 turibdi).
  bool get priceUnset => !isTrial && price <= 0;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        kind: json['kind'] as String? ?? 'subscription',
        months: (json['months'] as num?)?.toInt(),
        highlight: json['highlight'] as bool? ?? false,
        lifetimeAnnualFeeUsd: json['lifetimeAnnualFeeUsd'] as num?,
      );
}

/// Biznes yuborgan "men to'ladim" so'rovi.
///
/// To'lov usuli qo'lda karta o'tkazma — bank bizga hech narsa aytmaydi.
/// Shu sabab mijoz o'zi xabar beradi, super-admin esa uni tasdiqlaydi.
class PaymentRequest {
  const PaymentRequest({
    required this.id,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.createdAt,
    required this.status,
    this.reference,
    this.note,
    this.rejectReason,
  });

  final String id;
  final String planId;
  final String planName;
  final double amount;
  final int createdAt;

  /// `pending` · `approved` · `rejected`
  final String status;

  final String? reference;
  final String? note;
  final String? rejectReason;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory PaymentRequest.fromJson(Map<String, dynamic> json) => PaymentRequest(
        id: json['id'] as String? ?? '',
        planId: json['planId'] as String? ?? '',
        planName: json['planName'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        status: json['status'] as String? ?? 'pending',
        reference: json['reference'] as String?,
        note: json['note'] as String?,
        rejectReason: json['rejectReason'] as String?,
      );
}

/// Obuna holatini olib keladi, imzosini tekshiradi va keshlaydi.
class LicenseService {
  LicenseService({ApiClient? api, SharedPreferences? prefs})
      : _api = api ?? ApiClient.instance,
        _prefs = prefs;

  final ApiClient _api;
  SharedPreferences? _prefs;

  static const _kPayload = 'license_payload';
  static const _kSignature = 'license_signature';
  static const _kServerTime = 'license_server_time';

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Holatni aniqlaydi: avval serverdan, bo'lmasa keshdan.
  ///
  /// [tenantId] — keshning boshqa biznesga tegishli emasligini tekshirish
  /// uchun. Bir qurilmada ikki xil biznesga kirilsa, birinchisining
  /// holati ikkinchisiga o'tib ketmasligi kerak.
  Future<LicenseResolution> resolve({required String tenantId}) async {
    try {
      final status = await fetch();
      await _cache(status);
      return LicenseResolution(status: status, fromCache: false);
    } catch (e) {
      debugPrint('Obuna holatini serverdan olib bo\'lmadi: $e');
      final cached = await _readCache(tenantId: tenantId);
      return LicenseResolution(
        status: cached,
        fromCache: true,
        error: e is ApiException ? e.message : 'Serverga ulanib bo\'lmadi.',
      );
    }
  }

  /// Serverdan holatni oladi va imzosini tekshiradi.
  Future<LicenseStatus> fetch() async {
    final response = await _api.get('/api/v1/license/status');

    final payload = response['payload'];
    final signature = response['signature'];
    if (payload is! Map || signature is! String) {
      throw ApiException('Serverdan tushunarsiz javob keldi.');
    }

    final status = LicenseStatus.fromJson(Map<String, dynamic>.from(payload));

    // Imzo kalit berilgandagina tekshiriladi. Kalit sozlanmagan bo'lsa
    // (masalan ishlab chiqish paytida) javobga ishonaveramiz - aks holda
    // ilova umuman ishlamay qolardi. Ishlab chiqarishda kalit doim beriladi.
    if (AppConfig.licenseSigningKey.isNotEmpty) {
      final valid = verifyLicenseSignature(
        status: status,
        signature: signature,
        signingKey: AppConfig.licenseSigningKey,
      );
      if (!valid) {
        throw ApiException(
          'Obuna javobining imzosi to\'g\'ri kelmadi. '
          'Ilovani yangilang yoki yordam xizmatiga murojaat qiling.',
          code: 'bad_signature',
        );
      }
    }

    return status;
  }

  /// Rejalar va to'lov ma'lumotlari (to'lov ekrani uchun).
  Future<({List<SubscriptionPlan> plans, PaymentInfo payment})>
      fetchPlans() async {
    final response = await _api.get('/api/v1/license/plans', withAuth: false);
    final rawPlans = response['plans'];
    final rawPayment = response['payment'];

    return (
      plans: [
        if (rawPlans is List)
          for (final p in rawPlans)
            if (p is Map)
              SubscriptionPlan.fromJson(Map<String, dynamic>.from(p)),
      ],
      payment: rawPayment is Map
          ? PaymentInfo.fromJson(Map<String, dynamic>.from(rawPayment))
          : PaymentInfo.empty,
    );
  }

  // -------------------------------------------------------------------
  // To'lov so'rovi
  // -------------------------------------------------------------------

  /// "Men to'ladim, tekshiring" xabarini yuboradi.
  ///
  /// Bu obunani UZAYTIRMAYDI — so'rov super-admin navbatiga tushadi va
  /// odam tasdiqlaydi.
  Future<PaymentRequest> submitPaymentRequest({
    required String planId,
    double? amount,
    String? reference,
    String? note,
  }) async {
    final response = await _api.post(
      '/api/v1/license/payment-request',
      body: {
        'planId': planId,
        if (amount != null) 'amount': amount,
        if (reference != null && reference.trim().isNotEmpty)
          'reference': reference.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    final raw = response['request'];
    if (raw is! Map) throw ApiException('Serverdan tushunarsiz javob keldi.');

    return PaymentRequest.fromJson({
      ...Map<String, dynamic>.from(raw),
      'id': response['requestId'],
    });
  }

  /// Oxirgi so'rov holati. So'rov bo'lmasa `null`.
  ///
  /// Xodim ham chaqira oladi — bloklangan ekranda "rahbar to'lov haqida
  /// xabar bergan" deb ko'rsatish uchun.
  Future<PaymentRequest?> fetchPaymentRequest() async {
    final response = await _api.get('/api/v1/license/payment-request');
    final raw = response['request'];
    if (raw is! Map) return null;
    return PaymentRequest.fromJson(Map<String, dynamic>.from(raw));
  }

  // -------------------------------------------------------------------
  // Kesh
  // -------------------------------------------------------------------

  Future<void> _cache(LicenseStatus status) async {
    final prefs = await _store;
    await prefs.setString(_kPayload, jsonEncode(status.toJson()));
    await prefs.setInt(_kServerTime, status.checkedAt);
  }

  /// Keshdagi holatni o'qiydi. Muddati o'tgan yoki boshqa biznesga
  /// tegishli bo'lsa `null`.
  Future<LicenseStatus?> _readCache({required String tenantId}) async {
    final prefs = await _store;
    final raw = prefs.getString(_kPayload);
    if (raw == null) return null;

    LicenseStatus cached;
    try {
      cached = LicenseStatus.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (e) {
      debugPrint('Keshlangan obuna holati o\'qilmadi: $e');
      return null;
    }

    if (cached.tenantId != tenantId) return null;

    final now = effectiveNow(
      deviceNow: DateTime.now().millisecondsSinceEpoch,
      lastServerTime: prefs.getInt(_kServerTime) ?? 0,
    );

    if (!isCacheUsable(validUntil: cached.validUntil, now: now)) {
      // Oflayn oyna tugadi. Bu holatda ham BLOKLAMAYMIZ - shunchaki
      // "holat noma'lum" deb qaytaramiz; qaror qabul qilish chaqiruvchida.
      return null;
    }
    return cached;
  }

  /// Chiqishda chaqiriladi — keyingi foydalanuvchi oldingi biznesning
  /// holatini ko'rib qolmasligi uchun.
  Future<void> clearCache() async {
    final prefs = await _store;
    await prefs.remove(_kPayload);
    await prefs.remove(_kSignature);
    await prefs.remove(_kServerTime);
  }
}
