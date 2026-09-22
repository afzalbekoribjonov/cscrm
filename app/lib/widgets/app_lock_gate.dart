import 'package:flutter/material.dart';

import '../screens/lock/app_lock_screen.dart';
import '../services/app_lock_service.dart';

/// Ilova qulfini boshqaradi: kerak bo'lganda qulf ekranini ko'rsatadi.
///
/// Qulf ikki holatda so'raladi:
///   * ilova ochilganda;
///   * fonda [_timeout] dan uzoq turib qaytganda.
///
/// Ikkinchi shart muhim: xodim buyurtma yozayotganda telefonni bir
/// zumga qo'yib olsa, qaytganda PIN so'ralmaydi. Telefon boshqa qo'lga
/// o'tib, biroz vaqt o'tgan bo'lsa esa so'raladi.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child, this.service});

  final Widget child;

  /// Sinovda almashtirish uchun. Odatda `null`.
  final AppLockService? service;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

/// Fonda qancha turgandan keyin PIN qayta so'raladi.
const _timeout = Duration(minutes: 1);

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  late final _lock = widget.service ?? AppLockService.instance;

  /// `null` — hali aniqlanmagan (qulf yoqilganmi, tekshirilmoqda).
  bool? _locked;

  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAtStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkAtStart() async {
    final enabled = await _lock.isEnabled();
    if (mounted) setState(() => _locked = enabled);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // Ketish vaqti FAQAT bir marta yoziladi: `paused` va `hidden`
        // ketma-ket kelishi mumkin, ikkinchisi hisobni nolga
        // qaytarib yuborardi.
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _onResumed() async {
    final leftAt = _leftAt;
    _leftAt = null;
    if (leftAt == null) return;
    if (DateTime.now().difference(leftAt) < _timeout) return;

    if (await _lock.isEnabled() && mounted) {
      setState(() => _locked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tekshiruv tugamaguncha ILOVA KO'RSATILMAYDI.
    //
    // Aks holda qulf yoqilgan bo'lsa ham, ekran bir lahzaga ochilib
    // ko'rinib ketardi — ya'ni qulfni aylanib o'tish uchun ilovani
    // ochib-yopish kifoya bo'lardi.
    if (_locked == null) {
      return const ColoredBox(
        color: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_locked!) {
      return AppLockScreen(
        service: widget.service,
        onUnlocked: () => setState(() => _locked = false),
      );
    }

    return widget.child;
  }
}
