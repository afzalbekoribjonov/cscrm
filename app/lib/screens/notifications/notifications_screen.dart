import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../services/notification_center.dart';
import '../../theme/app_colors.dart';
import '../orders/order_detail_screen.dart';

final _timeFormat = DateFormat('HH:mm');
final _dayFormat = DateFormat('dd.MM');

/// Bildirishnomalar ro'yxati.
///
/// Ro'yxat buyurtmalar tarixidan hisoblanadi va faqat BOSHQALAR qilgan
/// hodisalarni ko'rsatadi — o'z harakati qaytib kelmaydi.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Ekran ochilgandagi holat — o'qilmaganlar shu ro'yxatga qarab
  /// belgilanadi. Aks holda `markAllSeen` darhol hammasini "o'qilgan"
  /// qilib, foydalanuvchi qaysi biri yangi ekanini ko'rmay qolardi.
  late final Set<String> _unreadOnOpen = {
    for (final n in NotificationCenter.instance.items)
      if (NotificationCenter.instance.isUnread(n)) n.id,
  };

  @override
  void initState() {
    super.initState();
    // Ekran ochildi - hammasi ko'rilgan hisoblanadi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationCenter.instance.markAllSeen();
    });
  }

  void _open(AppNotification n) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          orderId: n.orderId,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
          access: widget.access,
          // Bildirishnomadan ochilgan buyurtma FAQAT KO'RISH uchun:
          // qaysi bo'limdan ochilgani noma'lum, vakolat esa bo'limga
          // bog'liq (qarang: StaffAccess.canActIn).
          section: widget.access.isAdmin ? WorkSection.yangi : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirishnomalar')),
      body: ListenableBuilder(
        listenable: NotificationCenter.instance,
        builder: (context, _) {
          final items = NotificationCenter.instance.items;

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 44,
                      color: context.colorTextSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Yangi bildirishnoma yo\'q',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Boshqa xodimlar buyurtma ustida ish qilganda '
                      'shu yerda ko\'rinadi.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(
                12, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _NotificationTile(
              notification: items[i],
              highlight: _unreadOnOpen.contains(items[i].id),
              onTap: () => _open(items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.highlight,
    required this.onTap,
  });

  final AppNotification notification;
  final bool highlight;
  final VoidCallback onTap;

  String get _time {
    final at = DateTime.fromMillisecondsSinceEpoch(notification.at);
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay ? _timeFormat.format(at) : _dayFormat.format(at);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = notification.type;

    return Material(
      color: highlight
          ? type.color.withValues(alpha: 0.07)
          : context.colorSurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight ? type.color.withValues(alpha: 0.35) : context.colorBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(type.icon, size: 18, color: type.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            type.label,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (highlight)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: type.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(_time, style: theme.textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${notification.orderCode} · ${notification.customerName}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (notification.byName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.byName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.colorTextSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
