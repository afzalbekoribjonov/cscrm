import 'dart:convert';

import '../models/measure_unit.dart';
import '../models/order_status.dart';
import '../services/order_service.dart';

/// Hali serverga yuborilmagan buyurtma.
///
/// NEGA KERAK. Buyurtma RAQAMI serverdagi umumiy hisoblagichdan
/// olinadi — uni qurilmada o'ylab topib bo'lmaydi, aks holda ikki
/// xodimda bir xil raqam chiqib qolardi. Shu sabab internetsiz
/// buyurtma yaratish umuman ishlamasdi.
///
/// Endi buyurtma avval QURILMADA saqlanadi, raqam esa aloqa
/// tiklanganda olinadi. Foydalanuvchi uchun ish to'xtamaydi; raqam
/// kelgach u o'sha ro'yxatda paydo bo'ladi.
class PendingOrder {
  const PendingOrder({
    required this.localId,
    required this.createdAt,
    required this.customerName,
    required this.customerPhone,
    required this.address,
    required this.deadline,
    required this.deliveryType,
    required this.items,
    required this.createdBy,
    required this.createdByName,
    required this.comment,
    this.assignedOrderId,
  });

  /// Qurilmadagi vaqtinchalik kalit. Server raqami bilan hech qanday
  /// aloqasi yo'q.
  final String localId;

  /// Qachon yaratilgani — ro'yxatda tartiblash uchun.
  final int createdAt;

  final String customerName;
  final String customerPhone;
  final String address;
  final int? deadline;
  final DeliveryType deliveryType;
  final List<NewOrderItemDraft> items;
  final String createdBy;
  final String createdByName;
  final String comment;

  /// Serverdan olingan raqam.
  ///
  /// Nol bosqichda `null`. Raqam olingandan KEYIN, lekin buyurtma
  /// yozilishidan OLDIN saqlanadi — shu bir qadam tufayli ilova
  /// aynan shu orada yopilib qolsa ham buyurtma ikki marta
  /// yozilmaydi: keyingi urinishda raqam bo'yicha tekshiriladi.
  final int? assignedOrderId;

  PendingOrder withOrderId(int id) => PendingOrder(
        localId: localId,
        createdAt: createdAt,
        customerName: customerName,
        customerPhone: customerPhone,
        address: address,
        deadline: deadline,
        deliveryType: deliveryType,
        items: items,
        createdBy: createdBy,
        createdByName: createdByName,
        comment: comment,
        assignedOrderId: id,
      );

  /// Umumiy summa — ro'yxatda ko'rsatish uchun.
  double get total => items.fold(0, (sum, i) => sum + i.price);

  Map<String, Object?> toJson() => {
        'localId': localId,
        'createdAt': createdAt,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'address': address,
        'deadline': deadline,
        'deliveryType': deliveryType.key,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'comment': comment,
        'assignedOrderId': assignedOrderId,
        'items': items
            .map((i) => {
                  'productId': i.productId,
                  'productName': i.productName,
                  'hajm': i.hajm,
                  'price': i.price,
                  'unit': i.unit?.key,
                  'quantity': i.quantity,
                })
            .toList(),
      };

  static PendingOrder fromJson(Map<String, Object?> json) => PendingOrder(
        localId: json['localId'] as String,
        createdAt: (json['createdAt'] as num).toInt(),
        customerName: json['customerName'] as String? ?? '',
        customerPhone: json['customerPhone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        deadline: (json['deadline'] as num?)?.toInt(),
        deliveryType:
            DeliveryType.fromKey(json['deliveryType'] as String? ?? ''),
        createdBy: json['createdBy'] as String? ?? '',
        createdByName: json['createdByName'] as String? ?? '',
        comment: json['comment'] as String? ?? '',
        assignedOrderId: (json['assignedOrderId'] as num?)?.toInt(),
        items: ((json['items'] as List?) ?? const [])
            .cast<Map<String, Object?>>()
            .map((i) => NewOrderItemDraft(
                  productId: i['productId'] as String? ?? '',
                  productName: i['productName'] as String? ?? '',
                  hajm: i['hajm'] as String? ?? '',
                  price: (i['price'] as num?)?.toDouble() ?? 0,
                  unit: MeasureUnit.fromKey(i['unit'] as String?),
                  quantity: (i['quantity'] as num?)?.toDouble() ?? 0,
                ))
            .toList(),
      );

  String encode() => jsonEncode(toJson());

  static PendingOrder decode(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, Object?>);
}
