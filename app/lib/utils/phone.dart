// Telefon raqamlari bilan ishlash uchun yordamchi funksiyalar.
//
// Foydalanuvchi raqamni "+998 90 123 45 67", "998901234567" yoki
// oddiy "901234567" ko'rinishida kiritishi mumkin - qaysi birini
// yozishidan qat'iy nazar, saqlashdan oldin bir xil kanonik
// "998XXXXXXXXX" (12 xonali, mamlakat kodi bilan, "+"siz) formatga
// keltiriladi. Shu tufayli xodim yaratish/login qilish va buyurtma
// mijoz raqami har doim bir xil taqqoslanadi.

/// Kiritilgan matndan faqat raqamlarni ajratib oladi (bo'sh joy, "+",
/// "-" va h.k. olib tashlanadi) - hech qanday kanonizatsiya qilinmaydi.
String digitsOnly(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

/// Oxirgi [n] ta raqamni qaytaradi (mahalliy raqamni mamlakat kodidan
/// ajratib olish uchun) - agar undan kam bo'lsa, borini qaytaradi.
String lastDigits(String input, int n) {
  final digits = digitsOnly(input);
  return digits.length <= n ? digits : digits.substring(digits.length - n);
}

/// Har qanday formatda kiritilgan raqamni kanonik "998XXXXXXXXX"
/// (12 xonali) formatga keltiradi. "+998", "998" yoki mamlakat
/// kodisiz mahalliy 9 xona - barchasi bir xil natija beradi.
String normalizePhone(String input) {
  final digits = digitsOnly(input);
  if (digits.isEmpty) return '';
  return '998${lastDigits(digits, 9)}';
}

/// Raqam to'liq kiritilganmi (mahalliy qismi 9 xonaga yetganmi) -
/// saqlashdan oldingi tekshiruv uchun.
bool isCompletePhone(String input) => normalizePhone(input).length == 12;

/// Saqlangan (yoki eski, formatlanmagan) raqamni ko'rsatish uchun
/// "+998 90 123 45 67" ko'rinishida formatlaydi.
String formatPhoneForDisplay(String stored) {
  final local = lastDigits(stored, 9);
  if (local.length != 9) {
    final digits = digitsOnly(stored);
    return digits.isEmpty ? '' : '+$digits';
  }
  return '+998 ${local.substring(0, 2)} ${local.substring(2, 5)} '
      '${local.substring(5, 7)} ${local.substring(7, 9)}';
}
