import '../models/item_status.dart';
import '../models/order.dart';
import 'unit_amounts.dart';

/// "Yuvish" ro'yxatini saralash usullari.
enum WashSort {
  /// Topshirish kuni yaqinidan boshlab (muddatsizlar oxirida).
  /// Qayta yuvishga qaytganlar — har doim tepada: ular kechikkan ish.
  deadline('Topshirish kuni'),

  /// Eng eski buyurtmadan boshlab — navbat tartibi.
  date('Sana'),

  expensive('Qimmat'),
  cheap('Arzon');

  const WashSort(this.label);

  final String label;
}

/// Buyurtmalarni tanlangan usulda saralaydi. Kiruvchi ro'yxat
/// O'ZGARMAYDI — bo'limlar boshqa ekranlar bilan umumiy.
List<Order> sortWashOrders(List<Order> orders, WashSort sort) {
  final list = [...orders];
  int byDate(Order a, Order b) {
    final c = a.createdAt.compareTo(b.createdAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  }

  switch (sort) {
    case WashSort.deadline:
      int rank(Order o) =>
          o.items.any((i) => i.status == ItemStatus.qaytaYuvildi) ? 0 : 1;
      list.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        final da = a.deadline;
        final db = b.deadline;
        if (da != null && db != null && da != db) return da.compareTo(db);
        if (da != null && db == null) return -1;
        if (da == null && db != null) return 1;
        return byDate(a, b);
      });
    case WashSort.date:
      list.sort(byDate);
    case WashSort.expensive:
      list.sort((a, b) {
        final c = b.totalPrice.compareTo(a.totalPrice);
        return c != 0 ? c : byDate(a, b);
      });
    case WashSort.cheap:
      list.sort((a, b) {
        final c = a.totalPrice.compareTo(b.totalPrice);
        return c != 0 ? c : byDate(a, b);
      });
  }
  return list;
}

/// Yuvish bosqichidagi (navbatda, yuvilmoqda, qayta yuvishda) O'LCHANGAN
/// xizmatlarning jami hajmi — bo'lim tepasidagi ko'rsatkichlar.
UnitAmounts washVolume(List<Order> orders) {
  final out = UnitAmounts();
  for (final o in orders) {
    for (final i in o.items) {
      if (!i.status.isWashStage || i.isHanded || !i.hasNumericMeasure) {
        continue;
      }
      out.add(i.unit, i.quantity);
    }
  }
  return out;
}
