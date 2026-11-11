import 'package:flutter/services.dart';

import 'phone.dart';

/// Telefon maydoni: "+998" oldindan yozilgan, foydalanuvchi faqat 9 ta
/// raqamni kiritadi va ular "90 123 45 67" ko'rinishida guruhlanadi.
///
/// To'liq raqam ("+998 90 …" yoki "998…") joylashtirilsa ham oxirgi 9
/// raqam olinadi — mamlakat kodi ikki marta yozilib qolmaydi.
class UzPhoneInputFormatter extends TextInputFormatter {
  const UzPhoneInputFormatter();

  static String format(String digits) {
    final d = digits.length > 9 ? digits.substring(digits.length - 9) : digits;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 5 || i == 7) b.write(' ');
      b.write(d[i]);
    }
    return b.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = digitsOnly(newValue.text);
    if (digits.length > 9) digits = lastDigits(digits, 9);
    final text = format(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Maydondagi matndan saqlanadigan kanonik raqam ("998901234567").
String phoneFromField(String text) => normalizePhone(text);
