import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/item_status.dart';
import '../../../models/order_history_entry.dart';
import '../../../models/order_status.dart';
import '../../../theme/app_colors.dart';

/// Buyurtma ko'rinishi uchun umumiy formatlar, ranglar va matnlar.
///
/// Bular ilgari `order_detail_screen.dart` ichida edi. Ekran bo'laklarga
/// ajratilgach, ular bir nechta faylga kerak bo'lib qoldi - shuning uchun
/// shu yerga chiqarildi.

final orderTimeFormat = DateFormat('dd.MM.yyyy, HH:mm');
final orderDateFormat = DateFormat('dd.MM.yyyy');

const Map<ItemStatus, Color> itemStatusColor = {
  ItemStatus.yuvilmoqda: AppColors.statusWashing,
  ItemStatus.qadoqlashda: AppColors.statusReadyDelivery,
  ItemStatus.tayyor: AppColors.statusDelivered,
  ItemStatus.qaytaYuvildi: AppColors.danger,
};

String statusLabel(String? key) {
  if (key == null) return '—';
  for (final s in OrderStatus.values) {
    if (s.key == key) return s.label;
  }
  return key;
}

String itemStatusLabel(String? key) {
  if (key == null) return '—';
  for (final s in ItemStatus.values) {
    if (s.key == key) return s.label;
  }
  return key;
}

ItemStatus? tryItemStatus(String? key) {
  if (key == null) return null;
  for (final s in ItemStatus.values) {
    if (s.key == key) return s;
  }
  return null;
}

/// Bitta tarix yozuvining ko'rinishi: ikonka, rang va inson tiliga
/// o'girilgan tavsif.
class HistoryVisual {
  const HistoryVisual(this.icon, this.color, this.text);
  final IconData icon;
  final Color color;
  final String text;
}

HistoryVisual historyVisual(OrderHistoryEntry h) {
  switch (h.type) {
    case 'order_created':
      return HistoryVisual(
        Icons.note_add_rounded,
        AppColors.primary,
        'Buyurtma yaratildi (${statusLabel(h.toStatus)})',
      );
    case 'item_status_changed':
      final product = h.itemProductName ?? 'Xizmat';
      final toStatus = tryItemStatus(h.toStatus);
      final color = toStatus == ItemStatus.qaytaYuvildi
          ? AppColors.danger
          : toStatus == ItemStatus.tayyor
              ? AppColors.statusDelivered
              : AppColors.statusReadyDelivery;
      final icon = toStatus == ItemStatus.qaytaYuvildi
          ? Icons.replay_rounded
          : toStatus == ItemStatus.tayyor
              ? Icons.check_circle_rounded
              : Icons.swap_horiz_rounded;
      final reason = h.note != null ? ' — sabab: ${h.note}' : '';
      return HistoryVisual(
        icon,
        color,
        '$product: ${itemStatusLabel(h.fromStatus)} → ${itemStatusLabel(h.toStatus)}$reason',
      );
    case 'item_updated':
      return HistoryVisual(
        Icons.edit_rounded,
        AppColors.warning,
        '${h.itemProductName ?? 'Xizmat'} yangilandi'
        '${h.note != null ? ': ${h.note}' : ''}',
      );
    default:
      if (h.note != null) {
        return HistoryVisual(
            Icons.local_shipping_rounded, AppColors.statusDelivered, h.note!);
      }
      return HistoryVisual(
        Icons.swap_horiz_rounded,
        AppColors.statusReadyDelivery,
        '${statusLabel(h.fromStatus)} → ${statusLabel(h.toStatus)}',
      );
  }
}

/// Buyurtmaning to'liq ko'rinishi. Jonli stream orqali ishlaydi.
///
/// Amallar ikki bosqichda cheklanadi: xodimda tegishli bo'lim vakolati
/// bo'lishi VA buyurtma aynan o'sha bo'limdan ochilgan bo'lishi shart
/// (qarang: [StaffAccess.canActIn]). Vakolat bo'lmasa tugmalar umuman
/// ko'rsatilmaydi - ekran faqat ko'rish rejimida ochiladi.
