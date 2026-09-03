/// Yuvilgan hajmni statistikada jamlash uchun o'lchov birligi.
///
/// [OrderItem.hajm] - bu odam o'qishi uchun formatlangan matn
/// ("2×3 m (6 m²)"), undan raqam yig'ib bo'lmaydi. Shu sabab har bir
/// xizmatda alohida raqamli [OrderItem.quantity] va shu birlik kaliti
/// saqlanadi.
enum MeasureUnit {
  m2('m2', 'm²', 'Metr kvadrat'),
  metr('metr', 'm', 'Metr'),
  kg('kg', 'kg', 'Kilogramm'),
  dona('dona', 'dona', 'Dona'),
  kichik('kichik', 'dona', 'Kichik o\'lcham'),
  katta('katta', 'dona', 'Katta o\'lcham');

  const MeasureUnit(this.key, this.short, this.label);

  /// Firebase'da saqlanadigan kalit.
  final String key;

  /// Raqam yonida chiqadigan qisqa belgi ("6 m²").
  final String short;

  /// Statistika kartasidagi to'liq nom.
  final String label;

  static MeasureUnit? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final u in MeasureUnit.values) {
      if (u.key == key) return u;
    }
    return null;
  }
}

/// Eski (raqamli maydonlarsiz saqlangan) xizmatlar uchun zaxira yo'l:
/// formatlangan [hajm] matnidan birlik va miqdorni taxminan ajratib
/// oladi. Yangi yozuvlarda bu kerak emas - ular raqamni to'g'ridan-to'g'ri
/// saqlaydi.
({MeasureUnit unit, double quantity})? parseLegacyHajm(String hajm) {
  final text = hajm.trim();
  if (text.isEmpty) return null;

  // "2×3 m (6 m²)" - qavs ichidagi yuza aynan bizga kerak bo'lgan raqam.
  final areaMatch = RegExp(r'\(([\d.]+)\s*m²\)').firstMatch(text);
  if (areaMatch != null) {
    final value = double.tryParse(areaMatch.group(1)!);
    if (value != null) return (unit: MeasureUnit.m2, quantity: value);
  }

  if (text.toLowerCase() == 'katta') {
    return (unit: MeasureUnit.katta, quantity: 1);
  }
  if (text.toLowerCase() == 'kichik') {
    return (unit: MeasureUnit.kichik, quantity: 1);
  }

  // "5 kg" / "3 m" / "1 dona" ko'rinishidagilar.
  final simple = RegExp(r'^([\d.]+)\s*(kg|dona|m)$').firstMatch(text);
  if (simple != null) {
    final value = double.tryParse(simple.group(1)!);
    if (value == null) return null;
    switch (simple.group(2)!) {
      case 'kg':
        return (unit: MeasureUnit.kg, quantity: value);
      case 'dona':
        return (unit: MeasureUnit.dona, quantity: value);
      case 'm':
        return (unit: MeasureUnit.metr, quantity: value);
    }
  }
  return null;
}
