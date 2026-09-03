import '../../models/calculation_method.dart';
import '../../models/measure_unit.dart';
import '../../models/product.dart';
import '../../services/order_service.dart';

/// Buyurtma yaratish jarayonida vaqtinchalik saqlanadigan (mahsulot, soni)
/// juftligi — hali Firebase'ga yozilmagan.
class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  CartLine copyWith({int? quantity}) =>
      CartLine(product: product, quantity: quantity ?? this.quantity);
}

/// Savatdagi har bir qatorni soniga qarab alohida jismoniy birlikka
/// ajratadi va darhol saqlash uchun tayyorlaydi - Hisoblash bosqichi
/// endi majburiy emas. "Soniga" (dona) usuli o'lcham talab qilmagani
/// uchun narxi darhol hisoblanadi; qolgan usullar (m², metr, kg,
/// kichik/katta) uchun hajm/narx bo'sh qoldiriladi va keyinchalik
/// mahsulot kartasidagi tahrirlash (qalam) tugmasi orqali kiritiladi.
List<NewOrderItemDraft> expandCartToDrafts(List<CartLine> cart) {
  final drafts = <NewOrderItemDraft>[];
  for (final line in cart) {
    final isDona = line.product.method == CalculationMethod.dona;
    for (var i = 0; i < line.quantity; i++) {
      drafts.add(NewOrderItemDraft(
        productId: line.product.id,
        productName: line.product.name,
        hajm: isDona ? '1 dona' : '',
        price: isDona ? line.product.price : 0,
        // "Dona" darhol o'lchangan hisoblanadi, shu sabab statistika
        // uchun raqami ham shu yerda yoziladi. Qolganlari keyinchalik
        // o'lchanganda to'ldiriladi.
        unit: isDona ? MeasureUnit.dona : null,
        quantity: isDona ? 1 : 0,
      ));
    }
  }
  return drafts;
}
