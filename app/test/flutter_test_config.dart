import 'dart:async';

import 'package:cscrm/l10n/script.dart';

/// Testlardan OLDIN bir marta ishga tushadi (Flutter buni o'zi topadi).
///
/// Ilova matni ekranda to'g'ri tipografiya bilan chiziladi ("Bo‘lim",
/// "ma’lumot"). Sinovlarda ham aynan shu holat — lotin yozuvi — standart.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ScriptController.instance.value = UzScript.latin;
  await testMain();
}
