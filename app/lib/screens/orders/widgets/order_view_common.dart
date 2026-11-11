import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/item_status.dart';
import '../../../models/order_history_entry.dart';
import '../../../models/order_status.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/money.dart';

/// Buyurtma ko'rinishi uchun umumiy formatlar va tarix yozuvlarining
/// "odam tilidagi" ko'rinishi.

final orderTimeFormat = DateFormat('dd.MM.yyyy, HH:mm');
final orderDateFormat = DateFormat('dd.MM.yyyy');

String statusLabel(String? key) {
  if (key == null) return '—';
  for (final s in OrderStatus.values) {
    if (s.key == key) return s.label;
  }
  return '—';
}

String itemStatusLabel(String? key) {
  if (key == null) return '—';
  for (final s in ItemStatus.values) {
    if (s.key == key) return s.label;
  }
  return '—';
}

ItemStatus? tryItemStatus(String? key) {
  if (key == null) return null;
  for (final s in ItemStatus.values) {
    if (s.key == key) return s;
  }
  return null;
}

/// Bitta tarix yozuvining ko'rinishi: ikonka, rang va tavsif.
class HistoryVisual {
  const HistoryVisual(this.icon, this.tone, this.text);
  final IconData icon;
  final StageTone tone;
  final String text;

  /// Eski kod uchun — to'ldirish rangi.
  Color get color => tone.fill;
}

HistoryVisual historyVisual(OrderHistoryEntry h) {
  switch (h.type) {
    case 'order_created':
      return HistoryVisual(
        Icons.note_add_rounded,
        StageTone.brand,
        'Buyurtma yaratildi (${statusLabel(h.toStatus)})',
      );
    case 'item_status_changed':
      final product = h.itemProductName ?? 'Xizmat';
      final to = tryItemStatus(h.toStatus);
      final reason = (h.note ?? '').isNotEmpty ? ' — sabab: ${h.note}' : '';
      final (icon, tone, verb) = switch (to) {
        ItemStatus.yuvilmoqda => (
            Icons.local_laundry_service_rounded,
            StageTone.washing,
            'yuvish boshlandi'
          ),
        ItemStatus.qadoqlashda => (
            Icons.inventory_2_rounded,
            StageTone.packaging,
            'qadoqlashga o\'tdi'
          ),
        ItemStatus.tayyor => (
            Icons.check_circle_rounded,
            StageTone.ready,
            'qadoqlandi, tayyor'
          ),
        ItemStatus.qaytaYuvildi => (
            Icons.replay_rounded,
            StageTone.rewash,
            'qayta yuvishga qaytarildi'
          ),
        _ => (
            Icons.swap_horiz_rounded,
            StageTone.neutral,
            '${itemStatusLabel(h.fromStatus)} → ${itemStatusLabel(h.toStatus)}'
          ),
      };
      return HistoryVisual(icon, tone, '$product: $verb$reason');
    case 'item_updated':
      return HistoryVisual(
        Icons.edit_rounded,
        StageTone.warning,
        '${h.itemProductName ?? 'Xizmat'} yangilandi'
        '${(h.note ?? '').isNotEmpty ? ': ${h.note}' : ''}',
      );
    case 'item_deleted':
      return HistoryVisual(
        Icons.delete_outline_rounded,
        StageTone.danger,
        h.note ?? '${h.itemProductName ?? 'Xizmat'} o\'chirildi',
      );
    case 'partial_delivery':
      return HistoryVisual(
        Icons.call_split_rounded,
        StageTone.almost,
        h.note ?? 'Xizmatlarning bir qismi topshirildi',
      );
    case 'debt_settled':
      return HistoryVisual(
        Icons.payments_rounded,
        StageTone.success,
        'Qarz to\'landi: ${formatSom(h.amount ?? 0)}'
        '${(h.method ?? '').isNotEmpty ? ' (${h.method})' : ''}',
      );
    default:
      if (h.toStatus == OrderStatus.yetgazildi.key) {
        return HistoryVisual(
          Icons.task_alt_rounded,
          StageTone.delivered,
          'Mijozga topshirildi${(h.note ?? '').isNotEmpty ? ' · ${h.note}' : ''}',
        );
      }
      if (h.fromStatus == OrderStatus.olibKelish.key &&
          h.toStatus == OrderStatus.yuvishda.key) {
        return const HistoryVisual(
          Icons.move_to_inbox_rounded,
          StageTone.pickup,
          'Mijozdan olib kelindi, sexga qabul qilindi',
        );
      }
      if ((h.note ?? '').isNotEmpty) {
        return HistoryVisual(Icons.info_outline_rounded, StageTone.neutral, h.note!);
      }
      return HistoryVisual(
        Icons.swap_horiz_rounded,
        StageTone.neutral,
        '${statusLabel(h.fromStatus)} → ${statusLabel(h.toStatus)}',
      );
  }
}
