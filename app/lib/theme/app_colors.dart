import 'package:flutter/material.dart';

/// CSCRM brend rang palitrasi.
///
/// Asosiy: ishonch va aniqlikni bildiruvchi to'q ko'k (SaaS mahsulot uchun
/// neytral - gilam yuvish, kimyoviy tozalash, kir yuvish, har qanday xizmat
/// biznesiga mos tushadi).
/// Urg'u: diqqatni tortadigan iliq to'q sariq — faqat harakat talab
/// qiladigan joylarda (to'lov, ogohlantirish) ishlatiladi.
abstract class AppColors {
  // --- Brend ---
  /// Nishon gradientining yuqori nuqtasi va asosiy interaktiv rang.
  static const Color brand = Color(0xFF0B5FFF);

  /// Nishon gradientining pastki nuqtasi.
  static const Color brandLight = Color(0xFF00C2FF);

  static const Color primary = brand;
  static const Color primaryDark = Color(0xFF0A4BCC);
  static const Color primaryLight = Color(0xFF7CB2FF);
  static const Color accent = Color(0xFFFF7A45);

  // --- Neytral: yorug' ---
  static const Color bgLight = Color(0xFFF5F8FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFEDF2F9);
  static const Color borderLight = Color(0xFFDFE7F1);
  static const Color textPrimaryLight = Color(0xFF0D1626);
  static const Color textSecondaryLight = Color(0xFF5C6B85);

  // --- Neytral: qorong'i ---
  static const Color bgDark = Color(0xFF080D18);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color surfaceMutedDark = Color(0xFF18223A);
  static const Color borderDark = Color(0xFF25314D);
  static const Color textPrimaryDark = Color(0xFFEBF1FA);
  static const Color textSecondaryDark = Color(0xFF97A6C0);

  // --- Buyurtma bosqichlari (ikkala temada bir xil, urg'u uchun) ---
  static const Color statusPickup = Color(0xFFF59E0B); // olib kelish - amber
  static const Color statusReady = Color(0xFF3B82F6); // ishni boshlash - blue
  static const Color statusWashing = Color(0xFF06B6D4); // yuvishda - cyan
  static const Color statusReadyDelivery =
      Color(0xFF8B5CF6); // yetgazishga tayyor - violet
  static const Color statusDelivered = Color(0xFF22C55E); // yetgazildi - green

  // --- Xabar ranglari ---
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);

  // --- Obuna holati (litsenziya bloki, to'lov ekranlari) ---
  /// Obuna faol, muddat yetarli.
  static const Color licenseActive = success;

  /// Muddat tugashiga oz qoldi - eslatma ko'rsatiladi.
  static const Color licenseExpiring = warning;

  /// Muddat tugagan - ilova bloklanadi.
  static const Color licenseExpired = danger;

  /// Bir umrlik litsenziya - alohida urg'u.
  static const Color licenseLifetime = Color(0xFF7C3AED);

  static const List<Color> brandGradient = [brand, brandLight];
}

/// Tungi rejimda ham to'g'ri ko'rinishi uchun - "Light" bilan tugaydigan
/// AppColors konstantalarini to'g'ridan-to'g'ri ishlatish o'rniga shu
/// getterlar orqali murojaat qilinadi, ular joriy tema (Brightness) ga qarab
/// mos rangni tanlaydi.
extension AppColorsContext on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get colorTextPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get colorTextSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get colorSurface =>
      _isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get colorSurfaceMuted =>
      _isDark ? AppColors.surfaceMutedDark : AppColors.surfaceMutedLight;
  Color get colorBorder =>
      _isDark ? AppColors.borderDark : AppColors.borderLight;
}
