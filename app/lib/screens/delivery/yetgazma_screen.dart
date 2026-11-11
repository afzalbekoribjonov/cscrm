import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/order.dart';
import '../../models/work_section.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../ui/sheets.dart';
import '../../utils/delivery_sort.dart';
import '../../utils/order_sections.dart';
import '../../widgets/order_list_view.dart';
import '../home/section_scaffold.dart';
import 'delivery_sort_bar.dart';

/// "Yetgazma" bo'limi — uchta ro'yxat:
///  * **Olib kelish** — mijozdan olib kelinishi kerak;
///  * **Deyarli tayyor** — kamida bitta xizmati tayyor, qolgani sexda
///    (tayyorlarini bo'lib topshirish mumkin);
///  * **Tayyor** — hamma xizmati tayyor, topshirish kutilmoqda.
///
/// Ilgari uchinchi ro'yxat "Yetgazildi" edi — bugun topshirilganlar. U
/// ish ro'yxati emas (qilinadigan ish yo'q) va qo'shimcha so'rov talab
/// qilardi. Bugungi natijalar boshqaruvchining "Asosiy" sahifasida.
class YetgazmaScreen extends StatefulWidget {
  const YetgazmaScreen({
    super.key,
    required this.sections,
    required this.user,
  });

  final OrderSections sections;
  final AppUser user;

  @override
  State<YetgazmaScreen> createState() => _YetgazmaScreenState();
}

class _YetgazmaScreenState extends State<YetgazmaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _location = LocationService();

  var _sort = DeliverySort.all;
  var _locating = false;

  /// Dastavchikning oxirgi ma'lum joylashuvi — bir marta olinadi:
  /// har chizishda GPS so'rash batareyani bekorga sarflardi.
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _changeSort(DeliverySort sort) async {
    if (sort != DeliverySort.distance) {
      setState(() => _sort = sort);
      return;
    }
    setState(() => _locating = true);
    try {
      final position = await _location.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _sort = DeliverySort.distance;
      });
    } on LocationFailure catch (e) {
      if (mounted) showResult(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _sortable(List<Order> orders, String emptyTitle, IconData icon,
      String emptyMessage) {
    return Column(
      children: [
        DeliverySortBar(
          value: _sort,
          locating: _locating,
          onChanged: _changeSort,
        ),
        Expanded(
          child: OrderListView(
            orders: sortDeliveries(orders, _sort, fromLat: _lat, fromLng: _lng),
            user: widget.user,
            section: WorkSection.yetgazma,
            emptyIcon: icon,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            showPrice: true,
            distanceOf: _sort == DeliverySort.distance
                ? (o) => distanceTo(o, fromLat: _lat, fromLng: _lng)
                : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sections;
    return SectionScaffold(
      user: widget.user,
      section: WorkSection.yetgazma,
      sections: s,
      subtitle: s.deliveryBadgeCount == 0
          ? 'Hozircha ish yo\'q'
          : '${s.deliveryBadgeCount} ta buyurtma kutilmoqda',
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabs: [
          _CountTab(label: 'Olib kelish', count: s.pickup.length),
          _CountTab(
            label: 'Deyarli tayyor',
            count: s.almostReady.length,
            tone: StageTone.almost,
          ),
          _CountTab(
            label: 'Tayyor',
            count: s.readyForDelivery.length,
            tone: StageTone.ready,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          OrderListView(
            orders: s.pickup,
            user: widget.user,
            section: WorkSection.yetgazma,
            emptyIcon: Icons.moped_outlined,
            emptyTitle: 'Olib kelinadigan buyurtma yo\'q',
            emptyMessage: '"Olib kelish" turidagi yangi buyurtmalar shu yerga '
                'tushadi.',
          ),
          _sortable(
            s.almostReady,
            'Deyarli tayyor buyurtma yo\'q',
            Icons.timelapse_rounded,
            'Kamida bitta xizmati tayyor bo\'lgan buyurtmalar shu yerda '
                'ko\'rinadi — ularni bo\'lib topshirish mumkin.',
          ),
          _sortable(
            s.readyForDelivery,
            'Topshirishga tayyor buyurtma yo\'q',
            Icons.check_circle_outline_rounded,
            'Hamma xizmati tayyor bo\'lgan buyurtmalar shu yerga tushadi.',
          ),
        ],
      ),
    );
  }
}

class _CountTab extends StatelessWidget {
  const _CountTab({
    required this.label,
    required this.count,
    this.tone = StageTone.pickup,
  });

  final String label;
  final int count;
  final StageTone tone;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: tone.soft(context),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: tone.ink(context),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
