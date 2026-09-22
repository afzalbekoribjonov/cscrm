import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../models/pending_order.dart';
import '../services/order_sync_service.dart';
import '../services/pending_order_store.dart';
import '../theme/app_colors.dart';
import '../utils/money.dart';

final _time = DateFormat('HH:mm');

/// Yangi buyurtma ekranining o'ng yuqori burchagidagi holat belgisi.
///
/// Uch holat:
///   * aylanuvchi doira — navbatda yuborilmagan buyurtma bor;
///   * belgi (✓) — hammasi yuborilgan;
///   * uzilgan bulut — aloqa yo'q va navbatda yozuv bor.
///
/// Bosilganda bugungi buyurtmalar ro'yxati ochiladi. Bu shunchaki
/// ko'rinish uchun emas: internetsiz yaratilgan buyurtmaning RAQAMI
/// hali yo'q, ya'ni foydalanuvchi uni boshqa hech qayerdan topa
/// olmaydi.
class SyncStatusAction extends StatelessWidget {
  const SyncStatusAction({super.key, required this.todaysOrders});

  /// Bugun yaratilgan, serverga yozilgan buyurtmalar.
  final List<Order> todaysOrders;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: OrderSyncService.instance.state,
      builder: (context, state, _) {
        return IconButton(
          tooltip: switch (state) {
            SyncState.idle => 'Bugungi buyurtmalar',
            SyncState.pending => 'Yuborilmoqda',
            SyncState.offline => 'Aloqa yo\'q — navbatda turibdi',
          },
          onPressed: () => _openSheet(context),
          icon: _Indicator(state: state),
        );
      },
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TodaySheet(todaysOrders: todaysOrders),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.state});

  final SyncState state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case SyncState.pending:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        );
      case SyncState.offline:
        return const Icon(Icons.cloud_off_rounded, color: AppColors.warning);
      case SyncState.idle:
        return const Icon(Icons.cloud_done_rounded, color: AppColors.success);
    }
  }
}

/// Bugungi buyurtmalar: yangisi tepada, yuborilmaganlari pastda.
class _TodaySheet extends StatelessWidget {
  const _TodaySheet({required this.todaysOrders});

  final List<Order> todaysOrders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<List<PendingOrder>>(
      valueListenable: PendingOrderStore.instance.orders,
      builder: (context, pending, _) {
        final sent = [...todaysOrders]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(
                  'Bugungi buyurtmalar',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),

                if (sent.isEmpty && pending.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text('Bugun buyurtma yo\'q',
                          style: theme.textTheme.bodyMedium),
                    ),
                  ),

                for (final order in sent)
                  _Row(
                    number: '№ ${order.id}',
                    name: order.customerName,
                    total: order.totalPrice,
                    at: DateTime.fromMillisecondsSinceEpoch(order.createdAt),
                  ),

                // Yuborilmaganlar PASTDA va alohida sarlavha bilan:
                // ular hali "bo'lib bo'lgan" ish emas, navbatda turgan
                // ish — ikkisini aralashtirib yuborish noto'g'ri.
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Text(
                        'Yuborilmoqda',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final order in pending.reversed)
                    _Row(
                      number: null,
                      name: order.customerName,
                      total: order.total,
                      at: DateTime.fromMillisecondsSinceEpoch(order.createdAt),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bitta qator. [number] `null` bo'lsa — raqam hali kutilmoqda.
class _Row extends StatelessWidget {
  const _Row({
    required this.number,
    required this.name,
    required this.total,
    required this.at,
  });

  final String? number;
  final String name;
  final double total;
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Raqam joyi QAT'IY kenglikda: raqam kelganda qolgan
          // ustunlar joyidan siljib ketmasligi kerak.
          SizedBox(
            width: 64,
            child: number == null
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Text(
                    number!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(_time.format(at), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${formatMoney(total.round())} so\'m',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
