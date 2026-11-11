import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../models/system_message.dart';
import '../../services/message_center.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/uz_dates.dart';

/// Xabarlar — faqat CSCRM'dan keladigan e'lonlar, eslatmalar va takliflar.
///
/// Ilgari bu yerda ikkinchi bo'lim ham bor edi: "Faoliyat" (sexdagi har
/// bir harakat). U kuniga o'nlab yozuv berardi, muhim xabarlarni ko'mib
/// yuborardi va har bir buyurtma o'zgarishida qayta hisoblanardi. Endi
/// faqat xabarlar qoldi.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  /// Ekran ochilgandagi o'qilmaganlar — ular ajratib ko'rsatiladi, garchi
  /// ochilishi bilan "o'qildi" deb belgilansa ham.
  late final Set<String> _unreadOnOpen = {
    for (final m in MessageCenter.instance.messages)
      if (MessageCenter.instance.isUnread(m)) m.id,
  };

  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MessageCenter.instance.markAllSeen();
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await MessageCenter.instance.refresh();
    await MessageCenter.instance.markAllSeen();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xabarlar')),
      body: ListenableBuilder(
        listenable: MessageCenter.instance,
        builder: (context, _) {
          final messages = MessageCenter.instance.messages;
          if (messages.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: EmptyState(
                      icon: Icons.mark_email_read_outlined,
                      tone: StageTone.brand,
                      title: _refreshing ? 'Yangilanmoqda…' : 'Hozircha xabar yo\'q',
                      message: 'CSCRM\'dan yangilik, eslatma yoki taklif '
                          'kelganda shu yerda ko\'rinadi.',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(Gap.page, 8, Gap.page,
                  24 + MediaQuery.of(context).padding.bottom),
              itemCount: messages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _MessageCard(
                message: messages[i],
                fresh: _unreadOnOpen.contains(messages[i].id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.fresh});

  final SystemMessage message;
  final bool fresh;

  (StageTone, IconData) get _kind => switch (message.kind) {
        'eslatma' => (StageTone.warning, Icons.notifications_active_outlined),
        'taklif' => (StageTone.success, Icons.local_offer_outlined),
        _ => (StageTone.brand, Icons.campaign_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (tone, icon) = _kind;
    final when = DateTime.fromMillisecondsSinceEpoch(message.createdAt);

    return AppCard(
      borderColor: fresh ? tone.fill.withValues(alpha: 0.45) : null,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, tone: tone, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TonePill(label: message.kindLabel, tone: tone, dense: true),
                    if (fresh) ...[
                      const SizedBox(width: 6),
                      const TonePill(
                          label: 'Yangi', tone: StageTone.danger, dense: true),
                    ],
                    const Spacer(),
                    Text(UzDates.dateTime(when),
                        style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 8),
                Text(message.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  message.body,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: context.colorTextSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
