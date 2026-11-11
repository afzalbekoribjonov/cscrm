// lib/l10n/material_cyrillic.dart ni yaratadi.
//
// Flutter'ning o'zbek (lotin) Material tarjimasidagi har bir matnni
// kirillga o'giradigan voris sinf. Qo'lda yozilmaydi: Flutter versiyasi
// yangilanib, yangi matn qo'shilsa — shu skript qayta ishga tushiriladi.
//
//   node tool/gen_material_cyrillic.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { join } from 'node:path';

const flutterRoot = process.env.FLUTTER_ROOT ??
  execSync('flutter --version --machine', { encoding: 'utf8', shell: true })
    .match(/"flutterRoot":\s*"([^"]+)"/)[1].replace(/\\\\/g, '/');
const src = readFileSync(
  join(flutterRoot, 'packages/flutter_localizations/lib/src/l10n/generated_material_localizations.dart'),
  'utf8',
).split('\r\n').join('\n'); // Windows'da SDK fayllari CRLF bilan bo'lishi mumkin

const start = src.indexOf('class MaterialLocalizationUz extends GlobalMaterialLocalizations');
const end = src.indexOf('\n}\n', start);
const body = src.slice(start, end);

// Matn emas yoki o'girilishi kerak bo'lmaganlar.
const skip = new Set([
  'anteMeridiemAbbreviation', 'postMeridiemAbbreviation', 'dateHelpText',
  'keyboardKeyAlt', 'keyboardKeyAltGraph', 'keyboardKeyBackspace', 'keyboardKeyCapsLock',
  'keyboardKeyChannelDown', 'keyboardKeyChannelUp', 'keyboardKeyControl', 'keyboardKeyDelete',
  'keyboardKeyEject', 'keyboardKeyEnd', 'keyboardKeyEscape', 'keyboardKeyFn', 'keyboardKeyHome',
  'keyboardKeyInsert', 'keyboardKeyMeta', 'keyboardKeyMetaMacOs', 'keyboardKeyMetaWindows',
  'keyboardKeyNumLock', 'keyboardKeyNumpad1', 'keyboardKeyNumpad2', 'keyboardKeyNumpad3',
  'keyboardKeyNumpad4', 'keyboardKeyNumpad5', 'keyboardKeyNumpad6', 'keyboardKeyNumpad7',
  'keyboardKeyNumpad8', 'keyboardKeyNumpad9', 'keyboardKeyNumpad0', 'keyboardKeyNumpadAdd',
  'keyboardKeyNumpadComma', 'keyboardKeyNumpadDecimal', 'keyboardKeyNumpadDivide',
  'keyboardKeyNumpadEnter', 'keyboardKeyNumpadEqual', 'keyboardKeyNumpadMultiply',
  'keyboardKeyNumpadParenLeft', 'keyboardKeyNumpadParenRight', 'keyboardKeyNumpadSubtract',
  'keyboardKeyPageDown', 'keyboardKeyPageUp', 'keyboardKeyPower', 'keyboardKeyPowerOff',
  'keyboardKeyPrintScreen', 'keyboardKeyScrollLock', 'keyboardKeySelect', 'keyboardKeyShift',
  'keyboardKeySpace',
]);

const getters = [...body.matchAll(/String\??\s+get\s+(\w+)\s*=>/g)]
  .map((m) => m[1])
  .filter((name) => !skip.has(name));

