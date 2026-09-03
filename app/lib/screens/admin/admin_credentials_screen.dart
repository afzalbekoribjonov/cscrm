import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../auth/login_screen.dart';

/// Boshqaruvchi hisobining login va parolini o'zgartirish.
///
/// Bitta forma, bitta "Saqlash" tugmasi: login va parol birga, bitta
/// amalda o'zgaradi. (Avvalgi versiyada ikkita alohida tugma bor edi -
/// birinchisi bosilgach foydalanuvchi tizimdan chiqarilib, ikkinchi
/// o'zgarish saqlanmay qolar edi.)
class AdminCredentialsScreen extends StatefulWidget {
  const AdminCredentialsScreen({super.key, required this.currentLogin});

  /// Joriy login - HomeShell/AdminHomeScreen orqali sessiyadan uzatiladi,
  /// shu sabab bu yerda qayta so'ralmaydi va hech qachon noaniq bo'lmaydi.
  final String currentLogin;

  @override
  State<AdminCredentialsScreen> createState() => _AdminCredentialsScreenState();
}

class _AdminCredentialsScreenState extends State<AdminCredentialsScreen> {
  final _authService = AuthService();

  final _currentPassCtrl = TextEditingController();
  late final _newLoginCtrl = TextEditingController(text: widget.currentLogin);
  final _newPassCtrl = TextEditingController();
  final _repeatPassCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Tugma holati va xulosa matni jonli yangilanib turishi uchun.
    for (final ctrl in [_newLoginCtrl, _newPassCtrl, _repeatPassCtrl]) {
      ctrl.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => setState(() => _error = null);

  @override
  void dispose() {
    for (final ctrl in [_newLoginCtrl, _newPassCtrl, _repeatPassCtrl]) {
      ctrl.removeListener(_onFieldChanged);
    }
    _currentPassCtrl.dispose();
    _newLoginCtrl.dispose();
    _newPassCtrl.dispose();
    _repeatPassCtrl.dispose();
    super.dispose();
  }

  String get _cleanNewLogin => AuthService.sanitizeLogin(_newLoginCtrl.text);

  bool get _loginChanged =>
      _cleanNewLogin.isNotEmpty && _cleanNewLogin != widget.currentLogin;

  bool get _passwordChanged => _newPassCtrl.text.isNotEmpty;

  bool get _hasChanges => _loginChanged || _passwordChanged;

  /// Saqlashdan oldingi tekshiruv. Xato matni qaytsa - saqlanmaydi.
  String? _validate() {
    if (_currentPassCtrl.text.isEmpty) {
      return 'Joriy parolni kiriting';
    }
    if (!_hasChanges) {
      return 'Hech narsa o\'zgartirilmadi';
    }
    if (_newLoginCtrl.text.trim().isNotEmpty && _cleanNewLogin.isEmpty) {
      return 'Login faqat lotin harflari va raqamlardan iborat bo\'lsin';
    }
    if (_passwordChanged) {
      if (_newPassCtrl.text.length < 6) {
        return 'Yangi parol kamida 6 ta belgidan iborat bo\'lsin';
      }
      if (_newPassCtrl.text != _repeatPassCtrl.text) {
        return 'Yangi parollar mos kelmadi';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (!await _confirm() || !mounted) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _authService.updateCredentials(
        currentPassword: _currentPassCtrl.text,
        newLogin: _loginChanged ? _cleanNewLogin : null,
        newPassword: _passwordChanged ? _newPassCtrl.text : null,
      );
      await _finish();
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Kutilmagan xatolik. Qayta urining.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// O'zgarishlarni aniq ko'rsatib tasdiqlatadi - "qaysi tugmani bosdim"
  /// degan chalkashlik bo'lmasligi uchun.
  Future<bool> _confirm() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O\'zgarishni tasdiqlang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loginChanged)
              _ConfirmRow(
                label: 'Login',
                value: '${widget.currentLogin}  →  $_cleanNewLogin',
              )
            else
              _ConfirmRow(
                label: 'Login',
                value: '${widget.currentLogin} (o\'zgarmaydi)',
                muted: true,
              ),
            const SizedBox(height: 8),
            _ConfirmRow(
              label: 'Parol',
              value:
                  _passwordChanged ? 'Yangi parolga almashadi' : 'O\'zgarmaydi',
              muted: !_passwordChanged,
            ),
            const SizedBox(height: 14),
            Text(
              'Saqlangach tizimdan chiqasiz va yangi ma\'lumotlar bilan '
              'qayta kirasiz.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Muvaffaqiyatdan keyin yangi loginni ko'rsatib, keyin login ekraniga
  /// o'tkazadi - foydalanuvchi yangi login nima ekanini albatta ko'radi.
  Future<void> _finish() async {
    final login = _loginChanged ? _cleanNewLogin : widget.currentLogin;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 40),
        title: const Text('Saqlandi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Endi tizimga shu ma\'lumotlar bilan kirasiz:'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Login:  $login',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    _passwordChanged
                        ? 'Parol:  yangi parol'
                        : 'Parol:  o\'zgarmadi',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tushunarli'),
          ),
        ],
      ),
    );

    await _authService.signOut();
    await SessionService().clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login va parol')),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 +
              MediaQuery.of(context).padding.bottom +
              MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Joriy login - foydalanuvchi nimani o'zgartirayotganini
            // aniq bilishi uchun har doim ko'rinib turadi.
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_circle_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Joriy login', style: theme.textTheme.bodySmall),
                        Text(
                          widget.currentLogin,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _currentPassCtrl,
              obscureText: _obscureCurrent,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: 'Joriy parol',
                helperText: 'Tasdiqlash uchun majburiy',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Nimani o\'zgartirmoqchi bo\'lsangiz, shu maydonni to\'ldiring. '
              'Bo\'sh qoldirilgani o\'zgarmaydi.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newLoginCtrl,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
              ],
              decoration: InputDecoration(
                labelText: 'Login',
                helperText: 'Faqat lotin harflari va raqamlar',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                suffixIcon: _loginChanged
                    ? const Icon(Icons.edit_rounded,
                        color: AppColors.warning, size: 18)
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newPassCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'Yangi parol',
                helperText: 'Bo\'sh qoldirsangiz parol o\'zgarmaydi',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            if (_passwordChanged) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _repeatPassCtrl,
                obscureText: _obscureNew,
                decoration: const InputDecoration(
                  labelText: 'Yangi parolni takrorlang',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving || !_hasChanges ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.label,
    required this.value,
    this.muted = false,
  });

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: muted ? FontWeight.w400 : FontWeight.w800,
              color: muted ? context.colorTextSecondary : null,
            ),
          ),
        ),
      ],
    );
  }
}
