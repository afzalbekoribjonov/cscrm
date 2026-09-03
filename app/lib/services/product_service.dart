import 'package:firebase_database/firebase_database.dart';

import '../models/calculation_method.dart';
import '../models/product.dart';
import '../utils/firebase_map.dart';
import 'tenant_scope.dart';

class ProductService {
  ProductService({TenantScope? scope})
      : _ref = (scope ?? TenantScope.current).ref('products');

  final DatabaseReference _ref;

  Stream<List<Product>> streamProducts() {
    return _ref.onValue.map((event) {
      final raw = asFirebaseMap(event.snapshot.value);
      final products = <Product>[];
      for (final entry in raw.entries) {
        if (entry.value is! Map) continue;
        products.add(Product.fromMap(entry.key, entry.value as Map));
      }
      products.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return products;
    });
  }

  Future<void> createProduct({
    required String name,
    required CalculationMethod method,
    required double price,
    required double priceSmall,
    required double priceLarge,
  }) async {
    final newRef = _ref.push();
    await newRef.set({
      'name': name.trim(),
      'method': method.key,
      'price': price,
      'priceSmall': priceSmall,
      'priceLarge': priceLarge,
      'createdAt': ServerValue.timestamp,
    });
  }

  Future<void> updateProduct({
    required String id,
    required String name,
    required CalculationMethod method,
    required double price,
    required double priceSmall,
    required double priceLarge,
  }) async {
    await _ref.child(id).update({
      'name': name.trim(),
      'method': method.key,
      'price': price,
      'priceSmall': priceSmall,
      'priceLarge': priceLarge,
    });
  }

  Future<void> deleteProduct(String id) async {
    await _ref.child(id).remove();
  }

  /// Mahsulotni bitta marta o'qib oladi - masalan buyurtma ichidagi
  /// mahsulotni qayta hisoblash uchun uning joriy hisoblash usuli kerak
  /// bo'lganda ishlatiladi.
  Future<Product?> getProduct(String id) async {
    final snapshot = await _ref.child(id).get();
    if (!snapshot.exists || snapshot.value is! Map) return null;
    return Product.fromMap(id, snapshot.value as Map);
  }
}
