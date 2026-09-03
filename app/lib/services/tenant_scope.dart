import 'package:firebase_database/firebase_database.dart';

/// Joriy biznes (tenant) doirasi.
///
/// CSCRM ko'p ijarachili: har bir biznesning ma'lumoti
/// `/tenants/{tenantId}/...` ostida alohida turadi. Servislar bazaga
/// TO'G'RIDAN-TO'G'RI murojaat qilmaydi — hammasi shu obyekt orqali
/// o'tadi, shuning uchun bir biznes boshqasining yo'liga tasodifan
/// yozib yubora olmaydi.
///
/// Yo'lning to'g'riligini bazaviy himoya deb hisoblamang: haqiqiy chegara
/// Realtime Database qoidalarida (`auth.token.tenantId`). Bu sinf shunchaki
/// kodni bitta joyda to'plab, xatoni oldini oladi.
class TenantScope {
  TenantScope({required this.tenantId, FirebaseDatabase? database})
      : _db = database ?? FirebaseDatabase.instance;

  final String tenantId;
  final FirebaseDatabase _db;

  /// Shu biznes ildizi.
  DatabaseReference get root => _db.ref('tenants/$tenantId');

  /// Biznes ichidagi yo'l, masalan `ref('orders')`.
  DatabaseReference ref(String path) => _db.ref('tenants/$tenantId/$path');

  // --- Joriy doira ---

  static TenantScope? _current;

  /// Kirish muvaffaqiyatli bo'lgach o'rnatiladi.
  static void activate(TenantScope scope) => _current = scope;

  /// Chiqishda tozalanadi — keyingi foydalanuvchi eski biznes ma'lumotini
  /// ko'rib qolmasligi uchun.
  static void clear() => _current = null;

  static TenantScope? get maybeCurrent => _current;

  /// Joriy doira. Kirilmagan bo'lsa xatolik — bu dasturchi xatosi
  /// (ekran sessiyasiz ochilgan), shuning uchun jim o'tkazib yubormaymiz.
  static TenantScope get current {
    final scope = _current;
    if (scope == null) {
      throw StateError(
        'TenantScope o\'rnatilmagan. Bu ekran faqat tizimga kirgandan '
        'keyin ochilishi kerak.',
      );
    }
    return scope;
  }
}
