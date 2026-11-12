import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'transliterate.dart';

/// Ilova yozuvi: o'zbek lotin yoki o'zbek kirill.
enum UzScript {
  latin('latin', 'Lotin', 'O‘zbekcha'),
  cyrillic('cyrillic', 'Кирилл', 'Ўзбекча');

  const UzScript(this.key, this.title, this.sample);

  /// Qurilmada saqlanadigan kalit.
  final String key;

  /// Tanlovda ko'rsatiladigan nom — har biri O'Z yozuvida, shunda
  /// foydalanuvchi qaysi biri qanday ko'rinishini darhol ko'radi.
  final String title;
  final String sample;

  static UzScript fromKey(String? key) =>
      key == UzScript.cyrillic.key ? UzScript.cyrillic : UzScript.latin;
}

/// Joriy yozuv. Sozlamalardan almashtiriladi va qurilmada saqlanadi.
///
/// Almashganda ilovaning BUTUN daraxti qayta chiziladi (holat
/// saqlangan holda) — qarang: `main.dart`.
class ScriptController extends ValueNotifier<UzScript> {
  ScriptController._() : super(UzScript.latin);

  static final ScriptController instance = ScriptController._();

  static const _prefsKey = 'ui_script';

  bool get isCyrillic => value == UzScript.cyrillic;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = UzScript.fromKey(prefs.getString(_prefsKey));
    } catch (_) {
      // O'qib bo'lmasa — lotin.
    }
  }

  Future<void> set(UzScript script) async {
    if (script == value) return;
    _cache.clear();
    value = script;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, script.key);
    } catch (_) {
      // Saqlanmasa ham joriy sessiyada ishlayveradi.
    }
  }
}

/// Bir xil matn ro'yxatlarda qayta-qayta chiziladi ("Yuvilmoqda",
/// "so'm") — har safar qaytadan o'girmaslik uchun kichik kesh.
///
/// Kesh qaysi yozuv uchun to'ldirilgani ham yoziladi: yozuv qanday
/// yo'l bilan almashmasin, eski yozuvdagi natija qaytib qolmaydi.
final _cache = <String, String>{};
UzScript? _cacheScript;

/// Matnni joriy yozuvda qaytaradi.
///
/// Ilovadagi barcha foydalanuvchiga ko'rinadigan matn shu orqali o'tadi:
/// `Text` vidjeti buni o'zi qiladi (qarang: `text.dart`), maydon
/// yorlig'i, maslahat (tooltip) kabi oddiy satr kutadigan joylarda esa
/// `t('...')` qo'lda chaqiriladi.
String t(String latin) {
  if (latin.isEmpty) return latin;
  final script = ScriptController.instance.value;
  if (script != _cacheScript) {
    _cache.clear();
    _cacheScript = script;
  }
  final cached = _cache[latin];
  if (cached != null) return cached;
  final result = script == UzScript.cyrillic
      ? latinToCyrillic(latin)
      : latinTypography(latin);
  if (_cache.length > 3000) _cache.clear();
  _cache[latin] = result;
  return result;
}
