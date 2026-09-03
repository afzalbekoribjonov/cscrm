import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../models/staff_access.dart';
import '../../services/order_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_utils.dart';
import '../../utils/delivery_stats.dart';
import '../../widgets/item_measurement_form.dart' show fmtSom;
import '../../widgets/stat_tile.dart';
import '../../widgets/stream_error_view.dart';
import 'delivery_orders_screen.dart';

/// Xodimning o'zi bugun/kecha necha buyurtma olib kelgani, yetkazgani va
/// qo'lida qancha (naqd/karta) pul borligini ko'rsatadigan shaxsiy
/// faoliyat ekrani - faqat Yetgazma bo'limi vakolati bo'lgan xodimlarga
/// ochiq (qarang: [MyActivityAction]).
class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  bool _today = true;
  OrderService _service = OrderService();
  // Bir marta yaratilib saqlanadi - build() ichida chaqirilsa, Bugun/Kecha
  // almashtirilganda (setState) yangi Stream obyekti hosil bo'lib, ro'yxat
  // har safar "waiting" holatiga qaytib flicker qilardi.
  // Bugun va kecha ko'rsatiladi, shuning uchun ikki kunlik oyna
  // yetarli - butun tarixni yuklash shart emas.
  late Stream<List<Order>> _ordersStream = _service.streamOrdersForPeriod(
    startOfDay(DateTime.now().subtract(const Duration(days: 1))),
    endOfDay(DateTime.now()),
  );

  DateTime get _day {
    final now = DateTime.now();
    return _today ? now : now.subtract(const Duration(days: 1));
  }

  void _retry() => setState(() {
        _service = OrderService();
        _ordersStream = _service.streamOrdersForPeriod(
          startOfDay(DateTime.now().subtract(const Duration(days: 1))),
          endOfDay(DateTime.now()),
        );
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mening faoliyatim')),
      body: StreamBuilder<List<Order>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return StreamErrorView(error: snapshot.error!, onRetry: _retry);
          }
          final orders = snapshot.data ?? const <Order>[];
          final stats =
              deliveryStatsForEmployee(orders, widget.currentUserId, _day);
          final dayLabel = _today ? 'Bugungi' : 'Kechagi';

          return ListView(
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
            children: [
              _DayToggle(
                today: _today,
                onChanged: (v) => setState(() => _today = v),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.move_to_inbox_rounded,
                      color: AppColors.statusPickup,
                      value: '${stats.pickedUpCount}',
                      label: '$dayLabel olib kelgan',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.local_shipping_rounded,
                      color: AppColors.statusDelivered,
                      value: '${stats.deliveredCount}',
                      label: '$dayLabel yetkazgan',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      icon: Icons.payments_rounded,
                      color: AppColors.success,
                      value: fmtSom(stats.cashTotal),
                      label: 'Naqd pul',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      icon: Icons.credit_card_rounded,
                      color: AppColors.accent,
                      value: fmtSom(stats.cardTotal),
                      label: 'Karta orqali',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MoneyBanner(total: stats.moneyTotal),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: stats.deliveredCount == 0
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DeliveryOrdersScreen(
                                title: '$dayLabel yetkazmalarim',
                                orders: deliveredOn(
                                  orders,
                                  _day,
                                  employeeId: widget.currentUserId,
                                ),
                                currentUserId: widget.currentUserId,
                                currentUserName: widget.currentUserName,
                                access: widget.access,
                              ),
                            ),
                          ),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text('$dayLabel yetkazmalarni ko\'rish'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({required this.today, required this.onChanged});

  final bool today;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _segment(context, 'Bugun', today, () => onChanged(true)),
          ),
          Expanded(
            child: _segment(context, 'Kecha', !today, () => onChanged(false)),
          ),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? context.colorSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : context.colorTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _MoneyBanner extends StatelessWidget {
  const _MoneyBanner({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Jami qo\'lidagi pul',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          Text(
            fmtSom(total),
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
