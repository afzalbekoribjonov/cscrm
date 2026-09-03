import 'package:flutter/material.dart';

/// Ilovaning to'rtta ish bo'limi. Xodimga vakolat aynan shu bo'limlar
/// bo'yicha beriladi: xodim qaysi bo'limga vakolatli bo'lsa, faqat o'sha
/// bo'limga tegishli ishlarni va faqat o'sha bo'lim ichidan turib bajara
/// oladi (qarang: [StaffAccess.canActIn]).
enum WorkSection {
  yangi('yangi', 'Yangi buyurtma', Icons.note_add_rounded),
  yuvish('yuvish', 'Yuvish', Icons.local_laundry_service_rounded),
  qadoqlash('qadoqlash', 'Qadoqlash', Icons.inventory_2_rounded),
  yetgazma('yetgazma', 'Yetgazma', Icons.local_shipping_rounded);

  const WorkSection(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  /// Vakolat berish ekranida ko'rsatiladigan qisqa izoh.
  String get accessHint {
    switch (this) {
      case WorkSection.yangi:
        return 'Yangi buyurtma yaratish';
      case WorkSection.yuvish:
        return 'Xizmat qo\'shish, o\'lchash, qadoqlashga o\'tkazish';
      case WorkSection.qadoqlash:
        return 'Qadoqlandi belgilash, qayta yuvishga qaytarish';
      case WorkSection.yetgazma:
        return 'Olib kelish, qabul qilish, yetgazish va to\'lov';
    }
  }

  static WorkSection? fromKey(String? key) {
    if (key == null) return null;
    for (final s in WorkSection.values) {
      if (s.key == key) return s;
    }
    return null;
  }
}
