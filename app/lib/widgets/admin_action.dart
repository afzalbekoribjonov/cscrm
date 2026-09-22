import 'package:flutter/material.dart';

import '../screens/admin/admin_home_screen.dart';

/// Boshqaruv bo'limiga kiruvchi tugma — AppBar'ning o'ng burchagida.
///
/// Ilgari u pastki menyuning O'RTASIDA, alohida bo'lim sifatida
/// turardi. Ikki kamchiligi bor edi:
///
///  * pastki menyu boshqaruvchida 5 ta, xodimda 4 ta bo'lib qolardi —
///    ya'ni bir xodim boshqasiga tushuntirganda ekranlar mos
///    kelmasdi;
///  * "Boshqaruv" ekran emas, alohida sahifa. Pastki menyu esa
///    ekranlar o'rtasida almashish uchun — u yerda "sahifa ochadigan"
///    tugma turishi tartibni buzardi.
///
/// Endi pastda hammada bir xil 4 ta bo'lim, boshqaruv esa yuqorida.
class AdminAction extends StatelessWidget {
  const AdminAction({
    super.key,
    required this.isAdmin,
    required this.currentUserId,
    required this.currentUserName,
  });

  /// Boshqaruvchi bo'lmasa tugma umuman chizilmaydi.
  final bool isAdmin;

  final String currentUserId;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Boshqaruv',
      icon: const Icon(Icons.admin_panel_settings_rounded),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AdminHomeScreen(
            currentUserId: currentUserId,
            currentUserName: currentUserName,
          ),
        ),
      ),
    );
  }
}
