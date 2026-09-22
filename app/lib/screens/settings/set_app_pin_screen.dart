import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/pin_pad.dart';

/// Ilova qulfi uchun PIN o'rnatish: kiriting, keyin takrorlang.
///
/// Takrorlash SHART: bu PIN'ni tiklab bo'lmaydi (u serverda emas,
/// qurilmada). Bir marta xato terilsa, foydalanuvchi o'z ilovasidan
/// chiqib qolardi.
class SetAppPinScreen extends StatefulWidget {
  const SetAppPinScreen({super.key, this.service});

  /// Sinovda almashtirish uchun. Odatda `null`.
  final AppLockService? service;

  @override
  State<SetAppPinScreen> createState() => _SetAppPinScreenState();
}

class _SetAppPinScreenState extends State<SetAppPinScreen> {
  late final _lock = widget.service ?? AppLockService.instance;
  final _padKey = GlobalKey<PinPadState>();

  String? _first;
  String? _error;

  Future<void> _onEntered(String pin) async {
    _padKey.currentState?.clear();

    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return;
    }

    if (_first != pin) {
      setState(() {
        _first = null;
        _error = 'PIN-kodlar mos kelmadi';
      });
      return;
    }

    await _lock.setPin(pin);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confirming = _first != null;

    return Scaffold(
      appBar: AppBar(title: const Text('PIN-kod')),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              confirming ? 'PIN-kodni takrorlang' : 'Yangi PIN-kod',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            // Balandlik qat'iy — xabar chiqqanda klaviatura sakramasin.
            SizedBox(
              height: 20,
              child: _error != null
                  ? Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Text(
                      '${AppLockService.minLength}–${AppLockService.maxLength} '
                      'xona',
                      style: theme.textTheme.bodySmall,
                    ),
            ),
            const Spacer(),
            PinPad(
              key: _padKey,
              onCompleted: _onEntered,
              minLength: AppLockService.minLength,
              maxLength: AppLockService.maxLength,
              submitLabel: confirming ? 'Tasdiqlash' : 'Davom etish',
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
