import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Testlardan OLDIN bir marta ishga tushadi (Flutter buni o'zi topadi).
///
/// `google_fonts` shriftni birinchi ishlatilganda internetdan yuklaydi.
/// Testda bu ikki muammo tug'diradi: testlar tarmoqqa bog'lanib qoladi va
/// yuklash muvaffaqiyatsiz tugasa istisno tashlanadi.
///
/// Shu sabab testlarda yuklash o'chiriladi — vidjetlar tizim shrifti
/// bilan chiziladi, bu esa mantiqni tekshirishga hech qanday xalaqit
/// bermaydi.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
