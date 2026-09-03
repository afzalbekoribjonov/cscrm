/// Buyurtma ustidagi bitta o'zgarish yozuvi (audit jurnali).
///
/// MUHIM: bu yozuvlar buyurtma tugunida EMAS, alohida
/// `/tenants/{id}/order_history/` tugunida saqlanadi.
///
/// Sabab: RTDB'da so'rov buyurtmaning BUTUN daraxtini qaytaradi. Tarix
/// buyurtma ichida bo'lsa, ro'yxat ekranlari uni ham yuklab olardi —
/// garchi ro'yxatda tarix umuman ko'rsatilmasa ham. 50 ta faol buyurtmada
/// bu ~180 KB keraksiz trafik degani.
///
/// Tugun TEKIS (buyurtma ichida ichma-ich emas), chunki ikki xil so'rov
/// kerak va RTDB bitta so'rovda bitta maydon bo'yicha saralaydi:
///  * bitta buyurtma tarixi — `orderByChild('orderId').equalTo(id)`
///  * davr bo'yicha hisobot — `orderByChild('at').startAt(x).endAt(y)`
class OrderHistoryEntry {
  const OrderHistoryEntry({
    required this.key,
    required this.orderId,
    required this.type,
    required this.byEmployeeId,
    required this.byName,
    required this.at,
    this.fromStatus,
    this.toStatus,
    this.note,
    this.itemProductName,
    this.itemKey,
  });

  factory OrderHistoryEntry.fromMap(String key, Map<dynamic, dynamic> map) {
    return OrderHistoryEntry(
      key: key,
      orderId: (map['orderId'] as num?)?.toInt() ?? 0,
      type: map['type'] as String? ?? '',
      byEmployeeId: map['byEmployeeId'] as String? ?? '',
      byName: map['byName'] as String? ?? '',
      at: (map['at'] as num?)?.toInt() ?? 0,
      fromStatus: map['fromStatus'] as String?,
      toStatus: map['toStatus'] as String?,
      note: map['note'] as String?,
      itemProductName: map['itemProductName'] as String?,
      itemKey: map['itemKey'] as String?,
    );
  }

  final String key;

  /// Qaysi buyurtmaga tegishli.
  final int orderId;

  final String type;
  final String byEmployeeId;
  final String byName;
  final int at;

  /// "status_changed"/"order_created" uchun OrderStatus kaliti, lekin
  /// "item_status_changed" uchun ItemStatus kaliti.
  final String? fromStatus;
  final String? toStatus;

  /// Erkin matn izoh - masalan qayta yuvish sababi yoki to'lov tafsiloti.
  final String? note;

  /// Faqat xizmatga tegishli yozuvlar uchun - qaysi xizmat ekanini
  /// ko'rsatish uchun.
  final String? itemProductName;
  final String? itemKey;

  /// Yozuv shu xizmatga tegishlimi.
  ///
  /// Avval kalit bo'yicha solishtiriladi (aniq). Eski yozuvlarda kalit
  /// bo'lmasligi mumkin - o'shalar uchun mahsulot nomi bo'yicha zaxira
  /// tekshiruv qoladi.
  bool belongsToItem(String key, String productName) {
    if (itemKey != null && itemKey!.isNotEmpty) return itemKey == key;
    return itemProductName != null && itemProductName == productName;
  }
}
