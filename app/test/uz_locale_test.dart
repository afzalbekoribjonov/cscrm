import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Kalendar va sanalar O'ZBEKCHA chiqishi kerak.
///
/// Bu test jim yiqilishning oldini oladi: lokal ma'lumoti yuklanmasa
/// `intl` inglizchaga tushib ketadi va buni hech kim sezmaydi.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('uz');
  });

  test('oy nomlari o\'zbekcha', () {
    final yanvar = DateTime(2026, 1, 15);
    final name = DateFormat('MMMM', 'uz').format(yanvar);

    expect(name.toLowerCase(), isNot('january'),
        reason: 'inglizchaga tushib qolmasligi kerak');
    expect(name.toLowerCase(), contains('yanvar'));
  });

  test('kun nomlari o\'zbekcha', () {
    // 2026-01-05 — dushanba.
    final name = DateFormat('EEEE', 'uz').format(DateTime(2026, 1, 5));

    expect(name.toLowerCase(), isNot('monday'));
    expect(name.toLowerCase(), contains('dushanba'));
  });

  test('qisqa oy nomi ham ishlaydi', () {
    // Mart uchun qisqa nom ikkala tilda ham "mar" — u farqni
    // ko'rsatmaydi. Yanvarda esa farq aniq: "yan" / "jan".
    final short = DateFormat('MMM', 'uz').format(DateTime(2026, 1, 1));
    expect(short.toLowerCase(), isNot('jan'));
    expect(short.toLowerCase(), startsWith('yan'));
  });

  test('raqamli format o\'zgarmaydi', () {
    // Hisobotlarda raqamli sana ishlatiladi — u lokaldan qat'i nazar
    // bir xil bo'lishi kerak.
    expect(
      DateFormat('dd.MM.yyyy').format(DateTime(2026, 3, 7)),
      '07.03.2026',
    );
  });
}
