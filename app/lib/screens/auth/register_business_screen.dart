import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../branding/logo.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/phone.dart';
import '../../widgets/license_gate.dart';
import '../home/home_shell.dart';

/// Yangi biznesni ro'yxatdan o'tkazish — har bir savol alohida ekranda.
///
/// NEGA BITTA UZUN FORMA EMAS: beshta maydon bir ekranda turganda odam
/// avval hammasini ko'zdan kechiradi, keyin qaysinisidan boshlashni
/// o'ylaydi va klaviatura ochilganda yarmi bekitilib qoladi. Bitta
/// savol — bitta javob tartibida esa o'ylashga hojat qolmaydi.
///
/// Hisob ilovada emas, SERVERDA yaratiladi: biznes tuguni, sinov
/// litsenziyasi va token da'volari birgalikda qo'yilishi kerak, buni esa
/// faqat Admin SDK qila oladi.
class RegisterBusinessScreen extends StatefulWidget {
  const RegisterBusinessScreen({super.key, this.service});

  /// Sinovda almashtirish uchun. Odatda `null`.
  final BusinessRegistrar? service;

  @override
  State<RegisterBusinessScreen> createState() => _RegisterBusinessScreenState();
}

/// Qadamlar tartibi. Qiymatlar indeks sifatida ishlatiladi, shuning
/// uchun tartibi muhim.
enum _Step { business, phone, login, password }

class _RegisterBusinessScreenState extends State<RegisterBusinessScreen> {
  final _pages = PageController();

  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();

  late final _authService = widget.service ?? AuthService();

