import 'package:flutter/material.dart' hide Text;

import '../l10n/text.dart';
import '../screens/notifications/notifications_screen.dart';
import '../services/message_center.dart';

/// App bar'dagi xabarlar qo'ng'irog'i — o'qilmagan CSCRM xabarlari soni
/// bilan.
class NotificationAction extends StatelessWidget {
  const NotificationAction({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MessageCenter.instance,
      builder: (context, _) {
        final count = MessageCenter.instance.unreadCount;
        return IconButton(
          tooltip: t('Xabarlar'),
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            child: Icon(
              count > 0
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_none_rounded,
            ),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        );
      },
    );
  }
}
