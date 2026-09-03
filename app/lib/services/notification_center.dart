import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_notification.dart';
import '../models/order.dart';

/// Bildirishnomalarni va "o'qilgan" holatini boshqaradi.
///
/// Ro'yxat buyurtmalar tarixidan hisoblanadi (qarang: [buildNotifications]),
/// shuning uchun bu yerda faqat ikki narsa saqlanadi:
///  * oxirgi ko'rilgan vaqt — o'qilmaganlar sonini hisoblash uchun
///  * joriy ro'yxat — qo'ng'iroq va ro'yxat ekrani bir xil ma'lumot ko'rsin
///
/// "O'qilgan" holati QURILMADA saqlanadi. Bu ataylab: bildirishnoma
/// "menga ko'rsatilganmi" degan savol — u qurilmaga tegishli, bazaga emas.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();

  static final NotificationCenter instance = NotificationCenter._();

  static const _kLastSeen = 'notifications_last_seen';

  /// Nechа kunlik hodisalar ko'rsatiladi.
  ///
  /// Buyurtmalar oqimi baribir faol + bugun yetgazilganlar bilan
  /// cheklangan, shuning uchun bu amalda yumshoq chegara.
  static const _windowDays = 3;

  List<AppNotification> _items = const [];
  int _lastSeenAt = 0;
  String _actorId = '';
  var _loaded = false;

  List<AppNotification> get items => _items;

  /// O'qilmaganlar soni — qo'ng'iroq ustidagi raqam.
  int get unreadCount => _items.where((n) => n.at > _lastSeenAt).length;

  bool isUnread(AppNotification n) => n.at > _lastSeenAt;

  /// Kirgandan keyin bir marta chaqiriladi.
  Future<void> start(String actorId) async {
    _actorId = actorId;
    final prefs = await SharedPreferences.getInstance();
    _lastSeenAt = prefs.getInt(_kLastSeen) ?? 0;
    _loaded = true;
    notifyListeners();
  }

  /// Buyurtmalar oqimi yangilanganda chaqiriladi.
  void update(List<Order> orders) {
    if (!_loaded) return;

    final since = DateTime.now()
        .subtract(const Duration(days: _windowDays))
        .millisecondsSinceEpoch;

    _items = buildNotifications(
      orders: orders,
      currentActorId: _actorId,
      since: since,
    );
    notifyListeners();
  }

  /// Ro'yxat ochilganda — hammasi o'qilgan deb belgilanadi.
  Future<void> markAllSeen() async {
    if (_items.isEmpty) return;
    final newest = _items.first.at;
    if (newest <= _lastSeenAt) return;

    _lastSeenAt = newest;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSeen, newest);
  }

  /// Chiqishda — keyingi foydalanuvchi oldingisining bildirishnomalarini
  /// ko'rib qolmasligi uchun.
  Future<void> stop() async {
    _items = const [];
    _lastSeenAt = 0;
    _actorId = '';
    _loaded = false;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastSeen);
  }
}
