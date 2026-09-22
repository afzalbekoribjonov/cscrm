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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:cscrm/branding/logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chiqariladigan fayl: yo'l va o'lchami.
typedef _Target = ({String path, int size});

/// Android ilova ikonkasining "xavfsiz doirasi" — adaptiv ikonkada
/// tashqi qism qurilma shakliga qarab kesiladi, shuning uchun matn
/// markazdagi ~60% ga joylashtiriladi.
const _adaptiveSafe = 0.60;

/// Sinov muhitida matn uchun ishlatiladigan shrift oilasi.
const _font = 'Roboto';

/// Roboto Black faylini Flutter SDK'sidan topadi.
///
/// NEGA KERAK: `flutter test` odatda haqiqiy shrift o'rniga sinov
/// shriftini qo'yadi — u har bir harfni to'ldirilgan to'rtburchak qilib
/// chizadi. Shunday holda ikonkada "CS CRM" o'rniga ikkita rangli
/// to'rtburchak chiqardi.
///
/// Roboto ataylab tanlangan: Android tizim shrifti ham aynan shu, ya'ni
/// ikonkadagi yozuv ilova ichidagi logotip bilan bir xil ko'rinadi.
File? _robotoFile() {
  // `dart.exe` SDK ichida: <flutter>/bin/cache/dart-sdk/bin/dart.exe
  final dartBin = File(Platform.resolvedExecutable).parent; // .../bin
  final candidates = <String>[
    // Dart SDK'dan yuqoriga: bin -> dart-sdk -> cache
    '${dartBin.parent.parent.path}/artifacts/material_fonts/roboto-black.ttf',
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts/roboto-black.ttf',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

void main() {
  testWidgets('logotip fayllari yangilanadi', (tester) async {
    final roboto = _robotoFile();
    if (roboto == null) {
      fail(
        'Roboto shrifti topilmadi. Usiz ikonkada harflar o\'rniga '
        'to\'rtburchaklar chiqadi — shuning uchun jimgina davom etmaymiz.',
      );
    }

    final loader = FontLoader(_font)
      ..addFont(Future.value(
        ByteData.view(roboto.readAsBytesSync().buffer),
      ));
    await loader.load();
    // --- To'liq nishon (plashka + matn) ---
    for (final t in <_Target>[
      (path: 'assets/icon/logo.png', size: 1024),
      (path: 'web/favicon.png', size: 64),
      (path: 'web/icons/Icon-192.png', size: 192),
      (path: 'web/icons/Icon-512.png', size: 512),
      (path: '../admin/public/favicon.png', size: 64),
    ]) {
      await _render(tester, t, CscrmMark(size: t.size.toDouble()));
    }

    // --- Maskalanadigan ikonka ---
    // Brauzer uni doira yoki boshqa shaklga kesishi mumkin, shuning
    // uchun matn kichikroq va chetlarda bo'sh joy qoldiriladi.
    for (final t in <_Target>[
      (path: 'web/icons/Icon-maskable-192.png', size: 192),
      (path: 'web/icons/Icon-maskable-512.png', size: 512),
    ]) {
      await _render(
        tester,
        t,
        Container(
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
      await _render(
        tester,
        t,
        SizedBox(
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
      await _render(tester, t, CscrmMark(size: t.size.toDouble()));
    }
  });
}

/// Vidjetni chizib, PNG qilib saqlaydi.
Future<void> _render(WidgetTester tester, _Target target, Widget child) async {
  final key = GlobalKey();

  tester.view.physicalSize = Size(target.size + 40.0, target.size + 40.0);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      // Logotip vidjeti shrift oilasini ATAYLAB belgilamaydi — ilovada
      // u tizim shriftini oladi. Sinov muhitida esa tizim shrifti yo'q,
      // shuning uchun uni shu yerda beramiz. `Text` o'z uslubini
      // shu asosiy uslub ustiga qo'yadi, ya'ni rang va qalinlik
      // o'zgarmaydi — faqat shrift oilasi qo'shiladi.
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: _font),
        child: Center(
          child: RepaintBoundary(key: key, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // `runAsync` SHART: rasmni kodlash haqiqiy asinxron ish, sinov
  // muhitidagi soxta vaqt bilan u hech qachon tugamasdi.
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });

  final file = File(target.path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('  ${target.path}  ${target.size}x${target.size}');
}
