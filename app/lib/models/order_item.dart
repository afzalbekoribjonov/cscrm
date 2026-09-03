import '../utils/firebase_map.dart';
import 'comment.dart';
import 'item_status.dart';
import 'measure_unit.dart';

class OrderItem {
  const OrderItem({
    required this.key,
    required this.itemId,
    required this.productId,
    required this.productName,
    required this.hajm,
    required this.price,
    required this.createdBy,
    required this.status,
    required this.comments,
    this.rewashReason,
    this.unit,
    this.quantity = 0,
  });

  factory OrderItem.fromMap(String key, Map<dynamic, dynamic> map) {
    final comments = <Comment>[];
    for (final entry in asFirebaseMap(map['comments']).entries) {
      if (entry.value is! Map) continue;
      comments.add(Comment.fromMap(entry.key, entry.value as Map));
    }
    comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final hajm = map['hajm'] as String? ?? '';

    // Yangi yozuvlarda raqamli o'lchov to'g'ridan-to'g'ri saqlanadi.
    // Eski yozuvlarda esa faqat formatlangan matn bor - undan taxminan
    // ajratib olamiz, aks holda statistikada ular ko'rinmay qolardi.
    var unit = MeasureUnit.fromKey(map['unit'] as String?);
    var quantity = (map['quantity'] as num?)?.toDouble() ?? 0;
    if (unit == null || quantity <= 0) {
      final parsed = parseLegacyHajm(hajm);
      if (parsed != null) {
        unit ??= parsed.unit;
        if (quantity <= 0) quantity = parsed.quantity;
      }
    }

    return OrderItem(
      key: key,
      itemId: map['itemId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      hajm: hajm,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      createdBy: map['createdBy'] as String? ?? '',
      status: ItemStatus.fromKey(map['status'] as String? ?? ''),
      comments: comments,
      rewashReason: map['rewashReason'] as String?,
      unit: unit,
      quantity: quantity,
    );
  }

  /// Firebase'dagi items map ichidagi kalit (masalan "1", "2").
  final String key;

  /// Ko'rsatish uchun ID, masalan "12/3" (buyurtma #12ning 3-mahsuloti).
  final String itemId;
  final String productId;
  final String productName;
  final String hajm;
  final double price;
  final String createdBy;

  /// Mahsulotning sexdagi joriy jarayon holati - buyurtmaning umumiy
  /// holatidan mustaqil, har bir mahsulot alohida siljiydi.
  final ItemStatus status;
  final List<Comment> comments;

  /// "Qayta yuvildi" belgilanganda kiritilgan sabab.
  final String? rewashReason;

  /// Statistika uchun raqamli o'lchov birligi va miqdori. O'lchanmagan
  /// xizmatlarda [unit] null bo'ladi.
  final MeasureUnit? unit;
  final double quantity;

  bool get isMeasured => hajm.isNotEmpty;

  Map<String, Object?> toMap() => {
        'itemId': itemId,
        'productId': productId,
        'productName': productName,
        'hajm': hajm,
        'price': price,
        'createdBy': createdBy,
        'status': status.key,
        if (rewashReason != null) 'rewashReason': rewashReason,
        if (unit != null) 'unit': unit!.key,
        if (quantity > 0) 'quantity': quantity,
      };
}
