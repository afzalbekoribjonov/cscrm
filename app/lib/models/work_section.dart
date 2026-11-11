import 'package:flutter/material.dart';

/// Ilovaning ish bo'limlari. Xodimga vakolat aynan shu bo'limlar bo'yicha
/// beriladi: xodim qaysi bo'limga vakolatli bo'lsa, faqat o'sha bo'limni
/// ochadi va faqat o'sha bo'lim ichidan turib ish qiladi (qarang:
/// [StaffAccess.canActIn]). Vakolati yo'q bo'limda "Sizda vakolat mavjud
/// emas" deb turadi — ichidagi buyurtmalar ko'rinmaydi.
enum WorkSection {
  yangi('yangi', 'Yangi', 'Yangi buyurtma', Icons.add_circle_outline_rounded,
      Icons.add_circle_rounded),
  yuvish('yuvish', 'Yuvish', 'Yuvish', Icons.local_laundry_service_outlined,
      Icons.local_laundry_service_rounded),
  qadoqlash('qadoqlash', 'Qadoqlash', 'Qadoqlash', Icons.inventory_2_outlined,
      Icons.inventory_2_rounded),
  yetgazma('yetgazma', 'Yetgazma', 'Yetgazma', Icons.local_shipping_outlined,
      Icons.local_shipping_rounded),
  ombor('ombor', 'Ombor', 'Omborxona', Icons.warehouse_outlined,
      Icons.warehouse_rounded);

  const WorkSection(
      this.key, this.shortLabel, this.label, this.icon, this.selectedIcon);

  final String key;

  /// Pastki menyudagi qisqa nom.
  final String shortLabel;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Vakolat berish ekranida ko'rsatiladigan qisqa izoh.
  String get accessHint {
    switch (this) {
      case WorkSection.yangi:
        return 'Yangi buyurtma yaratish, bugungi buyurtmalar';
      case WorkSection.yuvish:
        return 'Xizmat qo\'shish, o\'lchash, yuvish, qadoqlashga o\'tkazish';
      case WorkSection.qadoqlash:
        return 'Qadoqlandi belgilash, qayta yuvishga qaytarish';
      case WorkSection.yetgazma:
        return 'Olib kelish, qabul qilish, topshirish va to\'lov';
      case WorkSection.ombor:
        return 'Uzoq olib ketilmagan buyurtmalar va ularni topshirish';
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
