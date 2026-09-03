/// Oflayn holatda keshlangan litsenziyaning hali yaroqli ekanini aniqlash.
///
/// Bu mantiq ATAYLAB alohida — u vaqt bilan ishlaydi, ya'ni test qilinishi
/// kerak, lekin Firebase yoki tarmoqqa hech qanday aloqasi yo'q.
library;

/// Ishonchli "hozir".
///
/// Ilova ONLAYN bo'lganda vaqt muhim emas — javobni server beradi. Lekin
/// OFLAYN holatda keshning muddati o'tganini aniqlash uchun vaqt kerak,
/// va yagona manba qurilma soati bo'lib qoladi.
///
/// Qurilma soatini ORQAGA surish bilan oflayn oynani cho'zib bo'lmasligi
/// uchun oxirgi ko'rilgan SERVER vaqtidan orqaga qaytmaymiz: agar qurilma
/// vaqti serverникidan kichik bo'lsa, server vaqti ishlatiladi.
///
/// Oldinga surish esa foyda bermaydi — u keshni tezroq eskirtiradi va
/// ilova serverga murojaat qilishga majbur bo'ladi.
int effectiveNow({required int deviceNow, required int lastServerTime}) {
  return deviceNow > lastServerTime ? deviceNow : lastServerTime;
}

/// Keshlangan javob hali ishlatilsa bo'ladimi.
///
/// [validUntil] — `checkedAt + ttlSeconds * 1000`.
bool isCacheUsable({required int validUntil, required int now}) {
  return now < validUntil;
}
