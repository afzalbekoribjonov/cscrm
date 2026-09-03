import 'package:flutter/material.dart';

import '../models/staff_access.dart';
import '../screens/notifications/notifications_screen.dart';
import '../services/notification_center.dart';

/// App bar'ning o'ng yuqori burchagidagi bildirishnoma qo'ng'irog'i.
///
/// O'qilmaganlar soni ustida raqam bilan ko'rsatiladi. Raqam faqat
/// BOSHQALAR qilgan hodisalarni sanaydi — xodim o'z ishidan o'ziga
/// bildirishnoma olmaydi.
class NotificationAction extends StatelessWidget {
  const NotificationAction({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;
  final StaffAccess access;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationCenter.instance,
      builder: (context, _) {
        final count = NotificationCenter.instance.unreadCount;
        return IconButton(
          tooltip: 'Bildirishnomalar',
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            child: Icon(
              count > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
            ),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NotificationsScreen(
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                access: access,
              ),
            ),
          ),
        );
      },
    );
  }
}
