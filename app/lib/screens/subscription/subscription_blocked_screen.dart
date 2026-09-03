import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  PaymentInfo? _payment;
  PaymentRequest? _request;
  var _loadingPlans = true;

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
        _payment = result.payment;
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

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label nusxalandi'),
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
                  Text('Rejalar', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._plans.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PlanTile(plan: p),
                      )),
                  const SizedBox(height: 16),
                ],
                _PaymentCard(
                  payment: _payment,
                  onCopy: _copy,
                  onOpen: _open,
                ),
                const SizedBox(height: 12),

                // So'rov ko'rib chiqilayotgan paytda tugma yashiriladi —
                // server baribir ikkinchisini qabul qilmaydi va takroriy
                // urinish faqat chalkashlik keltiradi.
                if (_plans.isNotEmpty && !(_request?.isPending ?? false)) ...[
                  FilledButton.tonalIcon(
                    onPressed: _reportPayment,
                    icon: const Icon(Icons.receipt_long_rounded),
                    label: const Text('To\'lov haqida xabar berish'),
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

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text('Yordam', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _ContactRow(
              icon: Icons.phone_rounded,
              label: AppBranding.supportPhone,
              onTap: () =>
                  _open('tel:${AppBranding.supportPhone.replaceAll(' ', '')}'),
            ),
            _ContactRow(
              icon: Icons.send_rounded,
              label: 'Telegram',
              onTap: () => _open(AppBranding.supportTelegram),
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

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan});

  final SubscriptionPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: plan.highlight ? AppColors.primary : context.colorBorder,
          width: plan.highlight ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(plan.name, style: theme.textTheme.titleSmall),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(plan.description, style: theme.textTheme.bodySmall),
                if (plan.lifetimeAnnualFeeUsd != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+ yiliga \$${plan.lifetimeAnnualFeeUsd} — baza uchun',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.licenseLifetime),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            plan.priceUnset
                ? 'Kelishiladi'
                : '${_money.format(plan.price)} so\'m',
            style: theme.textTheme.titleSmall?.copyWith(
              color: plan.priceUnset
                  ? context.colorTextSecondary
                  : context.colorTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.onCopy,
    required this.onOpen,
  });

  final PaymentInfo? payment;
  final void Function(String value, String label) onCopy;
  final void Function(String url) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = payment;

    // To'lov ma'lumotlari serverda sozlanmagan bo'lsa soxta karta
    // ko'rsatmaymiz — aloqaga yo'naltiramiz.
    if (info == null || !info.configured) {
      return _InfoCard(
        icon: Icons.support_agent_rounded,
        color: AppColors.info,
        title: 'To\'lov uchun bog\'laning',
        body: 'To\'lov rekvizitlarini olish uchun yordam xizmatiga '
            'murojaat qiling.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Karta orqali to\'lov',
                    style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 14),

            // Bir nechta karta bo'lishi mumkin — mijoz o'z bankiga
            // mos kelganini tanlaydi (Humo / Uzcard).
            for (var i = 0; i < info.cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _CopyRow(
                label: info.cards[i].label,
                value: info.cards[i].number,
                onCopy: () =>
                    onCopy(info.cards[i].number, info.cards[i].label),
              ),
            ],

            if (info.cardHolder.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CopyRow(
                label: 'Karta egasi',
                value: info.cardHolder,
                onCopy: () => onCopy(info.cardHolder, 'Karta egasi'),
              ),
            ],
            if (info.note.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colorSurfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(info.note, style: theme.textTheme.bodySmall),
              ),
            ],
            if (info.telegram.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => onOpen(info.telegram),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Chekni yuborish'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Nusxalash',
          icon: const Icon(Icons.copy_rounded, size: 18),
          onPressed: onCopy,
        ),
      ],
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

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.open_in_new_rounded, size: 16),
      onTap: onTap,
    );
  }
}
