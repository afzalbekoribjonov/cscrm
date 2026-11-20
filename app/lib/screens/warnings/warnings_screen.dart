import 'package:flutter/material.dart' hide Text;

import '../../l10n/text.dart';
import '../../services/warning_center.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../ui/surfaces.dart';
import '../../utils/money.dart';
import '../../utils/uz_dates.dart';

/// Xodimning qayta yuvish ogohlantirishlari.
///
/// Ohangi ATAYLAB jiddiy: xodim yuvgan xizmat sifatsiz chiqqan va
/// mijozga qaytarib yuvilmoqda. Sahifa sababni, kim qaytarganini va
/// ushlab qolingan summani aniq ko'rsatadi. "Tanishdim" bosilgach
/// qo'ng'iroq yonidagi "!" belgisi yo'qoladi.
class WarningsScreen extends StatelessWidget {
  const WarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<WorkWarning>>(
      valueListenable: WarningCenter.instance,
      builder: (context, warnings, _) {
        final unseen = warnings.where((w) => !w.isSeen).length;
        final bottom = MediaQuery.of(context).padding.bottom;
        return Scaffold(
          appBar: AppBar(title: const Text('Ogohlantirishlar')),
          body: warnings.isEmpty
              ? const EmptyState(
                  icon: Icons.verified_rounded,
                  tone: StageTone.success,
                  title: 'Ogohlantirish yo\'q',
                  message: 'Ishingiz sifatli — shunday davom eting.',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                      Gap.page, 8, Gap.page, 24 + bottom + (unseen > 0 ? 72 : 0)),
                  children: [
                    if (unseen > 0) ...[
                      _SeriousBanner(count: unseen),
                      const SizedBox(height: 16),
                    ],
                    for (final w in warnings) ...[
                      _WarningCard(warning: w),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
          bottomSheet: unseen == 0
              ? null
              : Material(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          Gap.page, 8, Gap.page, 12),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          minimumSize: const Size.fromHeight(52),
                        ),
                        onPressed: () async {
                          await WarningCenter.instance.acknowledgeAll();
                        },
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text('Tanishdim, e\'tibor beraman'),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _SeriousBanner extends StatelessWidget {
  const _SeriousBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB91C1C), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.priority_high_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? 'Siz yuvgan xizmat qayta yuvishga qaytarildi'
                      : 'Siz yuvgan $count ta xizmat qayta yuvishga qaytarildi',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ishga mas\'uliyat bilan yondashing. Har bir buyurtma — '
                  'mijozning ishonchi. Xizmatni topshirishdan oldin '
                  'sifatini diqqat bilan tekshiring.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning});

  final WorkWarning warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = warning;
    final fresh = !w.isSeen;
    return AppCard(
      borderColor: fresh ? StageTone.danger.fill.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: Icons.replay_rounded,
                tone: fresh ? StageTone.danger : StageTone.neutral,
                size: 38,
                radius: 11,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.productName.isEmpty ? 'Xizmat' : w.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '№ ${w.orderId} · ${UzDates.dateTime(UzDates.fromMillis(w.at))}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (fresh)
                const TonePill(label: 'Yangi', tone: StageTone.danger, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          _Line(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Sabab',
            value: w.reason.isEmpty ? 'Ko\'rsatilmagan' : w.reason,
          ),
          if (w.byName.isNotEmpty)
            _Line(
              icon: Icons.person_outline_rounded,
              label: 'Qaytardi',
              value: w.byName,
            ),
          if (w.deduction > 0)
            _Line(
              icon: Icons.remove_circle_outline_rounded,
              label: 'Ishbayidan ushlandi',
              value: formatSom(w.deduction),
              danger: true,
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = danger ? StageTone.danger.ink(context) : null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ink ?? context.colorTextSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$label: ',
                  style: theme.textTheme.bodySmall,
                ),
                TextSpan(
                  text: value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
