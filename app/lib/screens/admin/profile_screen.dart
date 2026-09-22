import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/employee.dart';
import '../../models/license_status.dart';
import '../../services/employee_service.dart';
import '../../services/license_controller.dart';
import '../../services/license_service.dart';
import '../../theme/app_colors.dart';
import '../subscription/payment_request_sheet.dart';

final _money = NumberFormat.decimalPattern('uz');
final _date = DateFormat('dd.MM.yyyy');

/// Biznes profili: joriy tarif, muddat, xodimlar soni va boshqa rejalar.
///
/// NEGA KERAK. Obuna holati ilgari faqat MUDDAT TUGAGANDA — bloklash
/// ekranida ko'rinardi. Ya'ni foydalanuvchi qaysi tarifda ekanini va
/// qancha vaqt qolganini ish to'xtaganda bilardi. Bu sahifa o'sha
/// ma'lumotni har doim qo'l ostida saqlaydi.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.businessName,
    this.service,
    this.employees,
  });

  final String businessName;

  /// Sinovda almashtirish uchun. Odatda `null`.
  final LicenseService? service;

  /// Sinovda almashtirish uchun. Odatda `null` — xodimlar Firebase'dan
  /// jonli o'qiladi.
  final Stream<List<Employee>>? employees;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _service = widget.service ?? LicenseService();
  late final _employees = widget.employees ?? EmployeeService().streamEmployees();

  List<SubscriptionPlan> _plans = const [];
  var _loadingPlans = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final result = await _service.fetchPlans();
      if (!mounted) return;
      setState(() {
        _plans = result.plans.where((p) => !p.isTrial).toList();
        _loadingPlans = false;
      });
    } catch (_) {
      // Rejalar kelmasa ham sahifa ishlaydi: joriy tarif va xodimlar
      // soni mahalliy ma'lumotdan chiqadi.
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: LicenseController.instance,
          builder: (context, resolution, _) {
            final status = resolution?.status;

            return StreamBuilder<List<Employee>>(
              stream: _employees,
              builder: (context, snapshot) {
                final employees = snapshot.data ?? const <Employee>[];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    _BusinessHeader(
                      name: widget.businessName,
                      status: status,
                    ),
                    const SizedBox(height: 14),
                    _Counters(employees: employees),
                    const SizedBox(height: 22),
                    if (status != null) ...[
                      _PlanCard(status: status, plans: _plans),
                      const SizedBox(height: 22),
                    ],
                    if (_loadingPlans)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_plans.isNotEmpty)
                      _OtherPlans(
                        plans: _plans,
                        currentPlanId: status?.planId,
                        onPick: _openPayment,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openPayment(SubscriptionPlan plan) async {
    final sent = await showPaymentRequestSheet(
      context: context,
      plans: _plans,
      initialPlan: plan,
    );
    if (sent == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('So\'rovingiz yuborildi. Tasdiqlangach obuna uzayadi.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Bo'laklar
// ---------------------------------------------------------------------

/// Biznes nomi va obuna holati — sahifaning yuzi.
class _BusinessHeader extends StatelessWidget {
  const _BusinessHeader({required this.name, required this.status});

  final String name;
  final LicenseStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label) = _badge;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.brand],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name.isEmpty ? 'Biznes' : name,
            // Uzun nom uchta qatorgacha o'raladi, keyin qisqartiriladi —
            // aks holda u butun kartani cho'zib yuborardi.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  (Color, String) get _badge {
    final s = status;
    if (s == null) return (AppColors.licenseActive, 'Faol');

    return switch (s.state) {
      LicenseState.active => (AppColors.licenseActive, 'Faol'),
      LicenseState.expiring => (AppColors.licenseExpiring, 'Muddat yaqin'),
      LicenseState.grace => (AppColors.licenseExpiring, 'Muddat tugadi'),
      LicenseState.lifetimeFeeDue =>
        (AppColors.licenseLifetime, 'Yillik to\'lov'),
      LicenseState.expired => (AppColors.danger, 'Bloklangan'),
      LicenseState.suspended => (AppColors.danger, 'To\'xtatilgan'),
      // Server yangi holat yuborsa, ilova uni tanimaydi. Bunday
      // paytda "Faol" deb yozish yolg'on bo'lardi — holatni umuman
      // ko'rsatmaganimiz to'g'riroq.
      LicenseState.unknown => (AppColors.textSecondaryLight, 'Tekshirilmoqda'),
    };
  }
}

/// Raqamlar qatori: xodimlar soni va faollari.
class _Counters extends StatelessWidget {
  const _Counters({required this.employees});

  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final active = employees.where((e) => e.active).length;

    return Row(
      children: [
        Expanded(child: _Counter(value: '${employees.length}', label: 'Xodim')),
        const SizedBox(width: 12),
        Expanded(child: _Counter(value: '$active', label: 'Faol')),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Joriy tarif: nomi, muddati va qolgan kunlar.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.status, required this.plans});

  final LicenseStatus status;
  final List<SubscriptionPlan> plans;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = plans.where((p) => p.id == status.planId).firstOrNull;
    final name = plan?.name ?? _fallbackName;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JORIY TARIF',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 11,
                )),
            const SizedBox(height: 8),
            Text(
              name,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (status.expiresAt != null)
              _Line(
                label: 'Amal qiladi',
                value: _date.format(
                  DateTime.fromMillisecondsSinceEpoch(status.expiresAt!),
                ),
              ),
            if (status.daysLeft != null)
              _Line(
                label: 'Qolgan muddat',
                // Manfiy kun "−3 kun qoldi" bo'lib chiqardi — muddat
                // allaqachon o'tgan bo'lsa buni boshqacha aytamiz.
                value: status.daysLeft! >= 0
                    ? '${status.daysLeft} kun'
                    : 'Muddat o\'tgan',
              ),
            if (status.kind == 'lifetime')
              const _Line(label: 'Turi', value: 'Bir umrlik'),
          ],
        ),
      ),
    );
  }

  /// Rejalar yuklanmagan bo'lsa — hech bo'lmasa turi aytiladi.
  String get _fallbackName => switch (status.kind) {
        'trial' => 'Sinov muddati',
        'lifetime' => 'Bir umrlik',
        _ => 'Obuna',
      };
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Boshqa tariflar — uzoqroq muddat, arzonroq oylik narx.
class _OtherPlans extends StatelessWidget {
  const _OtherPlans({
    required this.plans,
    required this.currentPlanId,
    required this.onPick,
  });

