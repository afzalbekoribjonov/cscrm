import '../models/item_status.dart';

/// Buyurtma ustidagi sof hisob-kitoblar.
///
/// Bular ATAYLAB `OrderService` dan ajratilgan: ular tranzaksiya ichida,
/// serverdagi xom `Map` ustida ishlaydi va hech qanday Firebase ulanishiga
/// muhtoj emas. Shu sabab ularni to'g'ridan-to'g'ri test qilish mumkin —
/// pul bilan bog'liq mantiq uchun bu muhim.

/// Xizmatlar summasi.
///
/// Umumiy narx mustaqil saqlanadigan qiymat EMAS — u doim xizmatlardan
/// kelib chiqadi. Har bir o'zgarishda qaytadan hisoblanadi, shuning uchun
/// avvalgi noto'g'ri yozuvlar ham keyingi o'zgarishda o'zi tuzalib ketadi.
double sumItemPrices(Map<String, dynamic> items) {
  var total = 0.0;
  for (final value in items.values) {
    if (value is! Map) continue;
    total += (value['price'] as num?)?.toDouble() ?? 0;
  }
  return total;
}

/// Buyurtmadagi BARCHA xizmat tayyormi.
///
/// Bo'sh buyurtma "tayyor" hisoblanmaydi — aks holda xizmatlari hali
/// kiritilmagan buyurtma darhol yetgazishga tayyor bo'lib qolardi.
bool allItemsReady(Map<String, dynamic> items) {
  if (items.isEmpty) return false;
  return items.values
      .every((v) => v is Map && v['status'] == ItemStatus.tayyor.key);
}

/// Yetgazishdagi to'lov taqsimoti.
class DeliverySettlement {
  const DeliverySettlement({
    required this.paid,
    required this.debt,
    required this.discount,
  });

  final double paid;

  /// Mijoz keyin to'laydi.
  final double debt;

  /// Kechirildi — hech qachon olinmaydi.
  final double discount;
}

/// Olingan summani buyurtma narxiga nisbatan taqsimlaydi.
///
/// [orderTotal] SERVERDAGI joriy narx bo'lishi shart, dastavchik oynani
/// ochganda ko'rgan narx emas. Sabab: dastavchik mijoz oldida turganda
/// sexdagi xodim buyurtmaga yangi xizmat qo'shishi mumkin. Eski narxdan
/// hisoblansa, farq hech qayerda qayd etilmay yo'qolib ketardi.
///
/// [shortfallIsDiscount] — yetmagan qismni qarz deb yozishmi yoki
/// kechirishmi. Bu qaror dastavchikniki (uning vakolatiga qarab), lekin
/// SUMMANI server narxi belgilaydi.
DeliverySettlement splitDeliveryPayment({
  required double orderTotal,
  required double paid,
  required bool shortfallIsDiscount,
}) {
  final safePaid = paid < 0 ? 0.0 : paid;

  // Narx noma'lum (xizmatlar hali o'lchanmagan) - farqni hisoblashning
  // ma'nosi yo'q, olingan summa shundayligicha yoziladi.
  if (orderTotal <= 0) {
    return DeliverySettlement(paid: safePaid, debt: 0, discount: 0);
  }

  final applied = safePaid > orderTotal ? orderTotal : safePaid;
  final shortfall = orderTotal - applied;

  return DeliverySettlement(
    paid: applied,
    debt: shortfallIsDiscount ? 0 : shortfall,
    discount: shortfallIsDiscount ? shortfall : 0,
  );
}

/// Qarz to'lovining natijasi.
class DebtPayment {
  const DebtPayment({
    required this.applied,
    required this.remainingDebt,
    required this.totalPaid,
  });

  /// Haqiqatda hisobga olingan summa (qarzdan ortiq bo'lsa qirqiladi).
  final double applied;
  final double remainingDebt;
  final double totalPaid;

  bool get fullySettled => remainingDebt <= 0;
}

/// Qarzga to'lovni qo'llaydi.
///
/// Qancha olinishi SERVERDAGI joriy qarzdan kelib chiqadi: ikki joydan bir
/// vaqtda to'lov kiritilsa ham qarz manfiy songa tushib ketmaydi va
/// to'langan summa haqiqatdan oshib ketmaydi.
DebtPayment applyDebtPayment({
  required double currentDebt,
  required double currentPaid,
  required double amount,
}) {
  final safeDebt = currentDebt < 0 ? 0.0 : currentDebt;
  final safeAmount = amount < 0 ? 0.0 : amount;
  final applied = safeAmount > safeDebt ? safeDebt : safeAmount;

  return DebtPayment(
    applied: applied,
    remainingDebt: safeDebt - applied,
    totalPaid: currentPaid + applied,
  );
}
