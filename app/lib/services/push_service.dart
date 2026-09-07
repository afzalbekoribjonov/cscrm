import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'message_center.dart';

/// Ilova YOPIQ bo'lganda kelgan xabar.
///
/// Android bu funksiyani alohida izolyatda chaqiradi — shuning uchun u
/// yuqori darajada (top-level) bo'lishi SHART va ilovaning boshqa
/// holatiga murojaat qila olmaydi.
///
/// Bu yerda hech narsa qilmaymiz: bildirishnomani Android o'zi
/// ko'rsatadi (`notification` maydoni bilan yuborilgan). Ilova
/// ochilganda xabarlar serverdan baribir qayta o'qiladi.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {}

/// Push bildirishnomalar.
///
/// Xabar IKKI YO'L bilan yetadi:
///  * push — telefon ekranida darhol (ilova yopiq bo'lsa ham);
///  * ilova ichida — qo'ng'iroq ostidagi "Xabarlar" bo'limida.
///
/// Push QO'SHIMCHA yo'l: u ishlamasa ham (ruxsat berilmagan, internet
/// yo'q, token eskirgan) xabar yo'qolmaydi — u serverda saqlanadi va
/// ilova ochilganda ko'rinadi. Shuning uchun bu yerdagi har bir
/// xatolik jim yutiladi.
///
/// PUSH FAQAT CSCRM XABARLARI UCHUN. "Faoliyat" bo'limidagi hodisalar
/// (kim qaysi buyurtmada nima qildi) push bilan YUBORILMAYDI: ular
/// kuniga o'nlab bo'ladi va telefonni tinimsiz chiringlatardi. Ular
/// ilovaning o'zida, buyurtma ma'lumotidan hisoblanadi va faqat
/// qo'ng'iroq ostida ko'rinadi.
class PushService {
  PushService._();

  static final PushService instance = PushService._();

  static const _kToken = 'push_token';

  /// Android kanali. Nomi backenddagi `channelId` bilan AYNAN bir xil
  /// bo'lishi shart — aks holda Android bildirishnomani jimgina
  /// tashlab yuboradi.
  static const _channel = AndroidNotificationChannel(
    'cscrm_messages',
    'CSCRM xabarlari',
    description: 'Yangilik, eslatma va takliflar',
    importance: Importance.high,
  );

  final _local = FlutterLocalNotificationsPlugin();
  var _started = false;

  /// Tizimga kirgandan keyin chaqiriladi.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      await _setupLocal();

      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      final messaging = FirebaseMessaging.instance;

      // Android 13+ da bildirishnoma uchun ruxsat so'raladi. Rad etilsa
      // ilova baribir ishlaydi - xabar faqat ichkarida ko'rinadi.
      await messaging.requestPermission();

      await _sendToken(await messaging.getToken());

      // Token vaqti-vaqti bilan yangilanadi.
      messaging.onTokenRefresh.listen(_sendToken);

      // Ilova OCHIQ turganda Android bildirishnomani o'zi
      // ko'rsatmaydi - uni o'zimiz chiqaramiz.
      FirebaseMessaging.onMessage.listen(_onForeground);
    } catch (e) {
      debugPrint('Push ishga tushmadi: $e');
    }
  }

  Future<void> _setupLocal() async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _onForeground(RemoteMessage message) async {
    // Yangi xabar keldi - ro'yxatni yangilaymiz, qo'ng'iroq ustidagi
    // raqam darhol o'zgarsin.
    unawaited(MessageCenter.instance.refresh());

    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Tokenni serverga yuboradi va qurilmada eslab qoladi.
  Future<void> _sendToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await ApiClient.instance.post(
        '/api/v1/license/push-token',
        body: {'token': token, 'platform': 'android'},
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kToken, token);
    } catch (e) {
      debugPrint('Push tokenini yuborib bo\'lmadi: $e');
    }
  }

  /// Chiqishda: bu qurilmaga endi xabar yuborilmasin.
  ///
  /// Muhim, chunki telefonni boshqa odam ishlatishi mumkin — chiqib
  /// ketgan foydalanuvchining biznesi haqidagi xabar unga bormasligi
  /// kerak.
  Future<void> stop() async {
    _started = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      if (token == null) return;
      await prefs.remove(_kToken);
      await ApiClient.instance.delete('/api/v1/license/push-token/$token');
    } catch (e) {
      debugPrint('Push tokenini o\'chirib bo\'lmadi: $e');
    }
  }
}