  var _step = _Step.business;
  var _obscure = true;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Tugmaning yoniq-o'chiqligi kiritilgan matnga bog'liq — har bir
    // harfda qayta chiziladi.
    for (final c in [_business, _phone, _login, _password]) {
      c.addListener(_onTyping);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final c in [_business, _phone, _login, _password]) {
      c
        ..removeListener(_onTyping)
        ..dispose();
    }
    super.dispose();
  }

  void _onTyping() {
    // Xatolik yozuvi yangi harf kiritilishi bilan yo'qoladi — u
    // ekranda qolib, tuzatilgan maydon ustida turishi noto'g'ri.
    if (_error != null) {
      setState(() => _error = null);
    } else {
      setState(() {});
    }
  }

  // -------------------------------------------------------------------
  // Qadamlar bo'yicha tekshiruv
  // -------------------------------------------------------------------

  /// Joriy qadamdagi javob keyingisiga o'tish uchun yetarlimi.
  bool get _canContinue => switch (_step) {
        _Step.business => _business.text.trim().length >= 2,
        _Step.phone => isCompletePhone(_phone.text),
        _Step.login => AuthService.sanitizeLogin(_login.text).length >= 3,
        _Step.password => _password.text.length >= 6,
      };

  void _next() {
    if (!_canContinue || _loading) return;

    if (_step == _Step.password) {
      _submit();
      return;
    }

    _goTo(_Step.values[_step.index + 1]);
  }

  void _back() {
    if (_step == _Step.business) {
      Navigator.of(context).maybePop();
      return;
    }
    _goTo(_Step.values[_step.index - 1]);
  }

  void _goTo(_Step step) {
    setState(() {
      _step = step;
      _error = null;
    });
    _pages.animateToPage(
      step.index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  // -------------------------------------------------------------------
  // Yuborish
  // -------------------------------------------------------------------

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _authService.registerBusiness(
        businessName: _business.text,
        login: _login.text,
        password: _password.text,
        phone: normalizePhone(_phone.text),
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
      if (!mounted) return;
      setState(() => _loading = false);

      // Band login — foydalanuvchini aynan o'sha qadamga qaytaramiz.
      // Xatolikni oxirgi ekranda ko'rsatish "nimani tuzatay?" degan
      // savolni qoldirardi: tuzatiladigan maydon boshqa ekranda.
      if (e.code == 'login_taken') {
        _goTo(_Step.login);
        setState(() => _error = e.message);
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Ulanib bo\'lmadi. Internetni tekshirib, qayta urining.';
        });
      }
    }
  }

  // -------------------------------------------------------------------
  // Ko'rinish
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _loading ? null : _back,
        ),
        title: const CscrmWordmark(height: 26),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Progress(current: _step.index, total: _Step.values.length),
            Expanded(
              child: PageView(
                controller: _pages,
                // Surib o'tish O'CHIRILGAN: tasodifan surib yuborish
                // to'ldirilmagan qadamni o'tkazib yuborardi. O'tish
                // faqat tugma orqali — tekshiruvdan keyin.
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepPage(
                    title: 'Biznesingiz nomi',
                    field: _Field(
                      controller: _business,
                      hint: 'Nihol gilam yuvish',
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: _next,
                    ),
                  ),
                  _StepPage(
                    title: 'Telefon raqamingiz',
                    field: _Field(
                      controller: _phone,
                      hint: '+998 90 123 45 67',
                      keyboardType: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      ],
                      onSubmitted: _next,
                    ),
                  ),
                  _StepPage(
                    title: 'Login o\'ylab toping',
                    hint: 'Tizimga shu bilan kirasiz',
                    field: _Field(
                      controller: _login,
                      hint: 'nihol',
                      autocorrect: false,
                      onSubmitted: _next,
                    ),
                  ),
                  _StepPage(
                    title: 'Parol yarating',
                    hint: 'Kamida 6 ta belgi',
                    field: _Field(
                      controller: _password,
                      hint: '••••••',
                      obscure: _obscure,
                      onSubmitted: _next,
                      suffix: IconButton(
                        tooltip: _obscure ? 'Ko\'rsatish' : 'Yashirish',
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) _ErrorNote(_error!),
            _Action(
              label: _step == _Step.password ? 'Tayyor' : 'Davom etish',
              enabled: _canContinue && !_loading,
              loading: _loading,
              onTap: _next,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Bo'laklar
// ---------------------------------------------------------------------

/// Qadam ko'rsatkichi — nechta savol qolganini bildiradi.
class _Progress extends StatelessWidget {
  const _Progress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Row(
        children: List.generate(total, (i) {
          final done = i <= current;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              height: 4,
              margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: done
                    ? AppColors.brand
                    : Theme.of(context).dividerColor.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Bitta savol: sarlavha, ixtiyoriy bir qatorli izoh va maydon.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.title, required this.field, this.hint});

  final String title;
  final String? hint;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Savol ekranning YUQORI UCHDAN BIRIDA turadi.
    //
    // Tepaga yopishtirilsa, ostida katta bo'sh maydon qolib, ekran
    // tugallanmagandek ko'rinadi; markazga qo'yilsa klaviatura
    // ochilganda sakrab ketadi. Shu oraliq ikkalasidan ham qulay.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 28),
          field,
        ],
      ),
    );
  }
}

/// Katta, bitta maydon.
///
/// `autofocus` ATAYLAB yoqilgan: ekranda bitta maydon bor, ya'ni
/// foydalanuvchi baribir o'shanga bosadi — klaviaturani o'zi ochib
/// berish bitta ortiqcha harakatni olib tashlaydi.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    this.keyboardType,
    this.formatters,
    this.obscure = false,
    this.autocorrect = true,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmitted;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final bool obscure;
  final bool autocorrect;
  final TextCapitalization textCapitalization;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      obscureText: obscure,
      autocorrect: autocorrect,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textCapitalization: textCapitalization,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmitted(),
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).hintColor.withValues(alpha: 0.5),
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pastdagi asosiy tugma.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Klaviatura ochilganda tugma uning ustida qoladi: `Scaffold`
      // odatiy holda ekranni klaviatura balandligiga qisqartiradi,
      // ya'ni bu ustun ham yuqoriga siljiydi.
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
