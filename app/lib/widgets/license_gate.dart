import 'package:flutter/material.dart';

import '../screens/subscription/subscription_blocked_screen.dart';
import '../services/license_controller.dart';

/// Obuna muddati tugagan bo'lsa ish ekranlari o'rniga to'lov ekranini
/// ko'rsatadi.
///
/// Ilova ochiq turganda ham tekshiradi (ilova old planga qaytganda va
/// davriy ravishda), shuning uchun muddat ish kuni o'rtasida tugasa ham
/// ekran o'zi almashadi — foydalanuvchi ilovani qayta ochishi shart emas.
///
/// Teskarisi ham ishlaydi: to'lov tasdiqlangach ilova o'zi ochiladi.
class LicenseGate extends StatefulWidget {
  const LicenseGate({
    super.key,
    required this.tenantId,
    required this.isOwner,
    required this.child,
  });

  final String tenantId;
  final bool isOwner;
  final Widget child;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LicenseController.instance.start(widget.tenantId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Telefon cho'ntakda uzoq turgan bo'lishi mumkin - qaytganda holatni
    // yangilaymiz. To'lov qilingan bo'lsa ilova darhol ochiladi.
    if (state == AppLifecycleState.resumed) {
      LicenseController.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LicenseController.instance,
      builder: (context, child) {
        final resolution = LicenseController.instance.value;

        // Holat hali aniqlanmagan (birinchi so'rov ketmoqda) yoki umuman
        // aniqlanmadi - ilovani ochiq qoldiramiz.
        //
        // Bu ATAYLAB shunday: tarmoq muammosi tufayli ishlab turgan
        // biznesni to'xtatib qo'yish xatolikdan ko'ra qimmatroq. Server
        // javob berganda haqiqiy holat baribir qo'llanadi, va litsenziyani
        // mijoz tomondan o'zgartirib bo'lmaydi (Database qoidalari).
        final status = resolution?.status;
        if (status == null || !status.blocked) return child!;

        return SubscriptionBlockedScreen(
          status: status,
          isOwner: widget.isOwner,
        );
      },
      child: widget.child,
    );
  }
}
