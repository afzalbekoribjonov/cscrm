import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/text.dart';
import '../../models/app_user.dart';
import '../../models/license_status.dart';
import '../../services/license_controller.dart';
import '../../services/license_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/sheets.dart';
import '../../ui/surfaces.dart';
import '../../utils/money.dart';
import '../../utils/phone.dart';
import '../../utils/subscription_view.dart';
import '../../utils/uz_dates.dart';
import '../subscription/payment_request_sheet.dart';

/// "Profilim" — biznes va obuna.
///
/// Obuna muddati KUNda yaxlitlanmaydi: tugashiga 1 soat qolganda "1 kun"
/// emas, "1 soat" deb chiqadi va sahifa ochiq turganda o'zi yangilanadi.
/// Qo'shimcha ma'lumot (tariflar, to'lov so'rovi, bog'lanish) serverdan
/// — Firebase'dan emas — bir marta olinadi.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.businessName,
    this.service,
    this.now,
  });

  final String businessName;

  /// Sinovda serverga chiqmaydigan soxta xizmat beriladi.
  final LicenseService? service;

  /// Sinovda — qat'iy "hozir".
  final DateTime Function()? now;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _service = widget.service ?? LicenseService();
  Timer? _tick;

  List<SubscriptionPlan> _plans = const [];
  PaymentInfo? _payment;
  PaymentRequest? _request;
  var _loadingPlans = true;

  int get _now =>
      (widget.now?.call() ?? DateTime.now()).millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadRequest();
    // Qolgan vaqt sahifa ochiq turganda ham to'g'ri bo'lsin.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final result = await _service.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = result.plans.where((p) => !p.isTrial).toList();
        _payment = result.payment;
        _loadingPlans = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  Future<void> _loadRequest() async {
    try {
      final r = await _service.fetchPaymentRequest();
      if (mounted) setState(() => _request = r);
    } catch (_) {
      // So'rov holati ko'rinmasa ham sahifa ishlayveradi.
    }
  }

  Future<void> _openPayment(SubscriptionPlan plan) async {
    final sent = await showPaymentRequestSheet(
      context: context,
      plans: _plans,
      initialPlan: plan,
    );
    if (sent == null || !mounted) return;
    setState(() => _request = sent);
    showResult(context, 'So\'rovingiz yuborildi. Tasdiqlangach obuna uzayadi.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: ValueListenableBuilder<LicenseResolution?>(
        valueListenable: LicenseController.instance,
        builder: (context, resolution, _) {
          final status = resolution?.status;
          final plan = _plans.where((p) => p.id == status?.planId).firstOrNull;
          return ListView(
            padding: EdgeInsets.fromLTRB(Gap.page, 4, Gap.page,
                32 + MediaQuery.of(context).padding.bottom),
            children: [
              _Hero(
                name: widget.businessName,
                status: status,
                view: subscriptionView(status, deviceNow: _now),
              ),
              if (_request != null && (_request!.isPending || _request!.isRejected)) ...[
                const SizedBox(height: 12),
                _RequestCard(request: _request!),
              ],
              if (status != null) ...[
                const SizedBox(height: 20),
                _PlanCard(status: status, plan: plan, now: _now),
              ],
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Tariflar',
                subtitle: 'Obunani uzaytirish yoki tarifni almashtirish',
              ),
              if (_loadingPlans)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_plans.isEmpty)
                const AppCard(
                  child: Text('Tariflar ro\'yxatini olib bo\'lmadi. Internetni '
                      'tekshirib, sahifani qayta oching.'),
                )
              else
                _PlansCarousel(
                  plans: _plans,
                  currentPlanId: status?.planId,
                  onPick: _openPayment,
                ),
              const SizedBox(height: 24),
              _Support(phone: _payment?.phone ?? ''),
            ],
          );
        },
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.status, required this.view});

  final String name;
  final LicenseStatus? status;
  final SubscriptionView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.xl),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    initialsOf(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Biznes' : name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: view.tone.inkDark,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              view.label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (view.remaining != null) ...[
              const SizedBox(height: 20),
              Text(
                view.ended ? 'Obuna' : 'Obuna tugashiga',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                view.remaining!,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
              if (view.expiresAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${UzDates.date(view.expiresAt!)}, ${UzDates.time(view.expiresAt!)} gacha',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.status, required this.plan, required this.now});

  final LicenseStatus status;
  final SubscriptionPlan? plan;
  final int now;

  String get _kind => switch (status.kind) {
        'trial' => 'Sinov muddati',
        'lifetime' => 'Bir umrlik',
        _ => 'Obuna',
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expires = status.expiresAt;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.workspace_premium_outlined, tone: StageTone.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Joriy tarif', style: theme.textTheme.bodySmall),
                    Text(plan?.name ?? _kind, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: context.colorBorder),
          const SizedBox(height: 4),
          InfoRow(label: 'Turi', value: _kind),
          if (plan != null && !plan!.priceUnset)
            InfoRow(label: 'Narxi', value: formatSom(plan!.price)),
          if (expires != null)
            InfoRow(
              label: 'Amal qiladi',
              value: UzDates.date(DateTime.fromMillisecondsSinceEpoch(expires)),
            ),
          if (status.isLifetime && expires == null)
            const InfoRow(label: 'Muddat', value: 'Cheklanmagan'),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final PaymentRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = request.isPending;
    final tone = pending ? StageTone.info : StageTone.danger;
    return AppCard(
      color: tone.soft(context),
      borderColor: Colors.transparent,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(pending ? Icons.hourglass_top_rounded : Icons.error_outline_rounded,
              color: tone.ink(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending ? 'To\'lov tekshirilmoqda' : 'To\'lov tasdiqlanmadi',
                  style: theme.textTheme.titleSmall?.copyWith(color: tone.ink(context)),
                ),
                const SizedBox(height: 2),
                Text(
                  pending
                      ? '${request.planName} · ${formatSom(request.amount)}. '
                          'Tasdiqlangach obuna avtomatik uzayadi.'
                      : (request.rejectReason?.isNotEmpty ?? false)
                          ? 'Sabab: ${request.rejectReason}'
                          : 'Qayta so\'rov yuborishingiz mumkin.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tariflar — yon tomonga suriladigan kartalar (karusel).
///
/// Har bir tarif alohida katta kartada: narxi, oyiga qanchaga tushishi,
/// tejash foizi va "Tanlash" tugmasi. Joriy (yoki tavsiya etilgan) tarif
/// birinchi ko'rinadi; pastdagi nuqtalar nechta tarif borligini ko'rsatadi.
class _PlansCarousel extends StatefulWidget {
  const _PlansCarousel({
    required this.plans,
    required this.currentPlanId,
    required this.onPick,
  });

  final List<SubscriptionPlan> plans;
  final String? currentPlanId;
  final ValueChanged<SubscriptionPlan> onPick;

  @override
  State<_PlansCarousel> createState() => _PlansCarouselState();
}

class _PlansCarouselState extends State<_PlansCarousel> {
  late int _page = _initialPage();
  late final _controller =
      PageController(viewportFraction: 0.84, initialPage: _page);

  int _initialPage() {
    final plans = widget.plans;
    var i = plans.indexWhere((p) => p.id == widget.currentPlanId);
    if (i < 0) i = plans.indexWhere((p) => p.highlight);
    return i < 0 ? 0 : i;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plans = widget.plans;
    // Tejash 1 oylik tarifga nisbatan hisoblanadi.
    final baseline = plans
        .where((p) => p.months == 1 && !p.priceUnset)
        .map((p) => p.price)
        .firstOrNull;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      children: [
        SizedBox(
          // Katta shriftda ham karta ichi sig'sin.
          height: 226 * scale.clamp(1.0, 1.3),
          child: PageView.builder(
            controller: _controller,
            padEnds: plans.length > 1,
            itemCount: plans.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _PlanCard2(
                plan: plans[i],
                current: plans[i].id == widget.currentPlanId,
                baseline: baseline,
                onTap: () => widget.onPick(plans[i]),
              ),
            ),
          ),
        ),
        if (plans.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < plans.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.primary
                        : context.colorBorderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PlanCard2 extends StatelessWidget {
  const _PlanCard2({
    required this.plan,
    required this.current,
    required this.baseline,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool current;
  final double? baseline;
  final VoidCallback onTap;

  int? get _perMonth {
    final months = plan.months;
    if (months == null || months < 1 || plan.priceUnset) return null;
    return (plan.price / months).round();
  }

  int? get _saving {
    final per = _perMonth;
    final base = baseline;
    if (per == null || base == null || base <= 0) return null;
    final pct = ((1 - per / base) * 100).round();
    // 1–2 foiz "tejaysiz" deyishga arzimaydi — yaxlitlash xatosiga o'xshaydi.
    return pct >= 3 ? pct : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final per = _perMonth;
    final saving = _saving;
    final featured = plan.highlight && !current;
    final dark = featured;
    final fg = dark ? Colors.white : context.colorTextPrimary;
    final sub = dark ? Colors.white70 : context.colorTextSecondary;

    return Material(
      color: dark ? null : context.colorSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
        side: BorderSide(
          color: current
              ? AppColors.primary
              : dark
                  ? Colors.transparent
                  : context.colorBorder,
          width: current ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: dark
            ? const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(color: fg),
                      ),
                    ),
                    if (current)
                      const TonePill(label: 'Joriy', tone: StageTone.brand, dense: true)
                    else if (featured)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                        child: const Text(
                          'Tavsiya',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: plan.priceUnset
                            ? 'Kelishiladi'
                            : formatMoney(plan.price.round()),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: fg,
                          fontFeatures: AppFonts.tabular,
                        ),
                      ),
                      if (!plan.priceUnset)
                        TextSpan(
                          text: ' so\'m',
                          style: theme.textTheme.titleSmall?.copyWith(color: sub),
                        ),
                    ]),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  per == null
                      ? (plan.description.isEmpty ? ' ' : plan.description)
                      : 'Oyiga ${formatMoney(per)} so\'mdan',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: sub),
                ),
                const Spacer(),
                if (saving != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.savings_rounded,
                            size: 18,
                            color: dark ? Colors.white : StageTone.success.ink(context)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$saving% tejaysiz',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: dark ? Colors.white : StageTone.success.ink(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: dark ? Colors.white : null,
                      foregroundColor: dark ? AppColors.primaryDark : null,
                    ),
                    onPressed: onTap,
                    child: Text(current ? 'Uzaytirish' : 'Tanlash'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Yordam": qo'ng'iroq (CSCRM telefoni, sozlangan bo'lsa) va rasmiy
/// Telegram kanali — https://t.me/cscrm_uz (foydalanuvchi so'rovi,
/// 2026-11-20: havola sozlamaga emas, doim shu kanalga olib boradi).
class _Support extends StatelessWidget {
  const _Support({required this.phone});

  final String phone;

  static const telegramHandle = 'cscrm_uz';
  static final telegramUrl = Uri.parse('https://t.me/cscrm_uz');

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showResult(context, 'Ilovani ochib bo\'lmadi', error: true);
      }
    } catch (_) {
      if (context.mounted) showResult(context, 'Ilovani ochib bo\'lmadi', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = digitsOnly(phone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Yordam',
          subtitle: 'Savol yoki to\'lov bo\'yicha CSCRM bilan bog\'lanish',
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const IconTile(icon: Icons.send_rounded, tone: StageTone.info),
                title: const Text('Telegram'),
                subtitle: const Text.verbatim('@$telegramHandle'),
                trailing: Icon(Icons.open_in_new_rounded,
                    size: 18, color: context.colorTextTertiary),
                onTap: () => _open(context, telegramUrl),
              ),
              if (digits.isNotEmpty) ...[
                Divider(height: 1, indent: 72, color: context.colorBorder),
                ListTile(
                  leading: const IconTile(icon: Icons.call_outlined, tone: StageTone.success),
                  title: const Text('Qo\'ng\'iroq qilish'),
                  subtitle: Text(formatPhoneForDisplay(phone)),
                  onTap: () => _open(context, Uri(scheme: 'tel', path: '+$digits')),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
