/// "Ilova qonuniyatlari" — biznes egasi belgilaydigan ish qoidalari.
///
/// Bazada `tenants/{id}/settings/policies` da saqlanadi. Har bir maydon
/// ixtiyoriy: yozilmagan qiymat STANDART qiymatni oladi va standart
/// qiymatlar ilovaning shu paytgacha bo'lgan xatti-harakatini aynan
/// takrorlaydi — sozlama hech qachon ochilmagan biznesda hech narsa
/// o'zgarmaydi.
class BusinessPolicies {
  const BusinessPolicies({
    this.deadlineDays = 3,
    this.deadlineRequired = true,
    this.addressRequired = false,
    this.pickupGpsRequired = false,
    this.debtAllowed = true,
    this.measureBeforeWash = false,
    this.measureBeforePackaging = true,
    this.rewashReasonRequired = true,
    this.partialHandoverEnabled = true,
    this.warehouseEnabled = true,
    this.warehouseDays = 15,
  });

  static const defaults = BusinessPolicies();

  /// Topshirish muddati: buyurtma sexga qabul qilingandan necha kun
  /// keyin. Yangi buyurtma oynasida sana shu bo'yicha oldindan
  /// to'ldiriladi. 0 — oldindan belgilanmaydi.
  final int deadlineDays;

  /// Sexga qabul qilishda topshirish sanasi majburiy.
  final bool deadlineRequired;

  /// Yangi buyurtmada manzil majburiy.
  final bool addressRequired;

  /// Olib kelishda GPS manzilni saqlash majburiy ("Qabul qilindi" shundan
  /// keyin ochiladi).
  final bool pickupGpsRequired;

  /// To'lov to'liq olinmasa, farqni qarz sifatida yozishga ruxsat.
  final bool debtAllowed;

  /// Yuvishni boshlashdan oldin o'lchash majburiy.
  final bool measureBeforeWash;

  /// Qadoqlashga o'tkazishdan oldin o'lchash majburiy.
  final bool measureBeforePackaging;

  /// Qayta yuvishga qaytarishda sabab yozish majburiy.
  final bool rewashReasonRequired;

  /// Tayyor xizmatlarni buyurtmaning qolganidan oldin topshirish mumkin.
  final bool partialHandoverEnabled;

  /// Uzoq olib ketilmagan tayyor buyurtmalar "Omborxona"ga o'tadi.
  final bool warehouseEnabled;

  /// Tayyor bo'lganidan necha kun o'tgach buyurtma omborxonaga o'tadi.
  final int warehouseDays;

  static const deadlineDaysRange = (min: 0, max: 30);
  static const warehouseDaysRange = (min: 3, max: 90);

  factory BusinessPolicies.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return defaults;
    bool flag(String key, bool fallback) {
      final v = map[key];
      return v is bool ? v : fallback;
    }

    int number(String key, int fallback, ({int min, int max}) range) {
      final v = map[key];
      if (v is! num) return fallback;
      final n = v.toInt();
      if (n < range.min) return range.min;
      if (n > range.max) return range.max;
      return n;
    }

    const d = defaults;
    return BusinessPolicies(
      deadlineDays: number('deadlineDays', d.deadlineDays, deadlineDaysRange),
      deadlineRequired: flag('deadlineRequired', d.deadlineRequired),
      addressRequired: flag('addressRequired', d.addressRequired),
      pickupGpsRequired: flag('pickupGpsRequired', d.pickupGpsRequired),
      debtAllowed: flag('debtAllowed', d.debtAllowed),
      measureBeforeWash: flag('measureBeforeWash', d.measureBeforeWash),
      measureBeforePackaging:
          flag('measureBeforePackaging', d.measureBeforePackaging),
      rewashReasonRequired: flag('rewashReasonRequired', d.rewashReasonRequired),
      partialHandoverEnabled:
          flag('partialHandoverEnabled', d.partialHandoverEnabled),
      warehouseEnabled: flag('warehouseEnabled', d.warehouseEnabled),
      warehouseDays:
          number('warehouseDays', d.warehouseDays, warehouseDaysRange),
    );
  }

  Map<String, Object> toMap() => {
        'deadlineDays': deadlineDays,
        'deadlineRequired': deadlineRequired,
        'addressRequired': addressRequired,
        'pickupGpsRequired': pickupGpsRequired,
        'debtAllowed': debtAllowed,
        'measureBeforeWash': measureBeforeWash,
        'measureBeforePackaging': measureBeforePackaging,
        'rewashReasonRequired': rewashReasonRequired,
        'partialHandoverEnabled': partialHandoverEnabled,
        'warehouseEnabled': warehouseEnabled,
        'warehouseDays': warehouseDays,
      };

  BusinessPolicies copyWith({
    int? deadlineDays,
    bool? deadlineRequired,
    bool? addressRequired,
    bool? pickupGpsRequired,
    bool? debtAllowed,
    bool? measureBeforeWash,
    bool? measureBeforePackaging,
    bool? rewashReasonRequired,
    bool? partialHandoverEnabled,
    bool? warehouseEnabled,
    int? warehouseDays,
  }) =>
      BusinessPolicies(
        deadlineDays: deadlineDays ?? this.deadlineDays,
        deadlineRequired: deadlineRequired ?? this.deadlineRequired,
        addressRequired: addressRequired ?? this.addressRequired,
        pickupGpsRequired: pickupGpsRequired ?? this.pickupGpsRequired,
        debtAllowed: debtAllowed ?? this.debtAllowed,
        measureBeforeWash: measureBeforeWash ?? this.measureBeforeWash,
        measureBeforePackaging:
            measureBeforePackaging ?? this.measureBeforePackaging,
        rewashReasonRequired: rewashReasonRequired ?? this.rewashReasonRequired,
        partialHandoverEnabled:
            partialHandoverEnabled ?? this.partialHandoverEnabled,
        warehouseEnabled: warehouseEnabled ?? this.warehouseEnabled,
        warehouseDays: warehouseDays ?? this.warehouseDays,
      );

  /// Tayyor bo'lgan payt [readyAt] bo'yicha buyurtma omborxonadami.
  bool isInWarehouse(int? readyAt, DateTime now) {
    if (!warehouseEnabled || readyAt == null || readyAt <= 0) return false;
    final limit = DateTime.fromMillisecondsSinceEpoch(readyAt)
        .add(Duration(days: warehouseDays));
    return !now.isBefore(limit);
  }

  @override
  bool operator ==(Object other) =>
      other is BusinessPolicies && _mapEquals(toMap(), other.toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

bool _mapEquals(Map<String, Object> a, Map<String, Object> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (b[e.key] != e.value) return false;
  }
  return true;
}
