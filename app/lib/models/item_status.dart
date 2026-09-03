/// Buyurtma ichidagi har bir mahsulotning o'z (order.status'dan mustaqil)
/// jarayon holati - har biri sexda alohida-alohida siljiydi.
enum ItemStatus {
  yuvilmoqda('yuvilmoqda', 'Yuvilmoqda'),
  qadoqlashda('qadoqlashda', 'Qadoqlashda'),
  tayyor('tayyor', 'Tayyor'),
  qaytaYuvildi('qayta_yuvildi', 'Qayta yuvildi');

  const ItemStatus(this.key, this.label);
  final String key;
  final String label;

  static ItemStatus fromKey(String key) {
    return ItemStatus.values.firstWhere(
      (s) => s.key == key,
      orElse: () => ItemStatus.yuvilmoqda,
    );
  }
}
