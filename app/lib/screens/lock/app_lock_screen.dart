import 'package:flutter/material.dart';

import '../../branding/logo.dart';
import '../../services/app_lock_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/pin_pad.dart';

/// Ilova qulfi ekrani — PIN yoki barmoq izi so'raydi.
///
/// Bu ekrandan CHIQIB bo'lmaydi: orqaga tugmasi ham, ekranni surish
/// ham ishlamaydi. Yagona yo'l — to'g'ri PIN. Aks holda qulfning
/// ma'nosi qolmasdi.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked, this.service});

  final VoidCallback onUnlocked;

  /// Sinovda almashtirish uchun. Odatda `null`.
  final AppLockService? service;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  late final _lock = widget.service ?? AppLockService.instance;
  final _padKey = GlobalKey<PinPadState>();

  var _wrong = false;
  var _biometricsReady = false;

  @override
  void initState() {
    super.initState();
    _tryBiometrics();
  }

  /// Barmoq izi yoqilgan bo'lsa — darhol so'raymiz.
  ///
  /// Foydalanuvchi uni bekor qilsa PIN kiritish qoladi, shuning uchun
  /// bu yerda hech qanday xatolik ko'rsatilmaydi.
  Future<void> _tryBiometrics() async {
    if (!await _lock.biometricsEnabled()) return;
    if (!mounted) return;
    setState(() => _biometricsReady = true);

    if (await _lock.authenticateBiometric()) {
      widget.onUnlocked();
    }
  }

  Future<void> _check(String pin) async {
    if (await _lock.verify(pin)) {
      widget.onUnlocked();
      return;
    }
    if (!mounted) return;
    setState(() => _wrong = true);
    _padKey.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      // Orqaga tugmasi qulfni ochib yubormasligi kerak.
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              const CscrmMark(size: 64),
              const SizedBox(height: 20),
              Text(
                'PIN-kodni kiriting',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              // Joy HAR DOIM band turadi — xatolik chiqqanda klaviatura
              // pastga sakrab ketmasligi uchun.
              SizedBox(
                height: 20,
                child: _wrong
                    ? const Text(
                        'PIN xato',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const Spacer(),
              PinPad(
                key: _padKey,
                onCompleted: _check,
                minLength: AppLockService.minLength,
                maxLength: AppLockService.maxLength,
                submitLabel: 'Ochish',
              ),
              if (_biometricsReady)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _tryBiometrics,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Barmoq izi'),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
