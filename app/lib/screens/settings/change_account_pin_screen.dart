import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/pin_pad.dart';

/// Xodim O'Z hisobining PIN-kodini almashtiradi.
///
/// Bu ILOVA QULFI EMAS. Bu — tizimga kiradigan PIN, u serverda
/// saqlanadi va kim ekanligingizni aniqlaydi.
///
/// Uch qadam: joriy PIN, yangi PIN, yangisini takrorlash. Joriy PIN
/// serverda tekshiriladi — busiz qo'lga tushgan ochiq telefon yetarli
/// bo'lardi.
class ChangeAccountPinScreen extends StatefulWidget {
  const ChangeAccountPinScreen({super.key, this.client});

  /// Sinovda almashtirish uchun. Odatda `null`.
  final ApiClient? client;

  @override
  State<ChangeAccountPinScreen> createState() => _ChangeAccountPinScreenState();
}

enum _Step { current, fresh, repeat }

class _ChangeAccountPinScreenState extends State<ChangeAccountPinScreen> {
  late final _api = widget.client ?? ApiClient.instance;
  final _padKey = GlobalKey<PinPadState>();

  var _step = _Step.current;
  String _current = '';
  String _fresh = '';
  String? _error;
  var _saving = false;

  Future<void> _onEntered(String pin) async {
    _padKey.currentState?.clear();

    switch (_step) {
      case _Step.current:
        setState(() {
          _current = pin;
          _step = _Step.fresh;
          _error = null;
        });
      case _Step.fresh:
        setState(() {
          _fresh = pin;
          _step = _Step.repeat;
          _error = null;
        });
      case _Step.repeat:
        if (pin != _fresh) {
          setState(() {
            _step = _Step.fresh;
            _error = 'PIN-kodlar mos kelmadi';
          });
          return;
        }
        await _save();
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _api.post(
        '/api/v1/employees/me/pin',
        body: {'currentPin': _current, 'newPin': _fresh},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
        // Joriy PIN xato bo'lsa — eng boshiga. Boshqa xatolikda
        // yangi PIN'ni qaytadan kiritish yetarli.
        _step = e.code == 'wrong_pin' ? _Step.current : _Step.fresh;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Ulanib bo\'lmadi. Internetni tekshiring.';
        _step = _Step.fresh;
      });
    }
  }

  String get _title => switch (_step) {
        _Step.current => 'Joriy PIN-kod',
        _Step.fresh => 'Yangi PIN-kod',
        _Step.repeat => 'Yangi PIN-kodni takrorlang',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PIN-kodni o\'zgartirish')),
      body: SafeArea(
        child: _saving
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const Spacer(),
                  Text(
                    _title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: _error != null
                        ? Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Text('4–8 xona', style: theme.textTheme.bodySmall),
                  ),
                  const Spacer(),
                  PinPad(
                    key: _padKey,
                    onCompleted: _onEntered,
                    submitLabel: 'Davom etish',
                  ),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }
}
