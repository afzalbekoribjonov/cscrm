import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';
import '../services/license_controller.dart';
import '../services/notification_center.dart';
import '../services/order_sync_service.dart';
import '../services/session_service.dart';

/// Tizimdan chiqaradi — avval tasdiqlash so'raydi.
///
/// Funksiya sifatida ochiq, chunki uni ikki joy chaqiradi: sozlamalar
/// ro'yxatidagi qator va bloklash ekranidagi tugma.
Future<void> confirmAndLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chiqish'),
      content: const Text('Tizimdan chiqishni tasdiqlaysizmi?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Chiqish'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  if (!context.mounted) return;

  // Navigator OLDINDAN olinadi.
  //
  // Sabab: quyidagi tozalash bu tugmani ekrandan olib tashlashi
  // mumkin. Masalan bloklash ekranidan chiqilganda
  // `LicenseController.stop()` holatni tozalaydi, `LicenseGate` esa
  // darhol boshqa ekranga o'tadi — tugma bilan birga uning
  // `context`i ham o'ladi. Ilgari kod shundan keyin
  // `context.mounted` ni tekshirib, JIMGINA chiqib ketardi:
  // sessiya tozalangan, lekin login ekrani ochilmagan — foydalanuvchi
  // bo'sh ekranda qolardi.
  final navigator = Navigator.of(context, rootNavigator: true);

  await AuthService().signOut();
  await SessionService().clearSession();
  // Keyingi foydalanuvchi oldingi biznesning obuna holatini ko'rib
  // qolmasligi uchun kesh ham tozalanadi.
  await LicenseController.instance.stop();
  await NotificationCenter.instance.stop();
  // Yuborilmagan buyurtmalar navbati ham tozalanadi: ular shu
  // foydalanuvchining ishi, keyingisiga o'tib ketmasligi kerak.
  await OrderSyncService.instance.stop();

  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

/// AppBar'larga qo'yiladigan "Chiqish" tugmasi.
///
/// Endi faqat BLOKLASH ekranida ishlatiladi: u yerda sozlamalarga
/// kirib bo'lmaydi, shuning uchun chiqish yo'li ko'rinib turishi kerak.
/// Ish ekranlarida chiqish sozlamalarga ko'chirilgan.
class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Chiqish',
      icon: const Icon(Icons.logout_rounded),
      onPressed: () => confirmAndLogout(context),
    );
  }
}
