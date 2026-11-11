import 'package:flutter/material.dart';

/// CSCRM rang tizimi.
///
/// Uch qatlam:
///  * **Brend** — ko'k: ishonch va aniqlik. Faqat asosiy amal, tanlangan
///    holat va havolalarda.
///  * **Neytral** — fon, sirt, chegara, matn. Ekranning 90% i shu.
///  * **Ma'no ranglari** — buyurtma bosqichlari va xabarlar. Har bir
///    bosqichning o'z rangi bor va u ILOVA BO'YLAB bir xil: "Qadoqlashda"
///    ro'yxatda ham, kartada ham, hisobotda ham binafsha.
///
/// Rang hech qachon yagona belgi emas — yonida doim matn yoki ikonka
/// turadi (rang ko'rmaydiganlar uchun ham tushunarli bo'lishi kerak).
abstract class AppColors {
  // --- Brend ---
  static const Color brand = Color(0xFF0B5FFF);
  static const Color brandLight = Color(0xFF00C2FF);

  static const Color primary = brand;
  static const Color primaryDark = Color(0xFF0A47C2);
  static const Color primaryLight = Color(0xFF7CB2FF);

  /// Asosiy rangning yumshoq foni (tanlangan element, belgi foni).
  static const Color primarySoftLight = Color(0xFFEAF1FF);
  static const Color primarySoftDark = Color(0xFF15254D);

  /// Urg'u — iliq to'q sariq. Faqat diqqat talab qiladigan joyda.
  static const Color accent = Color(0xFFFF7A45);

  // --- Neytral: kunduzgi ---
  static const Color bgLight = Color(0xFFF3F5F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMutedLight = Color(0xFFF0F3F8);
  static const Color borderLight = Color(0xFFE3E8EF);
  static const Color borderStrongLight = Color(0xFFCDD5E0);
  static const Color textPrimaryLight = Color(0xFF0E1726);
  static const Color textSecondaryLight = Color(0xFF5A6577);
  static const Color textTertiaryLight = Color(0xFF8C96A6);

  // --- Neytral: tungi ---
  static const Color bgDark = Color(0xFF0A0F1A);
  static const Color surfaceDark = Color(0xFF121927);
  static const Color surfaceMutedDark = Color(0xFF1A2233);
  static const Color borderDark = Color(0xFF242E42);
  static const Color borderStrongDark = Color(0xFF33405A);
  static const Color textPrimaryDark = Color(0xFFE9EEF6);
  static const Color textSecondaryDark = Color(0xFF9BA7BA);
  static const Color textTertiaryDark = Color(0xFF6F7B90);

  // --- Xabar ranglari ---
  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color success = Color(0xFF16A34A);
  static const Color info = Color(0xFF2563EB);

  // --- Buyurtma bosqichlari (to'ldirish/belgi rangi) ---
  // Matn uchun to'g'ridan-to'g'ri ishlatilmaydi — oq fonda kontrast
  // yetmaydi. Matn rangi: [StageTone.ink].
  static const Color statusPickup = Color(0xFFF59E0B); // olib kelish
  static const Color statusQueued = Color(0xFF6366F1); // navbatda
  static const Color statusWashing = Color(0xFF0EA5E9); // yuvilmoqda
  static const Color statusPackaging = Color(0xFF8B5CF6); // qadoqlashda
  static const Color statusAlmost = Color(0xFF14B8A6); // deyarli tayyor
  static const Color statusReady = Color(0xFF22C55E); // tayyor
  static const Color statusWarehouse = Color(0xFFF97316); // omborda
  static const Color statusDelivered = Color(0xFF64748B); // topshirildi
  static const Color statusRewash = Color(0xFFEF4444); // qayta yuvish

  /// Eski nom — "Yetgazishga tayyor" ilgari binafsha edi. Yangi kodda
  /// [statusPackaging] / [statusReady] ishlatiladi.
  static const Color statusReadyDelivery = statusPackaging;

  // --- Obuna holati ---
  static const Color licenseActive = success;
  static const Color licenseExpiring = warning;
  static const Color licenseExpired = danger;
  static const Color licenseLifetime = Color(0xFF7C3AED);

  static const List<Color> brandGradient = [brand, brandLight];

  /// Bosh sahifa sarlavhasining foni — chuqur ko'kdan brend ko'kiga.
  static const List<Color> heroGradient = [
    Color(0xFF0A2E8A),
    Color(0xFF0B4FE0),
    Color(0xFF1C7BFF),
  ];
}

/// Bitta ma'noli rangning ikki ko'rinishi: to'ldirish (belgi, chiziq,
/// fon) va matn ("ink"). Matn rangi har bir mavzuda alohida tanlangan —
/// kunduzgi oq fonda ham, tungi to'q fonda ham o'qiladigan bo'lishi uchun.
class StageTone {
  const StageTone(this.fill, this.inkLight, this.inkDark);