const lines = [];
lines.push(`// AVTOMATIK YARATILGAN — qo'lda tahrirlamang.`);
lines.push(`// Manba: tool/gen_material_cyrillic.mjs (Flutter o'zbek tarjimasidan).`);
lines.push(`// ignore_for_file: public_member_api_docs`);
lines.push(``);
lines.push(`import 'package:flutter/foundation.dart';`);
lines.push(`import 'package:flutter/material.dart';`);
lines.push(`import 'package:flutter_localizations/flutter_localizations.dart';`);
lines.push(`import 'package:intl/intl.dart' as intl;`);
lines.push(``);
lines.push(`import 'transliterate.dart';`);
lines.push(``);
lines.push(`/// \`$nom\` ko'rinishidagi o'rinbosarlarni buzmasdan o'giradi.`);
lines.push(`String _template(String raw) => raw.splitMapJoin(`);
lines.push(`      RegExp(r'\\$\\w+|\\$\\{\\w+\\}'),`);
lines.push(`      onMatch: (m) => m[0]!,`);
lines.push(`      onNonMatch: latinToCyrillic,`);
lines.push(`    );`);
lines.push(``);
lines.push(`/// Flutter'ning o'zbek tarjimasi — kirill yozuvida.`);
lines.push(`class MaterialLocalizationUzCyrl extends MaterialLocalizationUz {`);
lines.push(`  const MaterialLocalizationUzCyrl({`);
lines.push(`    required super.fullYearFormat,`);
lines.push(`    required super.compactDateFormat,`);
lines.push(`    required super.shortDateFormat,`);
lines.push(`    required super.mediumDateFormat,`);
lines.push(`    required super.longDateFormat,`);
lines.push(`    required super.yearMonthFormat,`);
lines.push(`    required super.shortMonthDayFormat,`);
lines.push(`    required super.decimalFormat,`);
lines.push(`    required super.twoDigitZeroPaddedFormat,`);
lines.push(`  });`);
lines.push(``);
for (const name of getters) {
  const fn = name.endsWith('Raw') || name.endsWith('Other') || name.endsWith('One') ||
    name.endsWith('Zero') || name.endsWith('Few') || name.endsWith('Many') || name.endsWith('Two')
    ? '_template'
    : 'latinToCyrillic';
  // Ixtiyoriy (nullable) qiymatlar ham bor.
  const nullable = new RegExp(`String\\?\\s+get\\s+${name}\\s*=>`).test(body);
  lines.push('  @override');
  lines.push(nullable
    ? `  String? get ${name} => super.${name} == null ? null : ${fn}(super.${name}!);`
    : `  String get ${name} => ${fn}(super.${name});`);
  lines.push('');
}
lines.push(`  @override`);
lines.push(`  String formatMonthYear(DateTime date) => latinToCyrillic(super.formatMonthYear(date));`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  String formatMediumDate(DateTime date) => latinToCyrillic(super.formatMediumDate(date));`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  String formatFullDate(DateTime date) => latinToCyrillic(super.formatFullDate(date));`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  String formatShortDate(DateTime date) => latinToCyrillic(super.formatShortDate(date));`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  String formatShortMonthDay(DateTime date) => latinToCyrillic(super.formatShortMonthDay(date));`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  List<String> get narrowWeekdays => super.narrowWeekdays.map(latinToCyrillic).toList();`);
lines.push(`}`);
lines.push(``);
lines.push(`/// Material matnlari kirillda — faqat kirill yozuvi tanlanganda ulanadi.`);
lines.push(`class UzCyrillicMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {`);
lines.push(`  const UzCyrillicMaterialDelegate();`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  bool isSupported(Locale locale) => locale.languageCode == 'uz';`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  Future<MaterialLocalizations> load(Locale locale) {`);
lines.push(`    const name = 'uz';`);
lines.push(`    return SynchronousFuture<MaterialLocalizations>(MaterialLocalizationUzCyrl(`);
lines.push(`      fullYearFormat: intl.DateFormat.y(name),`);
lines.push(`      compactDateFormat: intl.DateFormat('dd.MM.yyyy', name),`);
lines.push(`      shortDateFormat: intl.DateFormat.yMMMd(name),`);
lines.push(`      mediumDateFormat: intl.DateFormat.MMMEd(name),`);
lines.push(`      longDateFormat: intl.DateFormat.yMMMMEEEEd(name),`);
lines.push(`      yearMonthFormat: intl.DateFormat.yMMMM(name),`);
lines.push(`      shortMonthDayFormat: intl.DateFormat.MMMd(name),`);
lines.push(`      decimalFormat: intl.NumberFormat.decimalPattern(name),`);
lines.push(`      twoDigitZeroPaddedFormat: intl.NumberFormat('00', name),`);
lines.push(`    ));`);
lines.push(`  }`);
lines.push(``);
lines.push(`  @override`);
lines.push(`  bool shouldReload(UzCyrillicMaterialDelegate old) => false;`);
lines.push(`}`);
lines.push(``);

writeFileSync(new URL('../lib/l10n/material_cyrillic.dart', import.meta.url), lines.join('\n'));
console.log(`yozildi: lib/l10n/material_cyrillic.dart (${getters.length} ta matn)`);
