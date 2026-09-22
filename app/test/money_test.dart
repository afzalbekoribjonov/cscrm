import 'package:cscrm/utils/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pul summalari.
///
/// Asosiy talab — uch xonadan keyin ajratgich. Usiz "1320000" va
/// "132000" bir qarashda farq qilmaydi, pul bilan ishlaydigan ilovada
/// esa bu qimmatga tushadi.

/// Sinovda o'qish oson bo'lishi uchun: uzilmaydigan bo'sh joyni
/// ko'rinadigan belgiga almashtiramiz.
String visible(String s) => s.replaceAll(moneyGroupSeparator, '_');

TextEditingValue value(String text, {int? cursor}) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );

void main() {
  group('ko\'rsatish', () {
    test('uch xonadan keyin ajratgich qo\'yiladi', () {
      expect(visible(formatMoney(132456)), '132_456');
      expect(visible(formatMoney(1320000)), '1_320_000');
      expect(visible(formatMoney(999)), '999');
      expect(visible(formatMoney(1000)), '1_000');
    });

    test('ajratgich UZILMAYDIGAN bo\'sh joy', () {
      // Oddiy bo'sh joy bo'lsa, "132" bilan "456" qatorning ikki
      // chetiga bo'linib ketishi mumkin edi.
      expect(formatMoney(132456).contains(' '), isTrue);
      expect(formatMoney(132456).contains(' '), isFalse);
    });

    test('kasr qismi yaxlitlanadi', () {
      // Summalar so'mda, tiyin yo'q.
      expect(visible(formatMoney(132456.4)), '132_456');
      expect(visible(formatMoney(132456.6)), '132_457');
    });

    test('nol va manfiy son ham to\'g\'ri chiqadi', () {
      expect(formatMoney(0), '0');
      expect(visible(formatMoney(-132456)), '-132_456');
    });

    test('so\'m qo\'shiladi', () {
      expect(visible(formatSom(132456)), '132_456 so\'m');
    });
  });

  group('o\'qish', () {
    test('formatlangan matndan son ajratiladi', () {
      expect(parseMoney(formatMoney(132456)), 132456);
      expect(parseMoney('132 456 so\'m'), 132456);
      expect(parseMoney('1 320 000'), 1320000);
    });

    test('bo\'sh yoki noto\'g\'ri matn nol beradi', () {
      expect(parseMoney(''), 0);
      expect(parseMoney('so\'m'), 0);
    });
  });

  group('kiritish', () {
    const formatter = MoneyInputFormatter();

    TextEditingValue type(String oldText, String newText) =>
        formatter.formatEditUpdate(value(oldText), value(newText));

    test('yozilayotganda ajratgich qo\'yiladi', () {
      expect(visible(type('', '1').text), '1');
      expect(visible(type('132', '1324').text), '1_324');
      expect(visible(type('1 324', '13245').text), '13_245');
      expect(visible(type('13 245', '132456').text), '132_456');
    });

    test('KURSOR raqamdan keyin qoladi', () {
      // Ajratgich qo'shilganda kursor o'z-o'zidan chapga siljib
      // qolardi va keyingi raqam noto'g'ri joyga tushardi.
      final result = formatter.formatEditUpdate(
        value('132'),
        value('1324'),
      );
      expect(visible(result.text), '1_324');
      expect(
        result.selection.baseOffset,
        result.text.length,
        reason: 'oxiriga yozilganda kursor ham oxirida qolishi kerak',
      );
    });

    test('o\'rtaga yozilganda kursor joyida qoladi', () {
      // "1 234" ning boshiga "9" qo'shiladi -> "91 234", kursor
      // "9" dan keyin, ya'ni 1-o'rinda.
      final result = formatter.formatEditUpdate(
        value('1${moneyGroupSeparator}234'),
        value('91${moneyGroupSeparator}234', cursor: 1),
      );
      expect(visible(result.text), '91_234');
      expect(result.selection.baseOffset, 1);
    });

    test('hammasi o\'chirilsa maydon bo\'shaydi', () {
      expect(type('132 456', '').text, '');
    });

    test('raqam bo\'lmagan belgilar tashlanadi', () {
      expect(visible(type('', 'abc132def456').text), '132_456');
    });

    test('juda uzun raqam QABUL QILINMAYDI', () {
      // 12 xonadan oshgani summa bo'lolmaydi va faqat joylashuvni
      // buzadi — eski qiymat saqlanadi.
      final old = value('999${moneyGroupSeparator}999');
      final result = formatter.formatEditUpdate(
        old,
        value('9999999999999'),
      );
      expect(result.text, old.text);
    });
  });
}
