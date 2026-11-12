import 'package:flutter/material.dart';

import '../models/item_status.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_status.dart';
import '../models/work_section.dart';
import '../theme/app_colors.dart';
import '../utils/date_utils.dart';
import '../utils/order_sections.dart';

/// Bitta holatning ko'rinishi: nom, ikonka va rang.
class StageVisual {
  const StageVisual(this.label, this.icon, this.tone);
  final String label;
  final IconData icon;
  final StageTone tone;
}

/// Xizmat bosqichi — topshirilgani alohida ("Topshirildi").
enum ItemStage {
  queued(StageVisual('Navbatda', Icons.hourglass_top_rounded, StageTone.queued)),
  washing(StageVisual(
      'Yuvilmoqda', Icons.local_laundry_service_rounded, StageTone.washing)),
  rewash(StageVisual('Qayta yuvishda', Icons.replay_rounded, StageTone.rewash)),
  packaging(StageVisual(
      'Qadoqlashda', Icons.inventory_2_rounded, StageTone.packaging)),
  ready(StageVisual('Tayyor', Icons.check_circle_rounded, StageTone.ready)),
  handed(StageVisual('Topshirildi', Icons.task_alt_rounded, StageTone.delivered));

  const ItemStage(this.visual);
  final StageVisual visual;

  static ItemStage of(OrderItem item) {
    if (item.isHanded) return ItemStage.handed;
    return switch (item.status) {
      ItemStatus.navbatda => ItemStage.queued,
      ItemStatus.yuvilmoqda => ItemStage.washing,
      ItemStatus.qaytaYuvildi => ItemStage.rewash,
      ItemStatus.qadoqlashda => ItemStage.packaging,
      ItemStatus.tayyor => ItemStage.ready,
    };
  }

  /// Xizmat qaysi bo'limda ishlanadi.
  WorkSection? get section => switch (this) {
        ItemStage.queued || ItemStage.washing || ItemStage.rewash =>
          WorkSection.yuvish,
        ItemStage.packaging => WorkSection.qadoqlash,
        ItemStage.ready => WorkSection.yetgazma,
        ItemStage.handed => null,
      };
}

/// Buyurtmaning joyi — qidiruvda va kartalarda.
StageVisual placeVisual(OrderPlace place) => switch (place) {
      OrderPlace.pickup =>
        const StageVisual('Olib kelish', Icons.moped_rounded, StageTone.pickup),
      OrderPlace.workshop => const StageVisual(
          'Sexda', Icons.local_laundry_service_rounded, StageTone.washing),
      OrderPlace.almostReady => const StageVisual(
          'Deyarli tayyor', Icons.timelapse_rounded, StageTone.almost),
      OrderPlace.ready =>
        const StageVisual('Tayyor', Icons.check_circle_rounded, StageTone.ready),
      OrderPlace.warehouse =>
        const StageVisual('Omborda', Icons.warehouse_rounded, StageTone.warehouse),
      OrderPlace.delivered => const StageVisual(
          'Topshirilgan', Icons.task_alt_rounded, StageTone.delivered),
    };

/// Shu bo'limda ishlanadigan xizmatlar — buyurtma kartasi va ko'rinishida
/// faqat shular to'liq ko'rsatiladi.
///
/// Mijozdan OLIB KELINAYOTGAN buyurtmaning hamma xizmati Yetgazma
/// bo'liminiki: dastavchik aynan shularni olib keladi.
bool itemBelongsTo(OrderItem item, WorkSection? section, Order order) {
  if (section == null) return true;
  if (order.status == OrderStatus.olibKelish) {
    return section == WorkSection.yetgazma || section == WorkSection.yangi;
  }
  final stage = ItemStage.of(item);
  return switch (section) {
    WorkSection.yuvish => stage.section == WorkSection.yuvish,
    WorkSection.qadoqlash => stage == ItemStage.packaging,
    WorkSection.yetgazma || WorkSection.ombor => stage == ItemStage.ready,
    WorkSection.yangi => true,
  };
}

/// Muddat belgisi: "Bugun", "Ertaga", "3 kun", "2 kun o'tdi".
({String label, StageTone tone})? deadlineBadge(Order order, {DateTime? now}) {
  final deadline = order.deadline;
  if (deadline == null || order.status.isClosed) return null;
  final today = startOfDay(now ?? DateTime.now());
  final due = startOfDay(DateTime.fromMillisecondsSinceEpoch(deadline));
  final diff = due.difference(today).inDays;
  if (diff < 0) return (label: '${-diff} kun o\'tdi', tone: StageTone.danger);
  if (diff == 0) return (label: 'Bugun', tone: StageTone.danger);
  if (diff == 1) return (label: 'Ertaga', tone: StageTone.warning);
  return (label: '$diff kun', tone: StageTone.neutral);
}
