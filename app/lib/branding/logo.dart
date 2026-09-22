import 'package:flutter/material.dart';

/// CS CRM logotipi — faqat matn, hech qanday tasvirsiz.
///
/// NEGA FON QORAROQ KO'K. Logotipda "CS" qizil, "CRM" oq. Qizil rang
/// ilovaning asosiy yorqin ko'k foni (#0B5FFF) ustida **o'qilmaydi** —
/// ularning yorug'lik darajasi deyarli teng va kontrast atigi 1,57:1
/// chiqadi (o'qilishi uchun kamida 3:1 kerak). Bu did masalasi emas,
/// o'lchanadigan narsa.
///
/// Shuning uchun logotip foni chuqurroq ko'k (#0B2E77) qilingan: qizil
/// 3,84:1, oq esa 12,56:1 ga chiqadi — ikkalasi ham toza o'qiladi.
/// Ilovaning qolgan qismidagi yorqin ko'k o'zgarishsiz qoladi.
abstract class LogoColors {
  /// Logotip plashkasining foni. Ilovaning `AppColors.brand` idan
  /// ATAYLAB quyuqroq — yuqoridagi izohga qarang.
  static const Color badge = Color(0xFF0B2E77);

  /// "CS" qismi.
  static const Color cs = Color(0xFFFF4D4D);

  /// "CRM" qismi.
  static const Color crm = Color(0xFFFFFFFF);
}

/// Logotip harflarining umumiy uslubi.
///
/// Manfiy `letterSpacing` — harflarni bir-biriga yaqinlashtiradi va
/// matnni yozuvdan LOGOTIPGA aylantiradi. Odatiy oraliqda u shunchaki
/// qalin matnga o'xshab qolardi.
TextStyle _letters(double fontSize, Color color) => TextStyle(
      fontSize: fontSize,
      // `height` birdan KICHIK. Shrift qatori harflarning o'zidan
      // balandroq: u pastga tushadigan (g, y) va yuqoriga chiqadigan
      // harflar uchun joy qoldiradi. Logotipda esa faqat bosh harflar
      // bor — o'sha bo'sh joy ikki qator orasini keraksiz kengaytirib
      // yuborardi.
      height: 0.86,
      fontWeight: FontWeight.w900,
      letterSpacing: -fontSize * 0.035,
      color: color,
    );

/// Kvadrat nishon: "CS" tepada, "CRM" pastda.
///
/// Ikki qatorli, chunki nishon KVADRAT (ilova ikonkasi, splash, kirish
/// ekrani). "CS CRM" bitta qatorda kvadratga sig'ishi uchun harflar
/// juda kichrayib ketardi va telefon ekranidagi ikonkada umuman
/// o'qilmasdi. Gorizontal joylar uchun [CscrmWordmark] bor.
class CscrmMark extends StatelessWidget {
  const CscrmMark({
    super.key,
    this.size = 56,
    this.rounded = 0.225,
  });

  final double size;

  /// Burchak radiusi — o'lchamga nisbatan.
  final double rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: LogoColors.badge,
        borderRadius: BorderRadius.circular(size * rounded),
      ),
      // `alignment` ATAYLAB qo'yilmaydi. U bolaga BO'SH cheklov beradi —
      // shunda `FittedBox` kengaymay, matnni o'z tabiiy o'lchamida
      // qoldiradi va nishon ichida bir chekkada kichkina bo'lib
      // ko'rinadi. Usiz esa bola nishonni to'liq to'ldiradi va matn
      // haqiqatan kattalashadi.
      //
      // `FittedBox` o'zi shrift o'lchamidagi farqlardan himoya qiladi:
      // foydalanuvchi tizim shriftini kattalashtirib qo'ysa ham matn
      // nishondan chiqib ketmaydi.
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: const CscrmStackedLetters(),
      ),
    );
  }
}

/// Plashkasiz, ikki qatorli yozuv: "CS" ustida, "CRM" ostida.
///
/// Ota-vidjet bergan joyni to'liq egallaydi.
///
/// Alohida ajratilgan, chunki uni IKKI joy ishlatadi: [CscrmMark] va
/// ikonka generatori (`tool/generate_icons_test.dart`) — Android
/// adaptiv ikonkasida fon alohida qatlam bo'lgani uchun u faqat
/// yozuvni chizadi. Ikki joyda ikki nusxa bo'lsa, ular vaqt o'tib
/// bir-biridan ajralib ketardi.
class CscrmStackedLetters extends StatelessWidget {
  const CscrmStackedLetters({super.key});

  /// "CS" va "CRM" ning nisbiy o'lchami. Aniq qiymatlar muhim emas —
  /// [FittedBox] hammasini berilgan joyga moslaydi; muhimi ularning
  /// BIR-BIRIGA nisbati.
  static const _csSize = 42.0;
  static const _crmSize = 30.0;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CS', style: _letters(_csSize, LogoColors.cs)),
          const SizedBox(height: _csSize * 0.02),
          Text('CRM', style: _letters(_crmSize, LogoColors.crm)),
        ],
      ),
    );
  }
}

/// Gorizontal so'z belgisi: bitta qatorda "CS CRM".
///
/// AppBar, sayt sarlavhasi va boshqa keng joylar uchun.
class CscrmWordmark extends StatelessWidget {
  const CscrmWordmark({
    super.key,
    this.height = 34,
  });

  /// Plashkaning balandligi. Kengligi matnga qarab o'zi hisoblanadi.
  final double height;

  @override
  Widget build(BuildContext context) {
    final fontSize = height * 0.46;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.30),
      decoration: BoxDecoration(
        color: LogoColors.badge,
        borderRadius: BorderRadius.circular(height * 0.26),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('CS', style: _letters(fontSize, LogoColors.cs)),
            SizedBox(width: fontSize * 0.22),
            Text('CRM', style: _letters(fontSize, LogoColors.crm)),
          ],
        ),
      ),
    );
  }
}
