/// Build vaqtida beriladigan sozlamalar.
///
/// Firebase qiymatlari [DefaultFirebaseOptions] da, bu yerda esa qolgan
/// hammasi. Barchasi `--dart-define-from-file=env/dev.json` orqali keladi.
class AppConfig {
  const AppConfig._();

  /// CSCRM API manzili (Render'da turadi).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Litsenziya javobining imzosini tekshirish uchun umumiy maxfiy kalit.
  ///
  /// DIQQAT: bu qiymat ilova ichida bo'ladi, ya'ni uni APK'dan ajratib
  /// olish mumkin. Shuning uchun u faqat "javob yo'lda o'zgartirilmadimi"
  /// degan savolga javob beradi — haqiqiy himoya serverda, chunki
  /// litsenziya holatini faqat server hisoblaydi va `license` tuguniga
  /// mijoz yoza olmaydi (Database qoidalari).
  static const licenseSigningKey = String.fromEnvironment(
    'LICENSE_SIGNING_SECRET',
  );

  /// Server javobini kutish muddati.
  static const requestTimeout = Duration(seconds: 20);

  /// API manzili berilganmi.
  static bool get hasApi => apiBaseUrl.isNotEmpty;
}
