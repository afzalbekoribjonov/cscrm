import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../services/auth_service.dart';
import '../services/license_controller.dart';
import '../services/notification_center.dart';
import '../services/session_service.dart';

/// AppBar'larga qo'yiladigan umumiy "Chiqish" tugmasi - xodim va
/// boshqaruvchi sessiyasini tozalab, login ekraniga qaytaradi. Tasodifan
/// bosilib qolmasligi uchun avval tasdiqlash so'raladi.
class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  Future<void> _confirmAndLogout(BuildContext context) async {
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
    await AuthService().signOut();
    await SessionService().clearSession();
    // Keyingi foydalanuvchi oldingi biznesning obuna holatini ko'rib
    // qolmasligi uchun kesh ham tozalanadi.
    await LicenseController.instance.stop();
    await NotificationCenter.instance.stop();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Chiqish',
      icon: const Icon(Icons.logout_rounded),
      onPressed: () => _confirmAndLogout(context),
    );
  }
}