  final Color fill;
  final Color inkLight;
  final Color inkDark;

  Color ink(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? inkDark : inkLight;

  /// Yumshoq fon — belgi va nishonlar uchun.
  Color soft(BuildContext context) => fill.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.12,
      );

  static const pickup =
      StageTone(AppColors.statusPickup, Color(0xFFB45309), Color(0xFFFBBF24));
  static const queued =
      StageTone(AppColors.statusQueued, Color(0xFF4338CA), Color(0xFFA5B4FC));
  static const washing =
      StageTone(AppColors.statusWashing, Color(0xFF0369A1), Color(0xFF7DD3FC));
  static const packaging = StageTone(
      AppColors.statusPackaging, Color(0xFF6D28D9), Color(0xFFC4B5FD));
  static const almost =
      StageTone(AppColors.statusAlmost, Color(0xFF0F766E), Color(0xFF5EEAD4));
  static const ready =
      StageTone(AppColors.statusReady, Color(0xFF15803D), Color(0xFF86EFAC));
  static const warehouse = StageTone(
      AppColors.statusWarehouse, Color(0xFFC2410C), Color(0xFFFDBA74));
  static const delivered = StageTone(
      AppColors.statusDelivered, Color(0xFF334155), Color(0xFFCBD5E1));
  static const rewash =
      StageTone(AppColors.statusRewash, Color(0xFFB91C1C), Color(0xFFFCA5A5));

  static const danger =
      StageTone(AppColors.danger, Color(0xFFB91C1C), Color(0xFFF87171));
  static const warning =
      StageTone(AppColors.warning, Color(0xFFB45309), Color(0xFFFBBF24));
  static const success =
      StageTone(AppColors.success, Color(0xFF15803D), Color(0xFF4ADE80));
  static const info =
      StageTone(AppColors.info, Color(0xFF1D4ED8), Color(0xFF93C5FD));
  static const brand =
      StageTone(AppColors.primary, Color(0xFF0B5FFF), Color(0xFF8AB4FF));
  static const neutral = StageTone(
      Color(0xFF94A3B8), Color(0xFF475569), Color(0xFFCBD5E1));
}

/// Joriy mavzuga (kun/tun) qarab neytral ranglarni beradi.
extension AppColorsContext on BuildContext {
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  Color get colorBackground =>
      isDarkTheme ? AppColors.bgDark : AppColors.bgLight;
  Color get colorTextPrimary =>
      isDarkTheme ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get colorTextSecondary =>
      isDarkTheme ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get colorTextTertiary =>
      isDarkTheme ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
  Color get colorSurface =>
      isDarkTheme ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get colorSurfaceMuted =>
      isDarkTheme ? AppColors.surfaceMutedDark : AppColors.surfaceMutedLight;
  Color get colorBorder =>
      isDarkTheme ? AppColors.borderDark : AppColors.borderLight;
  Color get colorBorderStrong =>
      isDarkTheme ? AppColors.borderStrongDark : AppColors.borderStrongLight;
  Color get colorPrimarySoft =>
      isDarkTheme ? AppColors.primarySoftDark : AppColors.primarySoftLight;

  /// Asosiy rang MATN sifatida — tungi mavzuda ochroq.
  Color get colorPrimaryInk =>
      isDarkTheme ? const Color(0xFF8AB4FF) : AppColors.primary;
}
