import 'package:flutter/material.dart';

/// Bo'lim vakolatlaridan tashqari beriladigan qo'shimcha huquqlar.
///
/// Bo'lim vakolati ([WorkSection]) "qaysi bo'limda ishlay oladi" degan
/// savolga javob bersa, bular "o'sha bo'lim ichida qanchalik ko'p narsa
/// qila oladi" degan savolga javob beradi. Ikkalasi ham talab qilinadi:
/// masalan "O'lchash" uchun xodimda ham Yuvish bo'limi vakolati, ham
/// [StaffPermission.measure] bo'lishi shart.
enum StaffPermission {
  discount(
    'discount',
    'Skidka berish',
    'To\'lov summasini buyurtma narxidan kam kiritish',
    Icons.percent_rounded,
  ),
  measure(
    'measure',
    'O\'lchash va narx',
    'Xizmat hajmini o\'lchash va narxini o\'zgartirish',
    Icons.straighten_rounded,
  ),
  reports(
    'reports',
    'Hisobotlarni ko\'rish',
    'Daromad va faollik bo\'limini ochish',
    Icons.insights_rounded,
  ),
  deleteOrder(
    'delete_order',
    'Buyurtmani o\'chirish',
    'Buyurtmani butunlay o\'chirib yuborish',
    Icons.delete_outline_rounded,
  ),
  editOrder(
    'edit_order',
    'Ma\'lumotlarni tahrirlash',
    'Mijoz ismi, telefoni, manzili va topshirish sanasi',
    Icons.edit_outlined,
  ),
  rewash(
    'rewash',
    'Qayta yuvishga qaytarish',
    'Qadoqlashdagi xizmatni yuvishga qaytarish',
    Icons.replay_rounded,
  ),
  viewPhone(
    'view_phone',
    'Mijoz telefon raqami',
    'Raqamni to\'liq ko\'rish va unga qo\'ng\'iroq qilish',
    Icons.phone_rounded,
  ),
  comment(
    'comment',
    'Izoh qoldirish',
    'Buyurtma va xizmatlarga izoh yozish (o\'qish hammaga ochiq)',
    Icons.mode_comment_outlined,
  ),
  expenses(
    'expenses',
    'Chiqimlar',
    'Chiqimlarni ko\'rish, qo\'shish, tahrirlash va o\'chirish',
    Icons.receipt_long_rounded,
  ),
  debtors(
    'debtors',
    'Qarzdorlar',
    'Qarzdorlar ro\'yxatini ko\'rish va qarzni yopish',
    Icons.account_balance_wallet_outlined,
  ),
  manageItems(
    'manage_items',
    'Xizmatlarni boshqarish',
    'Buyurtmadagi xizmat turini almashtirish va o\'chirish',
    Icons.tune_rounded,
  );

  const StaffPermission(this.key, this.label, this.hint, this.icon);

  final String key;
  final String label;
  final String hint;
  final IconData icon;

  static StaffPermission? fromKey(String? key) {
    if (key == null) return null;
    for (final p in StaffPermission.values) {
      if (p.key == key) return p;
    }
    return null;
  }
}
