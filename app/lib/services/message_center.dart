import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/system_message.dart';
import 'api_client.dart';

/// CSCRM'dan kelgan xabarlarni olib keladi va o'qilganini eslab qoladi.
///
/// "O'qildi" belgisi QURILMADA saqlanadi, serverda emas. Server tomonda
/// saqlansa, har bir xabar uchun har bir foydalanuvchidan yozuv kerak
/// bo'lardi — foydasi esa deyarli yo'q, chunki bu shaxsiy qulaylik.
class MessageCenter extends ChangeNotifier {
  MessageCenter._();

  static final MessageCenter instance = MessageCenter._();

  static const _kSeen = 'seen_message_ids';

  List<SystemMessage> _messages = const [];
  Set<String> _seen = {};
  var _loaded = false;

  List<SystemMessage> get messages => _messages;

  /// O'qilmagan xabarlar soni — qo'ng'iroq ustidagi raqamga qo'shiladi.
  int get unreadCount =>
      _messages.where((m) => !_seen.contains(m.id)).length;

  bool isUnread(SystemMessage m) => !_seen.contains(m.id);

  /// Serverdan xabarlarni oladi.
  ///
  /// Xatolik JIM yutiladi: xabarlar qo'shimcha ma'lumot, ular
  /// kelmagani uchun ish ekranlari buzilmasligi kerak.
  Future<void> refresh({ApiClient? api}) async {
    try {
      final response =
          await (api ?? ApiClient.instance).get('/api/v1/license/messages');
      final raw = response['messages'];
      if (raw is! List) return;

      _messages = [
        for (final m in raw)
          if (m is Map) SystemMessage.fromJson(Map<String, dynamic>.from(m)),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      await _loadSeen();
      notifyListeners();
    } catch (e) {
      debugPrint('Xabarlarni olib bo\'lmadi: $e');
    }
  }

  Future<void> _loadSeen() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _seen = (prefs.getStringList(_kSeen) ?? const []).toSet();
    _loaded = true;
  }

  /// Hammasi ko'rilgan deb belgilaydi.
  ///
  /// Faqat HOZIRGI xabarlar yoziladi: o'chirilgan xabarlarning ID'si
  /// ro'yxatda abadiy qolib, u cheksiz o'sib ketmasin.
  Future<void> markAllSeen() async {
    await _loadSeen();
    final ids = _messages.map((m) => m.id).toSet();
    if (_seen.containsAll(ids)) return;

    _seen = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSeen, _seen.toList());
    notifyListeners();
  }

  /// Chiqishda chaqiriladi.
  void clear() {
    _messages = const [];
    notifyListeners();
  }
}
