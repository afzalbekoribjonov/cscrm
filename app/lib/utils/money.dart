import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Pul summalarini ko'rsatish va kiritish — BUTUN ILOVA UCHUN BITTA joy.
///
/// NEGA KERAK EDI. Ilgari summalar ikki xil chiqardi: ba'zi ekranlarda
/// `NumberFormat` orqali "132 456", ko'pchiligida esa
/// `toStringAsFixed(0)` orqali "132456". Ikkinchisi olti xonali
/// summadan boshlab o'qilmay qoladi — "1320000" va "132000" ni bir
/// qarashda ajratib bo'lmaydi. Pul bilan ishlaydigan ilovada bu
/// chalkashlik qimmatga tushadi.
///
/// Ajratgich — UZILMAYDIGAN bo'sh joy (U+00A0). Oddiy bo'sh joy
/// bo'lsa, "132" bilan "456" qatorning ikki chetiga bo'linib ketishi
/// mumkin edi.

final _decimal = NumberFormat.decimalPattern('uz');

/// Guruhlarni ajratuvchi belgi. Sinovlar va kiritish maydonlari shunga
/// tayanadi, shuning uchun bir joyda e'lon qilingan.
const moneyGroupSeparator = ' ';

/// "132 456"
String formatMoney(num value) => _decimal.format(value.round());

/// "132 456 so'm"
String formatSom(num value) => '${formatMoney(value)} so\'m';

/// Kiritilgan matndan sonni ajratib oladi.
///
/// Ajratgichlar, bo'sh joylar va boshqa belgilar tashlanadi:
/// "132 456 so'm" -> 132456. O'qib bo'lmasa 0.
double parseMoney(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return double.tryParse(digits) ?? 0;
}

/// Summa kiritilayotganda raqamlarni uchtalab ajratadi.
///
/// Foydalanuvchi "132456" deb yozadi, maydonda "132 456" ko'rinadi.
///
/// KURSOR o'rni ham to'g'rilanadi: ajratgich qo'shilganda kursor
/// o'z-o'zidan chapga siljib qolardi va keyingi raqam noto'g'ri
/// joyga tushardi.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter({this.maxDigits = 12});

  /// Eng ko'p necha xona. Himoya chegarasi: tasodifan uzun raqam
  /// yozilsa, u summa bo'lolmaydi va faqat joylashuvni buzadi.
  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return TextEditingValue.empty;

    if (digits.length > maxDigits) return oldValue;

    // Kursordan OLDIN nechta raqam borligini sanaymiz — formatlangan
    // matnda kursorni aynan shuncha raqamdan keyin qo'yamiz.
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final digitsBefore = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    final formatted = _decimal.format(int.parse(digits));

    var seen = 0;
    var offset = formatted.length;
    for (var i = 0; i < formatted.length; i++) {
      if (seen == digitsBefore) {
        offset = i;
        break;
      }
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) seen++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
