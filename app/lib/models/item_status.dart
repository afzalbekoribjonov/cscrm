/// Buyurtma ichidagi har bir xizmatning sexdagi holati — buyurtmaning
/// umumiy holatidan mustaqil, har biri alohida siljiydi:
///
///   Navbatda → (Yuvish) → Yuvilmoqda → Qadoqlashda → Tayyor
///                              ↑______ Qayta yuvish ______|
///
/// "Navbatda" ATAYLAB qo'shilgan: ilgari yangi xizmat yaratilishi bilan
/// "Yuvilmoqda" bo'lib qolardi — hali hech kim tegmagan gilam "yuvilmoqda"
/// deb turardi. Endi yuvish xodim "Yuvish" tugmasini bosganda boshlanadi.
///
/// Topshirilgan xizmat holati "Tayyor" bo'lib qoladi, topshirilgani esa
/// alohida belgida (`OrderItem.handedAt`) — ilovaning eski versiyalari
/// ham uni to'g'ri "Tayyor" deb ko'radi.
enum ItemStatus {
  navbatda('navbatda', 'Navbatda'),
  yuvilmoqda('yuvilmoqda', 'Yuvilmoqda'),
  qadoqlashda('qadoqlashda', 'Qadoqlashda'),
  tayyor('tayyor', 'Tayyor'),
  qaytaYuvildi('qayta_yuvildi', 'Qayta yuvishda');

  const ItemStatus(this.key, this.label);
  final String key;
  final String label;

  /// Noma'lum qiymat (masalan ilovaning yangiroq versiyasi yozgan) —
  /// "Navbatda" deb olinadi: bu eng xavfsiz tomon, xizmat hech qayerdan
  /// "yo'qolib" qolmaydi va hech kim uni tayyor deb topshirib yubormaydi.
  static ItemStatus fromKey(String key) {
    for (final s in ItemStatus.values) {
      if (s.key == key) return s;
    }
    return ItemStatus.navbatda;
  }

  /// Yuvish bo'limiga tegishli holatlar.
  bool get isWashStage =>
      this == navbatda || this == yuvilmoqda || this == qaytaYuvildi;

  /// Yuvish hali boshlanmagan — "Yuvish" tugmasi kutilmoqda.
  bool get awaitsWash => this == navbatda || this == qaytaYuvildi;
}
