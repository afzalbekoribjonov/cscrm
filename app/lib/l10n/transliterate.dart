/// O'zbek tili uchun yozuv almashtirish: lotin ↔ kirill.
///
/// Ilovaning barcha matni lotin yozuvida yozilgan. Kirill rejimi alohida
/// tarjima fayllarisiz, shu matnning O'ZIDAN quriladi: o'zbek lotin
/// alifbosi kirillga deyarli bir ma'noli o'giriladi. Istisnolar (rus
/// tilidan kirgan so'zlar: "sentabr" → "сентябрь", "sex" → "цех") alohida
/// lug'atda.
///
/// Sof mantiq — Flutter'ga bog'liq emas va to'liq sinovdan o'tadi
/// (test/transliterate_test.dart).
library;

/// Matnda "o'", "g'" va tutuq belgisi o'rnida uchraydigan barcha
/// apostrof turlari. Klaviaturalar har xil belgi beradi — hammasi bir xil
/// tushuniladi.
const _apostrophes = {
  0x27, // '
  0x60, // `
  0xB4, // ´
  0x2BB, // ʻ
  0x2BC, // ʼ
  0x2018, // ‘
  0x2019, // ’
};

bool _isApostrophe(int code) => _apostrophes.contains(code);

bool _isLatinLetter(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

bool _isCyrillicLetter(int c) => c >= 0x400 && c <= 0x4FF;

/// O'zbek lotinidagi "o‘" va "g‘" uchun belgi.
///
/// Rasmiy imlo U+02BB (ʻ) ni talab qiladi, lekin ilovadagi shriftlarning
/// birida u yo'q — boshqa shriftdan olinib "g'alati" ko'rinardi. U+2018
/// (‘) ikkala shriftda bor va ko'rinishi bir xil.
const okinaMark = '‘';

/// Tutuq belgisi ("ma’lumot").
const tutuqMark = '’';

// ---------------------------------------------------------------------------
// Lotin: to'g'ri tipografiya
// ---------------------------------------------------------------------------

/// Lotin matnini to'g'ri belgilar bilan qaytaradi.
///
/// Kodda matnlar oddiy klaviatura apostrofi bilan yozilgan
/// (`'O\'chirish'`). Ekranda esa "O‘chirish" ko'rinishi kerak: oddiy `'`
/// harfdan uzoq turib qoladi va so'zni ikkiga bo'lib ko'rsatadi.
///
///  * o' / g' (har qanday apostrof bilan) → o‘ / g‘
///  * harflar orasidagi boshqa apostrof (tutuq) → ’
///  * so'z oldidagi va ortidagi apostrof — qo'shtirnoq: ‘ … ’
String latinTypography(String input) {
  if (!input.codeUnits.any(_isApostrophe)) return input;
  final u = input.codeUnits;
  final out = StringBuffer();
  for (var i = 0; i < u.length; i++) {
    final c = u[i];
    if (!_isApostrophe(c)) {
      out.writeCharCode(c);
      continue;
    }
    final prev = i > 0 ? u[i - 1] : 0;
    final next = i + 1 < u.length ? u[i + 1] : 0;
    final prevIsLetter = _isLatinLetter(prev);
    final prevLower = prev | 0x20;
    if (prevIsLetter && (prevLower == 0x6F || prevLower == 0x67)) {
      out.write(okinaMark); // o‘ / g‘
    } else if (prevIsLetter && _isLatinLetter(next)) {
      out.write(tutuqMark); // ma’lumot
    } else if (!prevIsLetter && (_isLatinLetter(next) || _isCyrillicLetter(next))) {
      out.write('‘'); // ochiluvchi qo'shtirnoq
    } else {
      out.write('’'); // yopiluvchi qo'shtirnoq
    }
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Lotin → kirill
// ---------------------------------------------------------------------------

const _single = <int, String>{
  0x61: 'а', 0x62: 'б', 0x63: 'ц', 0x64: 'д', 0x66: 'ф', 0x67: 'г',
  0x68: 'ҳ', 0x69: 'и', 0x6A: 'ж', 0x6B: 'к', 0x6C: 'л', 0x6D: 'м',
  0x6E: 'н', 0x6F: 'о', 0x70: 'п', 0x71: 'қ', 0x72: 'р', 0x73: 'с',
  0x74: 'т', 0x75: 'у', 0x76: 'в', 0x77: 'в', 0x78: 'х', 0x7A: 'з',
};

const _vowels = {0x61, 0x65, 0x69, 0x6F, 0x75}; // a e i o u

/// O'zgarmasdan qoladigan so'zlar: brend va qisqartmalar.
const _keepAsIs = {
  'cscrm', 'gps', 'pin', 'id', 'sms', 'qr', 'pdf', 'ok', 'click', 'payme',
  'telegram', 'google', 'android', 'ios', 'wifi', 'ussd', 'uzcard', 'humo',
  'visa', 'mastercard',
};

/// Rus tilidan kirgan so'zlar — harfma-harf o'girilsa xato chiqadi.
///
/// Kalit — so'zning lotin o'zagi (kichik harf, apostrofsiz). Qiymat —
/// `(yakka, qo'shimcha bilan)`: "yanvar" → "январь", "yanvarda" →
/// "январда" (qo'shimcha oldidan yumshatish belgisi tushadi — rasmiy
/// hujjatlardagi imlo: "1 январдан").
const _stems = <String, (String, String)>{
  'yanvar': ('январь', 'январ'),
  'fevral': ('февраль', 'феврал'),
  'aprel': ('апрель', 'апрел'),
  'iyun': ('июнь', 'июн'),
  'iyul': ('июль', 'июл'),
  'sentabr': ('сентябрь', 'сентябр'),
  'sentyabr': ('сентябрь', 'сентябр'),
  'oktabr': ('октябрь', 'октябр'),
  'oktyabr': ('октябрь', 'октябр'),
  'noyabr': ('ноябрь', 'ноябр'),
  'dekabr': ('декабрь', 'декабр'),
  'parol': ('пароль', 'парол'),
  'kalendar': ('календарь', 'календар'),
  'sex': ('цех', 'цех'),
  'tsex': ('цех', 'цех'),
  'litsenziya': ('лицензия', 'лицензия'),
  'aksiya': ('акция', 'акция'),
};

/// O'zakdan keyin kela oladigan qo'shimchalar. Faqat istisno so'zlar
/// uchun tekshiriladi: "sex" + "da" = "цехда", lekin "sexr…" kabi
/// boshqa so'z tasodifan istisnoga tushib qolmaydi.
const _suffixes = {
  '', 'da', 'dan', 'ga', 'ni', 'ning', 'dagi', 'gacha', 'lar', 'larda',
  'lardan', 'larga', 'larni', 'larning', 'dagilar', 'ingiz', 'imiz', 'im',
  'i', 'si', 'ham', 'dek',
};

final _wordPattern = RegExp(
  "[A-Za-z]+(?:['`´ʻʼ‘’][A-Za-z]+)*['`´ʻʼ‘’]?",
);

/// Lotin matnni o'zbek kirill yozuviga o'giradi.
///
/// Kirill harflari, raqamlar va belgilar o'zgarmaydi — matnda allaqachon
/// kirillda yozilgan qism (masalan mijoz ismi) buzilmaydi.
String latinToCyrillic(String input) {
  if (!input.codeUnits.any(_isLatinLetter)) return _quotes(input);
  return _quotes(input.replaceAllMapped(_wordPattern, (m) => _word(m[0]!)));
}

/// So'zga tegishli bo'lmagan apostroflar — qo'shtirnoq.
String _quotes(String input) {
  if (!input.codeUnits.any(_isApostrophe)) return input;
  final u = input.codeUnits;
  final out = StringBuffer();
  for (var i = 0; i < u.length; i++) {
    final c = u[i];
    if (!_isApostrophe(c)) {
      out.writeCharCode(c);
      continue;
    }
    final prev = i > 0 ? u[i - 1] : 0;
    final prevIsLetter = _isLatinLetter(prev) || _isCyrillicLetter(prev) ||
        (prev >= 0x30 && prev <= 0x39);
    out.write(prevIsLetter ? '’' : '‘');
  }
  return out.toString();
}

String _word(String word) {
  final bare = String.fromCharCodes(
    word.codeUnits.where((c) => !_isApostrophe(c)),
  ).toLowerCase();

  // Brend va qisqartma.
  if (_keepAsIs.contains(bare)) return word;

  for (final entry in _stems.entries) {
    if (!bare.startsWith(entry.key)) continue;
    final suffix = bare.substring(entry.key.length);
    if (!_suffixes.contains(suffix)) continue;
    final stem = suffix.isEmpty ? entry.value.$1 : entry.value.$2;
    return _matchCase(word, stem + _letters(suffix, wordStart: false));
  }

  return _letters(word, wordStart: true);
}

/// So'zning bosh harf ko'rinishini natijaga o'tkazadi.
String _matchCase(String source, String result) {
  if (result.isEmpty) return result;
  final letters = source.codeUnits.where(_isLatinLetter).toList();
  if (letters.isEmpty) return result;
  final allUpper =
      letters.length > 1 && letters.every((c) => c >= 0x41 && c <= 0x5A);
  if (allUpper) return result.toUpperCase();
  if (letters.first >= 0x41 && letters.first <= 0x5A) {
    return result[0].toUpperCase() + result.substring(1);
  }
  return result;
}

String _letters(String word, {required bool wordStart}) {
  final out = StringBuffer();
  final u = word.codeUnits;
  var prevVowel = false;
  var atStart = wordStart;

  // So'z butunlay bosh harfda bo'lsa ("YO'Q") — natija ham bosh harfda.
  final letters = u.where(_isLatinLetter).toList();
  final allUpper = letters.length > 1 && letters.every((c) => c <= 0x5A);

  int lowerAt(int i) => i < u.length ? (u[i] | 0x20) : 0;
  bool upperAt(int i) => i < u.length && u[i] >= 0x41 && u[i] <= 0x5A;
  bool apostropheAt(int i) => i < u.length && _isApostrophe(u[i]);

  void emit(String lower, bool upper) {
    out.write(upper || allUpper ? lower.toUpperCase() : lower);
  }

  var i = 0;
  while (i < u.length) {
    final c = u[i];
    final upper = upperAt(i);

    if (_isApostrophe(c)) {
      // Harflar orasidagi apostrof — tutuq (ma'lumot → маълумот). "o'" va
      // "g'" quyida harf bilan birga o'qiladi, bu yerga yetib kelmaydi.
      if (i > 0 && i + 1 < u.length) {
        out.write(allUpper ? 'Ъ' : 'ъ');
      } else {
        out.write('’');
      }
      i++;
      prevVowel = false;
      atStart = false;
      continue;
    }

    final l = c | 0x20;
    final n1 = lowerAt(i + 1);

    // o' / g'
    if ((l == 0x6F || l == 0x67) && apostropheAt(i + 1)) {
      emit(l == 0x6F ? 'ў' : 'ғ', upper);
      prevVowel = l == 0x6F;
      atStart = false;
      i += 2;
      continue;
    }
    // sh / ch
    if ((l == 0x73 || l == 0x63) && n1 == 0x68) {
      emit(l == 0x73 ? 'ш' : 'ч', upper);
      prevVowel = false;
      atStart = false;
      i += 2;
      continue;
    }
    // y + unli: yo → ё (lekin "yo'" → йў), yu → ю, ya → я, ye → е.
    if (l == 0x79) {
      String? pair;
      if (n1 == 0x6F && !apostropheAt(i + 2)) pair = 'ё';
      if (n1 == 0x75) pair = 'ю';
      if (n1 == 0x61) pair = 'я';
      if (n1 == 0x65) pair = 'е';
      if (pair != null) {
        emit(pair, upper);
        prevVowel = true;
        atStart = false;
        i += 2;
        continue;
      }
      emit('й', upper);
      prevVowel = false;
      atStart = false;
      i++;
      continue;
    }
    // e: so'z boshida va unlidan keyin — э, qolgan joyda — е.
    if (l == 0x65) {
      emit(atStart || prevVowel ? 'э' : 'е', upper);
      prevVowel = true;
      atStart = false;
      i++;
      continue;
    }

    final mapped = _single[l];
    if (mapped != null) {
      emit(mapped, upper);
      prevVowel = _vowels.contains(l);
    } else {
      out.writeCharCode(c);
      prevVowel = false;
    }
    atStart = false;
    i++;
  }
  return out.toString();
}

// ---------------------------------------------------------------------------
// Kirill → lotin (qidiruv uchun)
// ---------------------------------------------------------------------------

const _cyrToLat = <int, String>{
  0x430: 'a', 0x431: 'b', 0x432: 'v', 0x433: 'g', 0x434: 'd', 0x435: 'e',
  0x451: 'yo', 0x436: 'j', 0x437: 'z', 0x438: 'i', 0x439: 'y', 0x43A: 'k',
  0x43B: 'l', 0x43C: 'm', 0x43D: 'n', 0x43E: 'o', 0x43F: 'p', 0x440: 'r',
  0x441: 's', 0x442: 't', 0x443: 'u', 0x444: 'f', 0x445: 'x', 0x446: 's',
  0x447: 'ch', 0x448: 'sh', 0x449: 'sh', 0x44A: '', 0x44B: 'i', 0x44C: '',
  0x44D: 'e', 0x44E: 'yu', 0x44F: 'ya', 0x45E: 'o', 0x49B: 'q', 0x493: 'g',
  0x4B3: 'h',
};

/// Qidiruv uchun bir xil ko'rinish: kichik harf, kirill → lotin,
/// apostroflarsiz, ortiqcha bo'shliqsiz.
///
/// Shu tufayli "Етгазма", "Yetgazma" va "yetgazma" bir-biriga mos
/// keladi; "O'ktam" va "Oʻktam" ham.
String searchKey(String input) {
  final runes = input.toLowerCase().runes.toList();
  final out = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (_isApostrophe(r)) continue;
    final mapped = _cyrToLat[r];
    if (mapped == null) {
      out.writeCharCode(r);
      continue;
    }
    // "е" so'z boshida "ye" deb o'qiladi (Етгазма → yetgazma).
    if (r == 0x435) {
      final prev = i > 0 ? runes[i - 1] : 0x20;
      final atStart = !(_isLatinLetter(prev) || _isCyrillicLetter(prev));
      out.write(atStart ? 'ye' : 'e');
      continue;
    }
    out.write(mapped);
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
