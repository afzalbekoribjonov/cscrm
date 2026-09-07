import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../models/system_message.dart';
import '../../models/staff_access.dart';
import '../../models/work_section.dart';
import '../../services/message_center.dart';
import '../../services/notification_center.dart';
import '../../theme/app_colors.dart';
import '../orders/order_detail_screen.dart';

final _timeFormat = DateFormat('HH:mm');
final _dayFormat = DateFormat('dd.MM');

/// Bildirishnomalar — IKKI BO'LIM.
///
///  * **Xabarlar** — CSCRM'dan: yangilik, eslatma, taklif.
///  * **Faoliyat** — sexdagi ish: kim qaysi buyurtmada nima qildi.
///
/// Nega ajratilgan: ikkalasi butunlay boshqa narsa va boshqa tezlikda
/// keladi. Faoliyat kuniga o'nlab yozuv beradi, xabar esa oyda bir
/// marta. Bitta ro'yxatda bo'lsa, muhim e'lon "buyurtma yetkazildi"
/// yozuvlari orasida ko'milib ketardi.
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

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  /// Ekran ochilgandagi holat — o'qilmaganlar shu ro'yxatga qarab
  /// belgilanadi. Aks holda `markAllSeen` darhol hammasini "o'qilgan"
  /// qilib, foydalanuvchi qaysi biri yangi ekanini ko'rmay qolardi.
  late final Set<String> _unreadOnOpen = {
    for (final n in NotificationCenter.instance.items)
      if (NotificationCenter.instance.isUnread(n)) n.id,
  };

  /// Xabarlar ham ochilgandagi holat bo'yicha belgilanadi.
  late final Set<String> _unreadMessagesOnOpen = {
    for (final m in MessageCenter.instance.messages)
      if (MessageCenter.instance.isUnread(m)) m.id,
  };

  @override
  void initState() {
    super.initState();
    // Ekran ochildi - hammasi ko'rilgan hisoblanadi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationCenter.instance.markAllSeen();
      MessageCenter.instance.markAllSeen();
    });
    // Ochilganda yangi xabar kelgan bo'lsa ko'rinsin.
    MessageCenter.instance.refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirishnomalar'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            _CountTab(
              label: 'Xabarlar',
              icon: Icons.campaign_rounded,
              listenable: MessageCenter.instance,
              count: () => MessageCenter.instance.unreadCount,
            ),
            _CountTab(
              label: 'Faoliyat',
              icon: Icons.history_rounded,
              listenable: NotificationCenter.instance,
              count: () => NotificationCenter.instance.unreadCount,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildMessages(context), _buildActivity(context)],
      ),
    );
  }

  /// CSCRM'dan kelgan xabarlar.
  Widget _buildMessages(BuildContext context) {
    return ListenableBuilder(
      listenable: MessageCenter.instance,
      builder: (context, _) {
        final items = MessageCenter.instance.messages;
        if (items.isEmpty) {
          return const _EmptyView(
            icon: Icons.campaign_outlined,
            title: 'Xabar yo\'q',
            text: 'CSCRM yangilik yoki eslatma yuborsa, shu yerda '
                'ko\'rinadi.',
          );
        }

        return RefreshIndicator(
          onRefresh: MessageCenter.instance.refresh,
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
                12, 12, 12, 12 + MediaQuery.of(context).padding.bottom),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _MessageTile(
              message: items[i],
              highlight: _unreadMessagesOnOpen.contains(items[i].id),
            ),
          ),
        );
      },
    );
  }

  /// Sexdagi ish — buyurtma hodisalari.
  Widget _buildActivity(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationCenter.instance,
      builder: (context, _) {
        final items = NotificationCenter.instance.items;

        if (items.isEmpty) {
          return const _EmptyView(
            icon: Icons.notifications_none_rounded,
            title: 'Yangi bildirishnoma yo\'q',
            text: 'Boshqa xodimlar buyurtma ustida ish qilganda '
                'shu yerda ko\'rinadi.',
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
    );
  }
}

/// Yorliq: nomi, ikonkasi va o'qilmaganlar soni.
class _CountTab extends StatelessWidget {
  const _CountTab({
    required this.label,
    required this.icon,
    required this.listenable,
    required this.count,
  });

  final String label;
  final IconData icon;
  final Listenable listenable;
  final int Function() count;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final n = count();
        return Tab(
          icon: Badge(
            label: Text('$n'),
            isLabelVisible: n > 0,
            child: Icon(icon, size: 20),
          ),
          text: label,
        );
      },
    );
  }
}

/// Bo'sh bo'lim ko'rinishi.
class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.colorTextSecondary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// CSCRM xabari.
class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.highlight});

  final SystemMessage message;
  final bool highlight;

  Color _kindColor() {
    switch (message.kind) {
      case 'eslatma':
        return AppColors.warning;
      case 'taklif':
        return AppColors.success;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _kindColor();
    final when = DateTime.fromMillisecondsSinceEpoch(message.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight
            ? color.withValues(alpha: 0.07)
            : context.colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? color.withValues(alpha: 0.35)
              : context.colorBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  message.kindLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_dayFormat.format(when)} · ${_timeFormat.format(when)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(message.body, style: theme.textTheme.bodyMedium),
        ],
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
