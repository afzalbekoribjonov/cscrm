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
