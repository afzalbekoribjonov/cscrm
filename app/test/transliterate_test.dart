import 'package:cscrm/l10n/transliterate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lotin → kirill', () {
    final cases = <String, String>{
      // Ilova bo'limlari va asosiy so'zlar.
      'Yangi buyurtma': 'Янги буюртма',
      'Yuvish': 'Ювиш',
      'Qadoqlash': 'Қадоқлаш',
      'Yetgazma': 'Етгазма',
      'Omborxona': 'Омборхона',
      'Deyarli tayyor': 'Деярли тайёр',
      'Tayyor': 'Тайёр',
      'Asosiy': 'Асосий',
      'Hisobot': 'Ҳисобот',
      'Xodimlar': 'Ходимлар',
      'Sozlamalar': 'Созламалар',
      'Ilova qonuniyatlari': 'Илова қонуниятлари',
      // o' / g' — har xil apostrof bilan.
      "O'chirish": 'Ўчириш',
      'Oʻchirish': 'Ўчириш',
      'O‘chirish': 'Ўчириш',
      "Bo'lim": 'Бўлим',
      "G'alaba": 'Ғалаба',
      "bog'": 'боғ',
      "So'm": 'Сўм',
      // yo' — "ё" emas, "йў".
      "Yo'q": 'Йўқ',
      "YO'Q": 'ЙЎҚ',
      "Yo'l": 'Йўл',
      // Tutuq belgisi.
      "Ma'lumot": 'Маълумот',
      "E'tibor": 'Эътибор',
      "san'at": 'санъат',
      // e: so'z boshida va unlidan keyin — э.
      'Eslatma': 'Эслатма',
      'Ertaga': 'Эртага',
      'poeziya': 'поэзия',
      'Bekor qilish': 'Бекор қилиш',
      // sh / ch / ng.
      'Shanba': 'Шанба',
      'Chorshanba': 'Чоршанба',
      'Ming': 'Минг',
      // Rus tilidan kirgan so'zlar.
      'sentabr': 'сентябрь',
      'Yanvar': 'Январь',
      '1 yanvardan': '1 январдан',
      'Sexda': 'Цехда',
      'sex ishi': 'цех иши',
      'Parol': 'Пароль',
      // Brend va qisqartmalar o'zgarmaydi.
      'CSCRM': 'CSCRM',
      'GPS manzil': 'GPS манзил',
      'PIN kod': 'PIN код',
      // Raqam, telefon, № va belgilar o'zgarmaydi.
      '№ 1250': '№ 1250',
      '+998 90 123 45 67': '+998 90 123 45 67',
      '12 500 so\'m': '12 500 сўм',
      '6 m²': '6 м²',
      // Kirill matn tegilmaydi.
      'Абдулла': 'Абдулла',
      'Abdulla Каримов': 'Абдулла Каримов',
    };
    cases.forEach((latin, cyrillic) {
      test('"$latin"', () => expect(latinToCyrillic(latin), cyrillic));
    });

    test('bosh harf saqlanadi', () {
      expect(latinToCyrillic('YANGI'), 'ЯНГИ');
      expect(latinToCyrillic('Yangi'), 'Янги');
      expect(latinToCyrillic('yangi'), 'янги');
    });

    test('qo\'shtirnoq ichidagi so\'z', () {
      expect(latinToCyrillic("'Yuvish' tugmasi"), '‘Ювиш’ тугмаси');
    });
  });

  group('lotin tipografiyasi', () {
    test("o' va g' — ‘ bilan", () {
      expect(latinTypography("O'chirish"), 'O‘chirish');
      expect(latinTypography("bog'"), 'bog‘');
      expect(latinTypography('Oʻzbek'), 'O‘zbek');
    });

    test('tutuq — ’ bilan', () {
      expect(latinTypography("ma'lumot"), 'ma’lumot');
    });

    test('apostrofsiz matn o\'zgarmaydi', () {
      const s = 'Yangi buyurtma 125';
      expect(identical(latinTypography(s), s), isTrue);
    });
  });

  group('qidiruv kaliti', () {
    test('lotin va kirill bir xil kalit beradi', () {
      expect(searchKey('Етгазма'), searchKey('Yetgazma'));
      expect(searchKey('Ўктам'), searchKey("O'ktam"));
      expect(searchKey('Шаҳноза'), searchKey('Shahnoza'));
      expect(searchKey('Абдулла'), 'abdulla');
    });

    test('apostrof turi farq qilmaydi', () {
      expect(searchKey("O'ktam"), searchKey('Oʻktam'));
      expect(searchKey("O'ktam"), searchKey('O‘ktam'));
    });

    test('bo\'shliqlar tekislanadi', () {
      expect(searchKey('  Nodira   opa '), 'nodira opa');
    });
  });
}
