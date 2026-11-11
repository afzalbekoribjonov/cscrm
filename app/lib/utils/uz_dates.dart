import 'package:intl/intl.dart';

import 'date_utils.dart';

/// Sanalarni o'zbekcha, odam o'qiydigan ko'rinishda yozish.
///
/// `intl` ning o'zbek formatlari oy nomini kichik harf bilan va ba'zan
/// noqulay tartibda beradi ("noyabr, 2026"). Ilovada esa sana hamma
/// joyda bir xil ko'rinishi kerak: "12-noyabr", "Noyabr 2026".
abstract class UzDates {
  static const months = [
    'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
    'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr',
  ];

  static const weekdaysShort = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  static const weekdays = [
    'Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba',
    'Yakshanba',
  ];

  static final _time = DateFormat('HH:mm');
  static final _numeric = DateFormat('dd.MM.yyyy');

  static String monthName(int month) => months[month - 1];

  /// "Noyabr 2026"
  static String monthYear(DateTime d) => '${monthName(d.month)} ${d.year}';

  /// "12-noyabr"
  static String dayMonth(DateTime d) =>
      '${d.day}-${monthName(d.month).toLowerCase()}';

  /// "12-noyabr, 2026" — joriy yil bo'lsa yil yozilmaydi.
  static String date(DateTime d, {DateTime? now}) {
    final today = now ?? DateTime.now();
    return d.year == today.year ? dayMonth(d) : '${dayMonth(d)}, ${d.year}';
  }

  /// "12.11.2026"
  static String numeric(DateTime d) => _numeric.format(d);

  /// "14:05"
  static String time(DateTime d) => _time.format(d);

  /// "Bugun", "Kecha", "Ertaga" yoki "12-noyabr".
  static String relativeDay(DateTime d, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final diff = startOfDay(d).difference(today).inDays;
    if (diff == 0) return 'Bugun';
    if (diff == -1) return 'Kecha';
    if (diff == 1) return 'Ertaga';
    return date(d, now: now);
  }

  /// "Bugun, 14:05" / "12-noyabr, 14:05"
  static String dateTime(DateTime d, {DateTime? now}) =>
      '${relativeDay(d, now: now)}, ${time(d)}';

  static DateTime fromMillis(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis);
}

/// Qolgan vaqtni aniq yozadi: "2 kun 5 soat", "3 soat 20 daqiqa",
/// "15 daqiqa".
///
/// Ilgari obuna muddati faqat KUNlarda (yuqoriga yaxlitlab)
/// ko'rsatilardi — tugashiga 1 soat qolganda ham "1 kun" chiqardi.
String formatRemaining(Duration d) {
  if (d.isNegative || d == Duration.zero) return '0 daqiqa';
  final days = d.inDays;
  final hours = d.inHours % 24;
  final minutes = d.inMinutes % 60;
  if (days >= 7) return '$days kun';
  if (days >= 1) return hours > 0 ? '$days kun $hours soat' : '$days kun';
  if (d.inHours >= 1) {
    return minutes > 0 ? '${d.inHours} soat $minutes daqiqa' : '${d.inHours} soat';
  }
  return '${d.inMinutes < 1 ? 1 : d.inMinutes} daqiqa';
}
