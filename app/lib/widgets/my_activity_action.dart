import 'package:flutter/material.dart';

import '../models/staff_access.dart';
import '../screens/activity/my_activity_screen.dart';

/// AppBar'ga qo'yiladigan tugma - faqat Yetgazma bo'limi vakolati bo'lgan
/// xodimlarga ko'rinadi, bosilganda xodimning o'zi bugun/kecha necha
/// buyurtma olib kelgani/yetkazgani va qo'lidagi pulini ko'rsatadigan
/// [MyActivityScreen] ochiladi.
class MyActivityAction extends StatelessWidget {
  const MyActivityAction({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    required this.access,
  });

  final String currentUserId;
  final String currentUserName;

  /// Xodimning haqiqiy vakolatlari - shu ekrandan ochilgan buyurtmalarga
  /// ortiqcha huquq berilmasligi (va telefon raqami vakolatga qarab
  /// ko'rinishi) uchun o'zgarishsiz uzatiladi.
  final StaffAccess access;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Mening faoliyatim',
      icon: const Icon(Icons.account_balance_wallet_rounded),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MyActivityScreen(
            currentUserId: currentUserId,
            currentUserName: currentUserName,
            access: access,
          ),
        ),
      ),
    );
  }
}
