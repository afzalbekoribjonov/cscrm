// Vidjetni PNG faylga chizadigan umumiy yordamchi.
//
// Ikki joy ishlatadi:
//   * `generate_icons_test.dart` — ilova ikonkalari
//   * `screenshots_test.dart`    — ekranlarni ko'z bilan tekshirish
//
// Ikkalasi ham `flutter test` orqali ishlaydi, chunki matnni rasmga
// aylantirishni faqat Flutter dvigateli qila oladi.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cscrm/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sinov muhitida matn uchun ishlatiladigan shrift oilasi — ilovaning
/// O'ZINIKI.
const renderFont = AppFonts.sans;

/// Material ikonkalari faylini Flutter SDK'sidan topadi (zaxira yo'l).
File? _sdkFont(String file) {
  // `dart.exe` SDK ichida: <flutter>/bin/cache/dart-sdk/bin/dart.exe
  final dartBin = File(Platform.resolvedExecutable).parent; // .../bin
  final candidates = <String>[
    '${dartBin.parent.parent.path}/artifacts/material_fonts/$file',
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts/$file',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (f.existsSync()) return f;
  }
  return null;
}

/// Ilovaning barcha shriftlarini sinov muhitiga yuklaydi.
///
/// NEGA KERAK: `flutter test` haqiqiy shrift o'rniga sinov shriftini
/// qo'yadi — u har bir harfni to'ldirilgan to'rtburchak qilib chizadi.
/// Bu yerda `pubspec.yaml` dagi shriftlar (FontManifest) aynan
/// ilovadagidek yuklanadi — rasm telefondagi ko'rinish bilan bir xil.
Future<void> loadRenderFont() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json'))
      as List<dynamic>;
  var loadedIcons = false;
  for (final entry in manifest) {
    final family = (entry as Map<String, dynamic>)['family'] as String;
    final loader = FontLoader(family);
    for (final font in entry['fonts'] as List<dynamic>) {
      loader.addFont(rootBundle.load((font as Map)['asset'] as String));
    }
    await loader.load();
    if (family == 'MaterialIcons') loadedIcons = true;
  }

  // Material ikonkalari ham shriftdan chiziladi. Usiz rasmda har bir
  // ikonka o'rniga bo'sh kvadrat chiqadi.
  if (!loadedIcons) {
    final icons = _sdkFont('materialicons-regular.otf');
    if (icons != null) {
      await (FontLoader('MaterialIcons')
            ..addFont(
                Future.value(ByteData.view(icons.readAsBytesSync().buffer))))
          .load();
    }
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
  // `pumpAndSettle` ATAYLAB ishlatilmaydi: ba'zi ekranlarda to'xtovsiz
  // animatsiya bor ("Yuvilmoqda" belgisi) — u hech qachon "tinchimaydi".
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Platforma kanallari (SharedPreferences va h.k.) javobini kutamiz.
  //
  // `pumpAndSettle` soxta vaqtni oldinga suradi, lekin kanal javoblari
  // HAQIQIY hodisalar navbatidan keladi. Usiz ekran o'z ma'lumotini
  // yuklashga ulgurmay chizilardi.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump(const Duration(milliseconds: 400));

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
