import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/staff_access.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/order_card.dart';
import '../../widgets/order_search_action.dart';
import '../../widgets/period_calendar.dart';
import '../../widgets/stream_error_view.dart';

/// Boshqaruvchi uchun barcha buyurtmalar tarixi - haqiqiy kalendar bo'yicha
/// kunlik/haftalik/oylik filtr, shu davrdagi buyurtmalar soni va daromad.
class OrdersAdminScreen extends StatefulWidget {
  const OrdersAdminScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  final String currentUserId;
  final String currentUserName;

  @override
  State<OrdersAdminScreen> createState() => _OrdersAdminScreenState();
}

class _OrdersAdminScreenState extends State<OrdersAdminScreen> {
  DateTime _rangeStart = startOfMonth(DateTime.now());
  DateTime _rangeEnd = endOfMonth(DateTime.now());
  OrderService _service = OrderService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa, kalendar
  // oralig'i almashtirilganda (setState) yangi Stream obyekti hosil bo'lib,
  // ro'yxat har safar "waiting" holatiga qaytib flicker qilardi.
  // Boshqaruv ro'yxati: oxirgi buyurtmalar. Qidiruv shu to'plam
  // ichida ishlaydi - butun tarixni yuklash shart emas.
  late Stream<List<Order>> _ordersStream = _service.streamRecentOrders();

  void _retry() => setState(() {
        _service = OrderService();
        _ordersStream = _service.streamRecentOrders();
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<List<Order>>(
      stream: _ordersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Buyurtmalar')),
            body: StreamErrorView(error: snapshot.error!, onRetry: _retry),
          );
        }
        final allOrders = snapshot.data ?? const <Order>[];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Buyurtmalar'),
            actions: [
              OrderSearchAction(
                orders: allOrders,
                currentUserId: widget.currentUserId,
                currentUserName: widget.currentUserName,
                access: const StaffAccess.admin(),
              ),
              const LogoutAction(),
            ],
          ),
          body: Builder(
            builder: (context) {
              final now = DateTime.now();
              final thisMonthOrders = allOrders
                  .where((o) => isWithinRange(
                      o.createdAt, startOfMonth(now), endOfMonth(now)))
                  .toList();
              final thisMonthRevenue = thisMonthOrders.fold<double>(
                  0, (sum, o) => sum + o.totalPrice);

              final filtered = allOrders
                  .where(
                      (o) => isWithinRange(o.createdAt, _rangeStart, _rangeEnd))
                  .toList();
              final filteredRevenue =
                  filtered.fold<double>(0, (sum, o) => sum + o.totalPrice);

              return ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                children: [
                  _MonthSummaryCard(
                    count: thisMonthOrders.length,
                    revenue: thisMonthRevenue,
                  ),
                  const SizedBox(height: 18),
                  PeriodCalendar(
                    onRangeChanged: (start, end) {
                      setState(() {
                        _rangeStart = start;
                        _rangeEnd = end;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniStat(
                            label: 'Buyurtmalar', value: '${filtered.length}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MiniStat(
                          label: 'Daromad',
                          value: '${filteredRevenue.toStringAsFixed(0)} so\'m',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Bu davrda buyurtma yo\'q',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (order) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: OrderCard(
                          order: order,
                          currentUserId: widget.currentUserId,
                          currentUserName: widget.currentUserName,
                          access: const StaffAccess.admin(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.count, required this.revenue});

  final int count;
  final double revenue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shu oy',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count buyurtma',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Daromad',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                '${revenue.toStringAsFixed(0)} so\'m',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