  final List<SubscriptionPlan> plans;
  final String? currentPlanId;
  final ValueChanged<SubscriptionPlan> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /// Taqqoslash uchun tayanch — eng qisqa rejaning oylik narxi.
    final baseline = plans
        .where((p) => p.months == 1 && !p.priceUnset)
        .map((p) => p.price)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BOSHQA TARIFLAR',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 11,
            )),
        const SizedBox(height: 10),
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

  /// Oyiga tushadigan narx — tariflarni taqqoslashda asosiy raqam.
  int? get _perMonth {
    final months = plan.months;
    if (months == null || months < 1 || plan.priceUnset) return null;
    return (plan.price / months).round();
  }

  /// Eng qisqa tarifga nisbatan necha foiz arzon.
  int? get _saving {
    final per = _perMonth;
    final base = baseline;
    if (per == null || base == null || base <= 0) return null;
    final pct = ((1 - per / base) * 100).round();
    // 1-2 foiz "tejaysiz" deb ko'rsatishga arzimaydi — u yaxlitlash
    // xatosiga o'xshab qoladi.
    return pct >= 3 ? pct : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final per = _perMonth;
    final saving = _saving;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: current ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).cardTheme.color,
            border: Border.all(
              color: current ? AppColors.brand : theme.dividerColor,
              width: current ? 2 : 1,
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
                        Flexible(
                          child: Text(
                            plan.name,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: 8),
                          const _Tag(text: 'Joriy', color: AppColors.brand),
                        ] else if (saving != null) ...[
                          const SizedBox(width: 8),
                          _Tag(
                            text: '$saving% tejash',
                            color: AppColors.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      per == null
                          ? plan.description
                          : '${_money.format(per)} so\'m/oy',
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
                    plan.priceUnset
                        ? 'Kelishiladi'
                        : _money.format(plan.price.round()),
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
