import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/delivery_sort.dart';
import '../../utils/order_sections.dart';
import '../../widgets/count_banner.dart';
import '../../widgets/admin_action.dart';
import '../../widgets/settings_action.dart';
import '../../widgets/notification_action.dart';
import '../../widgets/my_activity_action.dart';
import '../../widgets/order_card.dart';
import '../../widgets/order_search_action.dart';
import '../../widgets/finance_actions.dart';
import 'delivery_sort_bar.dart';

/// "Yetgazma" bo'limi - transport bilan bog'liq 3 bosqich: mijozdan olib
/// kelinishi kerak bo'lgan, sexda tayyor bo'lib mijozga yetgazilishi kerak
/// bo'lgan, va bugun yetgazib bo'lingan buyurtmalar.
class YetgazmaScreen extends StatefulWidget {
  const YetgazmaScreen({
    super.key,
    required this.sections,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  /// Bo'limlar HomeShell'da bir marta hisoblanadi - bu ekran filtrlamaydi.
  final OrderSections sections;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  State<YetgazmaScreen> createState() => _YetgazmaScreenState();
}

class _YetgazmaScreenState extends State<YetgazmaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  final _location = LocationService();

  var _sort = DeliverySort.all;
  var _locating = false;

  /// Dastavchikning oxirgi ma'lum joylashuvi.
  ///
  /// Bir marta olinadi va saqlanadi: har bir qayta chizishda GPS
  /// so'rash telefon batareyasini bekorga yeb qo'yardi. Ro'yxatni
  /// yangilash uchun "Manzil" ni qayta bosish kifoya.
  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Saralash usulini almashtiradi.
  ///
  /// "Manzil" tanlanganda GPS so'raladi. So'rov muvaffaqiyatsiz
  /// tugasa — masalan GPS o'chiq yoki ruxsat berilmagan — sabab
  /// ko'rsatiladi va OLDINGI saralash saqlanib qoladi: ro'yxatni
  /// tasodifiy tartibda qoldirish foydalanuvchini chalg'itardi.
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.sections.pickup;
    final ready = widget.sections.readyForDelivery;
    final deliveredToday = widget.sections.deliveredToday;

    return Scaffold(
      appBar: AppBar(
        leading: const SettingsAction(),
        title: const Text('Yetgazma'),
        actions: [
          NotificationAction(
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
          ),
          OrderSearchAction(
            orders: widget.sections.all,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
            section: WorkSection.yetgazma,
          ),
          ...financeActions(
            access: widget.access,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
          if (!widget.access.isAdmin && widget.access.has(WorkSection.yetgazma))
            MyActivityAction(
              currentUserId: widget.currentUserId,
              currentUserName: widget.currentUserName,
              access: widget.access,
            ),
          AdminAction(
            isAdmin: widget.access.isAdmin,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'Olib kelish (${pickup.length})'),
            Tab(text: 'Tayyor (${ready.length})'),
            Tab(text: 'Yetgazildi (${deliveredToday.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderList(
            orders: pickup,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
            emptyText: 'Olib kelinishi kerak bo\'lgan buyurtma yo\'q',
          ),
          // "Tayyor" — yagona saralanadigan ro'yxat. Qolgan ikkitasi
          // boshqa mantiqqa ega: birida buyurtmani olib kelish kerak,
          // ikkinchisi esa tugagan ish.
          Column(
            children: [
              DeliverySortBar(
                value: _sort,
                locating: _locating,
                onChanged: _changeSort,
              ),
              Expanded(
                child: _OrderList(
                  orders: sortDeliveries(
                    ready,
                    _sort,
                    fromLat: _lat,
                    fromLng: _lng,
                  ),
                  currentUserId: widget.currentUserId,
                  currentUserName: widget.currentUserName,
                  access: widget.access,
                  emptyText: 'Yetgazishga tayyor buyurtma yo\'q',
                  showDistance: _sort == DeliverySort.distance,
                  fromLat: _lat,
                  fromLng: _lng,
                ),
              ),
            ],
          ),
          _OrderList(
            orders: deliveredToday,
            currentUserId: widget.currentUserId,
            currentUserName: widget.currentUserName,
            access: widget.access,
            emptyText: 'Bugun hali yetgazilgan buyurtma yo\'q',
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
    required this.emptyText,
    this.showDistance = false,
    this.fromLat,
    this.fromLng,
  });

  final List<Order> orders;
  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;
  final String emptyText;

  /// Kartada manzildan keyin masofa yozilsinmi.
  ///
  /// Faqat "Manzil" bo'yicha saralanganda: boshqa tartiblarda masofa
  /// hech narsani tushuntirmaydi va shunchaki shovqin bo'lib qoladi.
  final bool showDistance;

  final double? fromLat;
  final double? fromLng;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(emptyText, style: Theme.of(context).textTheme.bodyMedium),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      itemCount: orders.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) return CountBanner(count: orders.length);
        final order = orders[index - 1];
        return OrderCard(
          order: order,
          currentUserId: currentUserId,
          currentUserName: currentUserName,
          access: access,
          section: WorkSection.yetgazma,
          distanceMeters: showDistance
              ? distanceTo(order, fromLat: fromLat, fromLng: fromLng)
              : null,
        );
      },
    );
  }
}
