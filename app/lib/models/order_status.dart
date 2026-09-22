enum OrderStatus {
  olibKelish('olib_kelish', 'Olib kelish'),
  ishniBoshlash('ishni_boshlash', 'Ishni boshlash'),
  yuvishda('yuvishda', 'Yuvishda'),
  yetgazishgaTayyor('yetgazishga_tayyor', 'Yetgazishga tayyor'),
  yetgazildi('yetgazildi', 'Yetgazildi');

  const OrderStatus(this.key, this.label);
  final String key;
  final String label;

  static OrderStatus fromKey(String key) {
    return OrderStatus.values.firstWhere(
      (s) => s.key == key,
      orElse: () => OrderStatus.olibKelish,
    );
  }

  /// Buyurtma sexga kirgan (qabul qilingan yoki o'zi kelgan) - Yuvish va
  /// Qadoqlash bo'limlari faqat shu holatdagi buyurtmalarni ko'rsatadi.
  /// `ishniBoshlash` faqat eski (migratsiyadan oldingi) ma'lumot uchun.
  bool get isInWorkshop =>
      this == OrderStatus.yuvishda || this == OrderStatus.ishniBoshlash;

  /// Buyurtma YOPILGAN — ish tugagan, unga endi tegilmaydi.
  ///
  /// Yetgazilgan buyurtmaning puli olingan va u kunlik daromadga
  /// kirgan. Keyin unga xizmat qo'shilsa yoki narxi o'zgartirilsa,
  /// allaqachon yopilgan hisobot o'zgarib ketadi.
  bool get isClosed => this == OrderStatus.yetgazildi;
}

enum DeliveryType {
  olibKelish('olib_kelish', 'Olib kelish'),
  oziKeldi('ozi_keldi', 'O\'zi keldi');

  const DeliveryType(this.key, this.label);
  final String key;
  final String label;

  static DeliveryType fromKey(String key) {
    return DeliveryType.values.firstWhere(
      (s) => s.key == key,
      orElse: () => DeliveryType.oziKeldi,
    );
  }
}
