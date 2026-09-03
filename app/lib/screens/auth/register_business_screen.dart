import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../branding/logo.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/license_gate.dart';
import '../home/home_shell.dart';

/// Yangi biznesni ro'yxatdan o'tkazish.
///
/// Hisob ilovada emas, SERVERDA yaratiladi: biznes tuguni, sinov
/// litsenziyasi va token da'volari birgalikda qo'yilishi kerak, buni esa
/// faqat Admin SDK qila oladi.
class RegisterBusinessScreen extends StatefulWidget {
  const RegisterBusinessScreen({super.key});

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();

  final _authService = AuthService();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _businessCtrl.dispose();
    _phoneCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _authService.registerBusiness(
        businessName: _businessCtrl.text,
        login: _loginCtrl.text,
        password: _passCtrl.text,
        phone: _phoneCtrl.text,
      );

      final session = Session.owner(
        tenantId: result.tenantId,
        tenantName: result.tenantName,
        userId: result.userId,
        displayName: result.displayName,
      );
      await SessionService().save(session);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LicenseGate(
            tenantId: result.tenantId,
            isOwner: true,
            child: HomeShell(session: session),
          ),
        ),
        (route) => false,
      );
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Kutilmagan xatolik. Qayta urinib ko\'ring.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Biznesni ro\'yxatdan o\'tkazish')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: CscrmMark(size: 56)),
                    const SizedBox(height: 18),
                    Text(
                      'Bepul sinov muddati',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ro\'yxatdan o\'tgach barcha imkoniyatlar ochiladi. '
                      'Karta ma\'lumoti so\'ralmaydi.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 26),

                    TextFormField(
                      controller: _businessCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Biznes nomi',
                        hintText: 'masalan: Nihol gilam yuvish',
                      ),
                      validator: (v) => (v ?? '').trim().length < 2
                          ? 'Biznes nomini kiriting'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Telefon raqami (ixtiyoriy)',
                        hintText: '+998 90 123 45 67',
                      ),
                    ),
                    const SizedBox(height: 26),

                    Text('Boshqaruvchi hisobi',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _loginCtrl,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Login',
                        helperText: 'Kichik lotin harflari, raqam, . _ -',
                      ),
                      validator: (v) {
                        final clean = AuthService.sanitizeLogin(v ?? '');
                        if (clean.length < 3) {
                          return 'Login kamida 3 ta belgidan iborat bo\'lsin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Parol',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v ?? '').length < 6
                          ? 'Parol kamida 6 ta belgidan iborat bo\'lsin'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passConfirmCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration:
                          const InputDecoration(labelText: 'Parolni takrorlang'),
                      validator: (v) => v != _passCtrl.text
                          ? 'Parollar mos kelmadi'
                          : null,
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
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
                          : const Text('Ro\'yxatdan o\'tish'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
