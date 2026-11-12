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
                _Plans(
                  plans: _plans,
                  currentPlanId: status?.planId,
                  onPick: _openPayment,
                ),
              if (_payment != null &&
                  (_payment!.phone.isNotEmpty || _payment!.telegram.isNotEmpty)) ...[
                const SizedBox(height: 24),
                _Support(payment: _payment!),
              ],
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

class _Plans extends StatelessWidget {
  const _Plans({
    required this.plans,
    required this.currentPlanId,
    required this.onPick,
  });

  final List<SubscriptionPlan> plans;
  final String? currentPlanId;
  final ValueChanged<SubscriptionPlan> onPick;

  @override
  Widget build(BuildContext context) {
    // Tejash 1 oylik tarifga nisbatan hisoblanadi.
    final baseline = plans
        .where((p) => p.months == 1 && !p.priceUnset)
        .map((p) => p.price)
        .firstOrNull;
    return Column(
      children: [
        for (final plan in plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PlanRow(
              plan: plan,
              current: plan.id == currentPlanId,
              baseline: baseline,
              onTap: () => onPick(plan),
            ),
          ),
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
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
    return AppCard(
      onTap: onTap,
      borderColor: current ? AppColors.primary : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(plan.name, style: theme.textTheme.titleSmall),
                    if (current)
                      const TonePill(label: 'Joriy', tone: StageTone.brand, dense: true)
                    else if (saving != null)
                      TonePill(
                          label: '$saving% tejash',
                          tone: StageTone.success,
                          dense: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  per == null ? plan.description : '${formatMoney(per)} so\'m/oy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.priceUnset ? 'Kelishiladi' : formatMoney(plan.price.round()),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFeatures: AppFonts.tabular,
                ),
              ),
              if (!plan.priceUnset) Text('so\'m', style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: context.colorTextTertiary),
        ],
      ),
    );
  }
}

class _Support extends StatelessWidget {
  const _Support({required this.payment});

  final PaymentInfo payment;

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
    final phone = digitsOnly(payment.phone);
    final tg = payment.telegram.replaceAll('@', '').trim();
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
              if (phone.isNotEmpty)
                ListTile(
                  leading: const IconTile(icon: Icons.call_outlined, tone: StageTone.success),
                  title: const Text('Qo\'ng\'iroq qilish'),
                  subtitle: Text(formatPhoneForDisplay(payment.phone)),
                  onTap: () => _open(context, Uri(scheme: 'tel', path: '+$phone')),
                ),
              if (phone.isNotEmpty && tg.isNotEmpty)
                Divider(height: 1, indent: 72, color: context.colorBorder),
              if (tg.isNotEmpty)
                ListTile(
                  leading: const IconTile(icon: Icons.send_rounded, tone: StageTone.info),
                  title: const Text('Telegram'),
                  subtitle: Text.verbatim('@$tg'),
                  onTap: () => _open(context, Uri.parse('https://t.me/$tg')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
