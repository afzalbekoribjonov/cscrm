import '../models/license_status.dart';
import '../theme/app_colors.dart';
import 'license_clock.dart';
import 'uz_dates.dart';

/// Obuna holatining ko'rinishi: nom, rang va qolgan vaqt.
class SubscriptionView {
  const SubscriptionView({
    required this.label,
    required this.tone,
    this.remaining,
    this.expiresAt,
    this.ended = false,
  });

  final String label;
  final StageTone tone;

  /// "3 kun 5 soat", "45 daqiqa". Bir umrlikda — "Muddatsiz".
  final String? remaining;
  final DateTime? expiresAt;

  /// Muddat tugagan.
  final bool ended;
}

SubscriptionView subscriptionView(LicenseStatus? s, {int? deviceNow}) {
  if (s == null) {
    return const SubscriptionView(label: 'Tekshirilmoqda', tone: StageTone.neutral);
  }
  final (label, tone) = switch (s.state) {
    LicenseState.active => ('Faol', StageTone.success),
    LicenseState.expiring => ('Muddat yaqin', StageTone.warning),
    LicenseState.grace => ('Muddat tugadi', StageTone.warning),
    LicenseState.lifetimeFeeDue => ('Yillik to\'lov kerak', StageTone.packaging),
    LicenseState.expired => ('Bloklangan', StageTone.danger),
    LicenseState.suspended => ('To\'xtatilgan', StageTone.danger),
    LicenseState.unknown => ('Tekshirilmoqda', StageTone.neutral),
  };
  if (s.isLifetime && s.expiresAt == null) {
    return SubscriptionView(label: label, tone: tone, remaining: 'Muddatsiz');
  }
  final expires = s.expiresAt;
  if (expires == null) return SubscriptionView(label: label, tone: tone);

  // Qolgan vaqt SERVER vaqtiga nisbatan: qurilma soati orqaga surilgan
  // bo'lsa ham muddat "uzayib" ko'rinmaydi.
  final now = effectiveNow(
    deviceNow: deviceNow ?? DateTime.now().millisecondsSinceEpoch,
    lastServerTime: s.checkedAt,
  );
  final left = Duration(milliseconds: expires - now);
  return SubscriptionView(
    label: label,
    tone: tone,
    remaining: left.isNegative ? 'Muddat tugagan' : formatRemaining(left),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(expires),
    ended: left.isNegative,
  );
}
