// Vidjetni PNG faylga chizadigan umumiy yordamchi.
//
// Ikki joy ishlatadi:
//   * `generate_icons_test.dart` — ilova ikonkalari
//   * `screenshots_test.dart`    — ekranlarni ko'z bilan tekshirish
//
// Ikkalasi ham `flutter test` orqali ishlaydi, chunki matnni rasmga
// aylantirishni faqat Flutter dvigateli qila oladi.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sinov muhitida matn uchun ishlatiladigan shrift oilasi.
const renderFont = 'Roboto';

/// Roboto faylini Flutter SDK'sidan topadi.
///
/// NEGA KERAK: `flutter test` haqiqiy shrift o'rniga sinov shriftini
/// qo'yadi — u har bir harfni to'ldirilgan to'rtburchak qilib chizadi.
/// Shunday holda rasmda matn o'rniga qora bloklar chiqadi.
///
/// Roboto ataylab tanlangan: Android tizim shrifti ham aynan shu, ya'ni
/// rasmdagi yozuv haqiqiy qurilmadagi bilan bir xil ko'rinadi.
File? _robotoFile(String weightFile) {
  // `dart.exe` SDK ichida: <flutter>/bin/cache/dart-sdk/bin/dart.exe
  final dartBin = File(Platform.resolvedExecutable).parent; // .../bin
  final candidates = <String>[
    '${dartBin.parent.parent.path}/artifacts/material_fonts/$weightFile',
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts/$weightFile',
  ];

  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

/// Shriftlarni sinov muhitiga yuklaydi.
///
/// Ikkitasi yuklanadi:
///   * umumiy matn uchun Roboto (Flutter SDK'dan);
///   * LOGOTIP uchun ilovaning o'z shrifti (`assets/fonts/`) — shunda
///     chizilgan ikonka ilovadagi logotip bilan AYNAN bir xil chiqadi.
///     Ilgari ikonka Roboto bilan chizilar, ilovadagi logotip esa
///     boshqa shriftda edi.
Future<void> loadRenderFont() async {
  const weights = [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
  ];

  final loader = FontLoader(renderFont);
  var found = 0;

  for (final weight in weights) {
    final file = _robotoFile(weight);
    if (file == null) continue;
    found++;
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }

  if (found == 0) {
    fail(
      'Roboto shrifti topilmadi. Usiz rasmda harflar o\'rniga '
      'to\'rtburchaklar chiqadi — shuning uchun jimgina davom etmaymiz.',
    );
  }
  await loader.load();

  final logo = File('assets/fonts/cscrm-logo.ttf');
  if (!logo.existsSync()) {
    fail('Logotip shrifti topilmadi: ${logo.path}');
  }
  await (FontLoader('CscrmLogo')
        ..addFont(Future.value(ByteData.view(logo.readAsBytesSync().buffer))))
      .load();

  // Material ikonkalari ham shriftdan chiziladi. Usiz rasmda har bir
  // ikonka o'rniga bo'sh kvadrat chiqadi va "ikonka noto'g'ri" degan
  // yolg'on taassurot qoladi.
  final icons = _robotoFile('materialicons-regular.otf');
  if (icons != null) {
    await (FontLoader('MaterialIcons')
          ..addFont(
              Future.value(ByteData.view(icons.readAsBytesSync().buffer))))
        .load();
  }
}

/// Vidjetni berilgan o'lchamda chizib, PNG qilib saqlaydi.
Future<void> renderToPng(
  WidgetTester tester, {
  required Widget child,
  required String path,
  required Size size,
  double pixelRatio = 1.0,
}) async {
  final key = GlobalKey();

  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      // Vidjetlar shrift oilasini ATAYLAB belgilamaydi — ilovada ular
      // tizim shriftini oladi. Sinov muhitida tizim shrifti yo'q,
      // shuning uchun uni shu yerda beramiz.
      child: DefaultTextStyle(
        style: const TextStyle(fontFamily: renderFont),
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: size, child: child),
          ),
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
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });

  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('  $path');
}
