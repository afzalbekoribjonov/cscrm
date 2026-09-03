import 'calculation_method.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.method,
    required this.price,
    required this.priceSmall,
    required this.priceLarge,
    required this.createdAt,
  });

  factory Product.fromMap(String id, Map<dynamic, dynamic> map) {
    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      method: CalculationMethod.fromKey(map['method'] as String? ?? ''),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      priceSmall: (map['priceSmall'] as num?)?.toDouble() ?? 0,
      priceLarge: (map['priceLarge'] as num?)?.toDouble() ?? 0,
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final CalculationMethod method;

  /// m2/dona/metr/kg usullari uchun - shu birlikning narxi.
  final double price;

  /// Faqat Kichik/Katta usuli uchun.
  final double priceSmall;
  final double priceLarge;

  final int createdAt;

  /// Mahsulot ro'yxatida ko'rsatiladigan qisqa narx yorlig'i.
  String get priceLabel {
    if (method.hasTwoSizes) {
      return 'Kichik: ${priceSmall.toStringAsFixed(0)} · Katta: ${priceLarge.toStringAsFixed(0)} so\'m';
    }
    final unit = method.unitSymbol.isEmpty ? '' : '/${method.unitSymbol}';
    return '${price.toStringAsFixed(0)} so\'m$unit';
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'method': method.key,
        'price': price,
        'priceSmall': priceSmall,
        'priceLarge': priceLarge,
        'createdAt': createdAt,
      };
}
