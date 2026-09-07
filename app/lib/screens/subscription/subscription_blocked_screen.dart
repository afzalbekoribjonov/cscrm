import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../branding/app_branding.dart';
import '../../branding/logo.dart';
import '../../models/license_status.dart';
import '../../services/license_controller.dart';
import '../../services/license_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/logout_action.dart';
import 'payment_request_sheet.dart';

final _money = NumberFormat.decimalPattern('uz');

/// Sana formati raqamli — ilovaning qolgan qismidagidek. Oy nomini
/// yozadigan format `initializeDateFormatting('uz')` ni talab qiladi,
/// u esa loyihada chaqirilmaydi.
final _dateTime = DateFormat('dd.MM.yyyy, HH:mm');

/// Obuna muddati tugaganda ko'rsatiladigan ekran.
///
/// Bu ekran biznes egasiga ham, XODIMGA ham ko'rinadi. Xodim to'lovni o'zi
/// qilmasa ham, nima bo'layotganini bilishi va boshqaruvchiga aytishi
/// kerak — aks holda u "ilova buzildi" deb o'ylaydi.
class SubscriptionBlockedScreen extends StatefulWidget {
  const SubscriptionBlockedScreen({
    super.key,
    required this.status,
    required this.isOwner,
    this.service,
  });

  final LicenseStatus status;

  /// Ega uchun to'lov ko'rsatmalari, xodim uchun esa "boshqaruvchiga
  /// murojaat qiling" deb yoziladi.
  final bool isOwner;

  /// Testda almashtirish uchun. Odatda `null`.
  final LicenseService? service;

  @override
  State<SubscriptionBlockedScreen> createState() =>
      _SubscriptionBlockedScreenState();
}

class _SubscriptionBlockedScreenState extends State<SubscriptionBlockedScreen> {
  late final _service = widget.service ?? LicenseService();

  List<SubscriptionPlan> _plans = const [];
  PaymentRequest? _request;
  var _loadingPlans = true;

