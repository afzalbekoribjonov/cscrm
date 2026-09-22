import 'package:flutter/material.dart';

import '../screens/settings/settings_screen.dart';

/// AppBar'ning chap tomonidagi "Sozlamalar" tugmasi.
///
/// Ilgari bu joyda xodimning ismi yozilgan matn turardi. U hech
/// qanday ish bajarmasdi — foydalanuvchi o'z ismini allaqachon biladi.
/// Endi shu joy ishlaydigan tugmaga aylandi, ism esa sozlamalar
/// ichida turibdi.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Sozlamalar',
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    );
  }
}
