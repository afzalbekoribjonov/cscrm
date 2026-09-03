import 'package:flutter/material.dart';

/// Mahsulot narxini hisoblash usuli. Har bir mahsulot (Boshqaruvchi >
/// Mahsulotlar) shulardan birini oladi, va buyurtma "Hisoblash" bosqichida
/// shu usulga mos kiritish maydoni ko'rsatiladi.
enum CalculationMethod {
  m2('m2', 'Metr kvadrat', 'm²', Icons.square_foot_rounded),
  dona('dona', 'Soniga', 'dona', Icons.tag_rounded),
  metr('metr', 'Metriga', 'm', Icons.straighten_rounded),
  kg('kg', 'Kilogramm', 'kg', Icons.scale_rounded),
  kichikKatta('kichik_katta', 'Kichik/Katta', '', Icons.format_size_rounded);

  const CalculationMethod(this.key, this.label, this.unitSymbol, this.icon);

  final String key;
  final String label;
  final String unitSymbol;
  final IconData icon;

  /// Kichik/Katta usuli ikkita narx (kichik, katta) talab qiladi;
  /// qolganlari bitta narx (birlik uchun) talab qiladi.
  bool get hasTwoSizes => this == CalculationMethod.kichikKatta;

  static CalculationMethod fromKey(String key) {
    return CalculationMethod.values.firstWhere(
      (m) => m.key == key,
      orElse: () => CalculationMethod.dona,
    );
  }
}
