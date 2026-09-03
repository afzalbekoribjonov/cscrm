/// Realtime Database ketma-ket butun sonli kalitlarni ("0","1","2"...)
/// ba'zan avtomatik ravishda List qilib qaytaradi (Map o'rniga) - bu xuddi
/// "orders" yoki buyurtma "items" kabi raqamli ID ishlatadigan tugunlarda
/// sodir bo'ladi va e'tiborsiz qoldirilsa butun ro'yxat "bo'sh" ko'rinishiga
/// olib keladi. Ikkala holatni ham bir xil Map ko'rinishga keltiradi, shunda
/// yuqori qatlam kod har doim Map bilan ishlay oladi.
Map<String, dynamic> asFirebaseMap(Object? raw) {
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  if (raw is List) {
    final map = <String, dynamic>{};
    for (var i = 0; i < raw.length; i++) {
      final value = raw[i];
      if (value != null) map['$i'] = value;
    }
    return map;
  }
  return const {};
}