  /// Tanlangan reja — "xabar berish" formasi shu bilan ochiladi.
  /// Standart: eng ommabop reja.
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadRequest();
  }

  Future<void> _loadPlans() async {
    try {
      final result = await _service.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = result.plans.where((p) => !p.isTrial).toList();
        _selectedPlanId ??= _plans.isEmpty
            ? null
            : _plans
                .firstWhere((p) => p.highlight, orElse: () => _plans.first)
                .id;
        _loadingPlans = false;
      });
    } catch (_) {
      // Rejalar yuklanmasa ham ekran ishlaydi — aloqa ma'lumotlari
      // brendda bor va "Tekshirish" tugmasi baribir ochiq.
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  /// Oldin yuborilgan so'rov bormi. Xatolik jim yutiladi: so'rov holati
  /// qo'shimcha ma'lumot, usiz ham ekran to'liq ishlaydi.
  Future<void> _loadRequest() async {
    try {
      final request = await _service.fetchPaymentRequest();
      if (mounted) setState(() => _request = request);
    } catch (_) {
      /* e'tiborsiz */
    }
  }

  Future<void> _reportPayment() async {
    final sent = await showPaymentRequestSheet(
      context: context,
      plans: _plans,
      initialPlan: _plans.where((p) => p.id == _selectedPlanId).firstOrNull,
    );
    if (sent == null || !mounted) return;

    setState(() => _request = sent);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'So\'rovingiz yuborildi. Tasdiqlangach ilova o\'zi ochiladi.',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _recheck() async {
    await LicenseController.instance.refresh();
    await _loadRequest();
    if (!mounted) return;

    final status = LicenseController.instance.value?.status;
    final stillBlocked = status?.blocked ?? true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stillBlocked
              ? 'Hozircha to\'lov tasdiqlanmagan. Biroz kutib, qayta tekshiring.'
              : 'To\'lov tasdiqlandi. Ilovadan foydalanishingiz mumkin.',
        ),
        backgroundColor:
            stillBlocked ? AppColors.warning : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.status;

    return Scaffold(
      appBar: AppBar(
        title: const CscrmWordmark(markSize: 28),
        actions: const [LogoutAction()],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            _StatusCard(status: status),
            const SizedBox(height: 16),

            if (_request != null) ...[
              _RequestCard(request: _request!),
              const SizedBox(height: 16),
            ],

            if (!widget.isOwner) ...[
              _InfoCard(
                icon: Icons.info_outline_rounded,
                color: AppColors.info,
                title: 'Nima qilish kerak',
                body: _request?.isPending ?? false
                    ? 'Rahbaringiz to\'lov haqida xabar bergan. Tasdiqlangach '
                        'ilova o\'zi ochiladi — pastdagi tugma bilan '
                        'tekshirib turishingiz mumkin.'
                    : 'To\'lovni biznes rahbari amalga oshiradi. Unga xabar '
                        'bering — to\'lov tasdiqlangach ilova o\'zi ochiladi.',
              ),
              const SizedBox(height: 16),
            ],

            if (widget.isOwner) ...[
              if (_loadingPlans)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_plans.isNotEmpty) ...[
                  Text(
                    'Rejani tanlang',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'To\'lov rekvizitlarini Telegram yoki telefon orqali '
                    'beramiz.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  ..._plans.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlanCard(
                          plan: p,
                          selected: _selectedPlanId == p.id,
                          onTap: () => setState(() => _selectedPlanId = p.id),
                        ),
                      )),
                  const SizedBox(height: 4),
                ],

                // So'rov ko'rib chiqilayotgan paytda tugma yashiriladi —
                // server baribir ikkinchisini qabul qilmaydi va takroriy
                // urinish faqat chalkashlik keltiradi.
                if (_plans.isNotEmpty && !(_request?.isPending ?? false)) ...[
                  FilledButton.icon(
                    onPressed: _reportPayment,
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('To\'lov haqida xabar berish'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],

            // "Tekshirish" tugmasi HAR IKKALASIGA ko'rinadi — xodim ham
            // to'lov o'tganini o'zi tekshira olsin.
            ListenableBuilder(
              listenable: LicenseController.instance,
              builder: (context, _) {
                final busy = LicenseController.instance.isRefreshing;
                return ElevatedButton.icon(
                  onPressed: busy ? null : _recheck,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(busy ? 'Tekshirilmoqda...' : 'Tekshirish'),
                );
              },
            ),

            const SizedBox(height: 24),

            // Aloqa — endi yagona yo'l: karta rekvizitlari ilovada
            // ko'rsatilmaydi, ularni Telegram yoki telefon orqali
            // beramiz. Shu sabab bu blok ko'zga tashlanadigan bo'lishi
            // kerak, oddiy ro'yxat emas.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colorSurfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biz bilan bog\'laning',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'To\'lov rekvizitlari va savollar bo\'yicha.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ContactButton(
                          icon: Icons.send_rounded,
                          label: 'Telegram',
                          color: AppColors.info,
                          onTap: () => _open(AppBranding.supportTelegram),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ContactButton(
                          icon: Icons.phone_rounded,
                          label: 'Qo\'ng\'iroq',
                          color: AppColors.success,
                          onTap: () => _open(
                            'tel:${AppBranding.supportPhone.replaceAll(' ', '')}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: SelectableText(
                      AppBranding.supportPhone,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nima uchun bloklangani.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final LicenseStatus status;

  (IconData, Color, String) get _visual {
    switch (status.state) {
      case LicenseState.suspended:
        return (
          Icons.block_rounded,
          AppColors.danger,
          'Hisob to\'xtatilgan',
        );
      case LicenseState.lifetimeFeeDue:
        return (
          Icons.storage_rounded,
          AppColors.licenseLifetime,
          'Yillik baza to\'lovi',
        );
      default:
        return (
          Icons.lock_clock_rounded,
          AppColors.danger,
          'Obuna muddati tugadi',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color, title) = _visual;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              status.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Yuborilgan to'lov so'rovining holati.
///
/// Bu karta EGAGA ham, XODIMGA ham ko'rinadi: ikkalasi ham "xabar
/// berilganmi yoki yo'qmi" degan savolga javob olishi kerak.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final PaymentRequest request;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rejected = request.isRejected;
    final pending = request.isPending;

    final (icon, color, title) = rejected
        ? (
            Icons.error_outline_rounded,
            AppColors.danger,
            'So\'rov rad etildi',
          )
        : pending
            ? (
                Icons.hourglass_top_rounded,
                AppColors.warning,
                'Tasdiqlanishi kutilmoqda',
              )
            : (
                Icons.check_circle_outline_rounded,
                AppColors.success,
                'So\'rov tasdiqlangan',
              );

    final when = DateTime.fromMillisecondsSinceEpoch(request.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '${request.planName} · ${_money.format(request.amount)} so\'m'
                  ' · ${_dateTime.format(when)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (rejected && (request.rejectReason?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Sabab: ${request.rejectReason}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.danger),
                  ),
                ],
                if (pending) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Odatda bir necha soat ichida tekshiriladi.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tanlanadigan reja kartasi.
///
/// Bosilganda tanlanadi va "xabar berish" formasi shu reja bilan
/// ochiladi — foydalanuvchi formada rejani QAYTA tanlashi shart emas.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool selected;
  final VoidCallback onTap;

  /// Oyiga tushadigan narx — rejalarni taqqoslash uchun eng foydali
  /// raqam. Bir oylikda ko'rsatilmaydi: u narxning o'zi.
  String? get _perMonth {
    final months = plan.months;
    if (months == null || months <= 1 || plan.priceUnset) return null;
    return '${_money.format((plan.price / months).round())} so\'m/oy';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selected ? AppColors.primary : context.colorBorder;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : context.colorSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent, width: selected ? 1.8 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tanlov belgisi — qaysi reja tanlanganini bir qarashda
              // ko'rsatadi.
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 21,
                  color: selected
                      ? AppColors.primary
                      : context.colorTextSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.name,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (plan.highlight) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Ommabop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      plan.description,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_perMonth != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _perMonth!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (plan.lifetimeAnnualFeeUsd != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.storage_rounded,
                                size: 13,
                                color: AppColors.licenseLifetime),
                          ),
                          const SizedBox(width: 5),
                          // `Expanded` shart: uzun matn tor telefonda
                          // qatordan chiqib ketardi.
                          Expanded(
                            child: Text(
                              'Yiliga \$${plan.lifetimeAnnualFeeUsd} — '
                              'baza uchun',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.licenseLifetime,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // O'ng ustunda FAQAT narx. Oylik narx chapga ko'chirildi:
              // "149 167 so'm/oy" o'ng ustunni shunchalik kengaytirardiki,
              // tor telefonda reja nomiga joy qolmasdi.
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan.priceUnset
                        ? 'Kelishiladi'
                        : _money.format(plan.price),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: plan.priceUnset
                          ? context.colorTextSecondary
                          : (selected ? AppColors.primary : null),
                    ),
                  ),
                  if (!plan.priceUnset)
                    Text('so\'m', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aloqa tugmasi — Telegram yoki qo'ng'iroq.
class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorSurface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

