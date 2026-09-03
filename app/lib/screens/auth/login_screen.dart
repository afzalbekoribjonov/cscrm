import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../branding/app_branding.dart';
import '../../branding/logo.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/phone.dart';
import '../../widgets/license_gate.dart';
import '../../widgets/pin_pad.dart';
import '../home/home_shell.dart';
import 'register_business_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0; // 0 = xodim, 1 = boshqaruvchi

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  const CscrmMark(size: 64),
                  const SizedBox(height: 14),
                  Text(AppBranding.name, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    AppBranding.shortDescription,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  _RoleToggle(
                    value: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _tab == 0
                        ? const _EmployeeLoginForm(key: ValueKey('emp'))
                        : const _OwnerLoginForm(key: ValueKey('owner')),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Hali hisobingiz yo\'qmi?',
                    style: theme.textTheme.bodySmall,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegisterBusinessScreen(),
                      ),
                    ),
                    child: const Text('Biznesni ro\'yxatdan o\'tkazish'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colorSurfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segment(context, 'Xodim', 0),
          _segment(context, 'Boshqaruvchi', 1),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, int index) {
    final selected = value == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? context.colorSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: selected ? AppColors.primary : context.colorTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kirish muvaffaqiyatli bo'lgach sessiyani saqlab, asosiy ekranga o'tadi.
Future<void> _completeSignIn(
  BuildContext context,
  SignInResult result,
) async {
  final session = result.isOwner
      ? Session.owner(
          tenantId: result.tenantId,
          tenantName: result.tenantName,
          userId: result.userId,
          displayName: result.displayName,
        )
      : Session.employee(
          tenantId: result.tenantId,
          tenantName: result.tenantName,
          userId: result.userId,
          employeeId: result.employeeId ?? '',
          displayName: result.displayName,
          access: result.access,
        );

  await SessionService().save(session);
  if (!context.mounted) return;

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => LicenseGate(
        tenantId: result.tenantId,
        isOwner: result.isOwner,
        child: HomeShell(session: session),
      ),
    ),
    (route) => false,
  );
}

// ---------------------------------------------------------------------------
// Xodim
// ---------------------------------------------------------------------------

class _EmployeeLoginForm extends StatefulWidget {
  const _EmployeeLoginForm({super.key});

  @override
  State<_EmployeeLoginForm> createState() => _EmployeeLoginFormState();
}

class _EmployeeLoginFormState extends State<_EmployeeLoginForm> {
  final _phoneCtrl = TextEditingController();
  final _pinPadKey = GlobalKey<PinPadState>();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// PIN endi SERVERDA tekshiriladi — qurilmaga hech qanday hash
  /// yuborilmaydi (qarang: [AuthService.employeeSignIn]).
  Future<void> _onPinCompleted(String pin) async {
    final phone = _phoneCtrl.text.trim();
    if (!isCompletePhone(phone)) {
      setState(() => _error = 'Avval telefon raqamini to\'liq kiriting');
      _pinPadKey.currentState?.clear();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _attempt(phone, pin);
    } on TenantChoiceRequired catch (e) {
      // Bir raqam bir nechta biznesga bog'langan — qaysi biri ekanini
      // so'raymiz.
      if (!mounted) return;
      final chosen = await showDialog<TenantChoice>(
        context: context,
        builder: (_) => _TenantPickerDialog(choices: e.choices),
      );
      if (chosen == null) {
        _pinPadKey.currentState?.clear();
      } else {
        try {
          await _attempt(phone, pin, tenantId: chosen.tenantId);
        } on AuthFailure catch (e) {
          _fail(e.message);
        }
      }
    } on AuthFailure catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Kutilmagan xatolik. Qayta urining.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _attempt(String phone, String pin, {String? tenantId}) async {
    final result = await _authService.employeeSignIn(
      phone: phone,
      pin: pin,
      tenantId: tenantId,
    );
    if (!mounted) return;
    await _completeSignIn(context, result);
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    _pinPadKey.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))
          ],
          decoration: const InputDecoration(
            labelText: 'Telefon raqami',
            hintText: '+998 90 123 45 67',
          ),
        ),
        const SizedBox(height: 22),
        Text('PIN-kodni kiriting', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        IgnorePointer(
          ignoring: _loading,
          child: Opacity(
            opacity: _loading ? 0.5 : 1,
            child: PinPad(key: _pinPadKey, onCompleted: _onPinCompleted),
          ),
        ),
        if (_loading) ...[
          const SizedBox(height: 16),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _TenantPickerDialog extends StatelessWidget {
  const _TenantPickerDialog({required this.choices});

  final List<TenantChoice> choices;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Qaysi biznes?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final choice in choices)
            ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: Text(choice.name),
              onTap: () => Navigator.of(context).pop(choice),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Boshqaruvchi (biznes egasi)
// ---------------------------------------------------------------------------

class _OwnerLoginForm extends StatefulWidget {
  const _OwnerLoginForm({super.key});

  @override
  State<_OwnerLoginForm> createState() => _OwnerLoginFormState();
}

class _OwnerLoginFormState extends State<_OwnerLoginForm> {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final login = _loginCtrl.text.trim();
    final pass = _passCtrl.text;
    if (login.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Login va parolni kiriting');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await _authService.ownerSignIn(login: login, password: pass);
      if (!mounted) return;
      await _completeSignIn(context, result);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Kutilmagan xatolik. Qayta urining.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _loginCtrl,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Login'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Parol',
            suffixIcon: IconButton(
              icon: Icon(_obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Text('Kirish'),
        ),
      ],
    );
  }
}
