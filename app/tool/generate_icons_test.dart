// Logotip PNG fayllarini ILOVANING O'ZIDAGI vidjetdan chiqaradi.
//
// Ishga tushirish (`app/` papkasidan):
//     flutter test tool/generate_icons_test.dart
//
// NEGA `flutter test`: logotipni chizish uchun matnni rasmga aylantirish
// kerak, buni esa Flutter dvigatelining o'zi qiladi. Ilgari bu ish
// `tools/generate_icons.py` da alohida chizilardi — ya'ni logotip IKKI
// joyda, ikki xil kod bilan yasalardi va ular vaqt o'tib bir-biridan
// ajralib ketishi muqarrar edi. Endi manba bitta: `lib/branding/logo.dart`.
//
// Fayl `test/` papkasidan TASHQARIDA turadi — aks holda oddiy
// `flutter test` har safar ikonkalarni qayta yozib yuborardi.

import 'package:cscrm/branding/logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render.dart';

/// Chiqariladigan fayl: yo'l va o'lchami.
typedef _Target = ({String path, int size});

/// Android ilova ikonkasining "xavfsiz doirasi" — adaptiv ikonkada
/// tashqi qism qurilma shakliga qarab kesiladi, shuning uchun matn
/// markazdagi ~60% ga joylashtiriladi.
const _adaptiveSafe = 0.60;

void main() {
  testWidgets('logotip fayllari yangilanadi', (tester) async {
    await loadRenderFont();
    // --- To'liq nishon (plashka + matn) ---
    for (final t in <_Target>[
      (path: 'assets/icon/logo.png', size: 1024),
      (path: 'web/favicon.png', size: 64),
      (path: 'web/icons/Icon-192.png', size: 192),
      (path: 'web/icons/Icon-512.png', size: 512),
      (path: '../admin/public/favicon.png', size: 64),
    ]) {
      await renderToPng(tester, child: CscrmMark(size: t.size.toDouble()), path: t.path, size: Size(t.size.toDouble(), t.size.toDouble()));
    }

    // --- Maskalanadigan ikonka ---
    // Brauzer uni doira yoki boshqa shaklga kesishi mumkin, shuning
    // uchun matn kichikroq va chetlarda bo'sh joy qoldiriladi.
    for (final t in <_Target>[
      (path: 'web/icons/Icon-maskable-192.png', size: 192),
      (path: 'web/icons/Icon-maskable-512.png', size: 512),
    ]) {
      await renderToPng(
        tester,
        path: t.path,
        size: Size(t.size.toDouble(), t.size.toDouble()),
        child:         Container(
          width: t.size.toDouble(),
          height: t.size.toDouble(),
          color: LogoColors.badge,
          alignment: Alignment.center,
          child: CscrmMark(size: t.size * _adaptiveSafe, rounded: 0),
        ),
      );
    }

    // --- Android adaptiv ikonkaning old qatlami ---
    // Fon alohida qatlam (pubspec'dagi `adaptive_icon_background`),
    // shuning uchun bu yerda faqat matn — foni shaffof.
    for (final t in <_Target>[
      (path: 'assets/icon/logo_foreground.png', size: 1024),
      (path: 'android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png', size: 108),
      (path: 'android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png', size: 162),
      (path: 'android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png', size: 216),
      (path: 'android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png', size: 324),
      (path: 'android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png', size: 432),
    ]) {
      await renderToPng(
        tester,
        path: t.path,
        size: Size(t.size.toDouble(), t.size.toDouble()),
        child:         SizedBox(
          width: t.size.toDouble(),
          height: t.size.toDouble(),
          child: Center(
            // Plashka bu yerda ATAYLAB chizilmaydi: Android uni
            // alohida fon qatlami sifatida o'zi qo'yadi
            // (`pubspec.yaml` dagi `adaptive_icon_background`).
            child: SizedBox.square(
              dimension: t.size * _adaptiveSafe,
              child: const CscrmStackedLetters(),
            ),
          ),
        ),
      );
    }

    // --- Ilova ochilish ekranidagi nishon ---
    for (final t in <_Target>[
      (path: 'android/app/src/main/res/drawable/launch_image.png', size: 216),
      (path: 'android/app/src/main/res/drawable-mdpi/launch_image.png', size: 108),
      (path: 'android/app/src/main/res/drawable-hdpi/launch_image.png', size: 162),
      (path: 'android/app/src/main/res/drawable-xhdpi/launch_image.png', size: 216),
      (path: 'android/app/src/main/res/drawable-xxhdpi/launch_image.png', size: 324),
      (path: 'android/app/src/main/res/drawable-xxxhdpi/launch_image.png', size: 432),
    ]) {
      await renderToPng(tester, child: CscrmMark(size: t.size.toDouble()), path: t.path, size: Size(t.size.toDouble(), t.size.toDouble()));
    }
  });
}

