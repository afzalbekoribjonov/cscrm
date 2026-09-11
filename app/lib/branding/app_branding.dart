/// CSCRM brend va mahsulot konstantalari.
///
/// Ilovada ko'rinadigan NOM, shior va aloqa ma'lumotlari faqat shu yerda
/// yoziladi. Ekranlarda matnni qattiq yozish taqiqlanadi - brend
/// o'zgarganda bitta fayl tahrirlansa kifoya.
class AppBranding {
  const AppBranding._();

  /// Qisqa nom - app bar, splash, login.
  static const name = 'CSCRM';

  /// To'liq nom - hujjatlar, hisobotlar, chek sarlavhasi.
  static const fullName = 'CSCRM — Cleaning Service CRM';

  /// Bir qatorli shior.
  static const tagline = 'Xizmat biznesi uchun boshqaruv tizimi';

  /// Login/splash ostidagi qisqa izoh.
  static const shortDescription =
      'Buyurtma, xodim va moliyani bitta joydan boshqaring';

  /// Rasmiy websayt (marketing + admin panel).
  static const websiteUrl = 'https://cscrm.uz';

  /// Yordam xizmati.
  static const supportPhone = '+998 94 108 09 16';
  static const supportTelegram = 'https://t.me/cscrm_uz';
  static const supportEmail = 'oribjonovafzaliy@gmail.com';

  /// Firebase Auth uchun ichki email domeni. Boshqaruvchi hisobi shu
  /// domenda yaratiladi - foydalanuvchi buni hech qachon ko'rmaydi,
  /// u faqat "login" kiritadi.
  static const authEmailDomain = '@cscrm.local';

  /// Play Store paket nomi - yangilanish havolasi uchun.
  static const androidPackage = 'uz.cscrm.uzafo';
}
