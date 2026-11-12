import 'package:cscrm/models/license_status.dart';
import 'package:cscrm/screens/admin/profile_screen.dart';
import 'package:cscrm/services/license_controller.dart';
import 'package:cscrm/services/license_service.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cscrm/l10n/script.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Profilim" sahifasi.
///
/// Asosiy tekshiruv — TARIFLARNI TAQQOSLASH to'g'ri chiqishi. "Tejash"
/// foizi noto'g'ri hisoblansa, foydalanuvchi ataylab yolg'on raqamga
/// qarab qaror qabul qiladi.

Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

/// Serverga chiqmaydigan soxta xizmat.
class _FakeService extends LicenseService {
  _FakeService(this.plans);

  final List<SubscriptionPlan> plans;

  @override
  Future<({List<SubscriptionPlan> plans, PaymentInfo payment})>
      fetchPlans() async => (
            plans: plans,
            payment: const PaymentInfo(
              cards: [],
              cardHolder: '',
              phone: '',
              email: '',
              telegram: '',
              note: '',
              configured: false,
            ),
          );

  @override
  Future<PaymentRequest?> fetchPaymentRequest() async => null;
}

const _plans = [
  SubscriptionPlan(
    id: 'm1',
    name: '1 oylik',
    price: 200000,
    description: '',
    kind: 'subscription',
    months: 1,
    highlight: false,
  ),
  SubscriptionPlan(
    id: 'm3',
    name: '3 oylik',
    price: 540000,
    description: '',
    kind: 'subscription',
    months: 3,
    highlight: true,
  ),
];

LicenseStatus status({
  String planId = 'm1',
  LicenseState state = LicenseState.active,
  int? daysLeft = 12,
}) =>
    LicenseStatus(
      tenantId: 't1',
      state: state,
      planId: planId,
      kind: 'subscription',
      expiresAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
      daysLeft: daysLeft,
      checkedAt: 0,
      ttlSeconds: 21600,
      message: '',
      blocked: false,
    );

final _expires = DateTime(2026, 10, 1);

Widget screen({LicenseStatus? licence, DateTime? now}) {
  LicenseController.instance.value = licence == null
      ? null
      : LicenseResolution(status: licence, fromCache: false);

  return wrap(ProfileScreen(
    businessName: 'Nihol gilam yuvish',
    service: _FakeService(_plans),
    now: () => now ?? _expires.subtract(const Duration(days: 12)),
  ));
}

void main() {
  tearDown(() => LicenseController.instance.value = null);

  testWidgets('biznes nomi sarlavhada turadi', (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pump();
    expect(find.text(t('Nihol gilam yuvish')), findsOneWidget);
  });

  testWidgets("'Xodim' va 'Faol' sanoq kartalari endi yo'q", (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pump();
    expect(find.text(t('Xodim')), findsNothing);
  });

  testWidgets("joriy tarif va qolgan muddat ko'rinadi", (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pump();
    expect(find.text(t('Joriy tarif')), findsOneWidget);
    expect(find.text(t('12 kun')), findsOneWidget);
  });

  testWidgets('1 soatdan kam qolganda "1 kun" EMAS — daqiqa', (tester) async {
    await tester.pumpWidget(screen(
      licence: status(daysLeft: 1),
      now: _expires.subtract(const Duration(minutes: 59)),
    ));
    await tester.pump();
    expect(find.text(t('59 daqiqa')), findsOneWidget);
    expect(find.text(t('1 kun')), findsNothing);
  });

  testWidgets('bir kundan kam — soat va daqiqa', (tester) async {
    await tester.pumpWidget(screen(
      licence: status(daysLeft: 1),
      now: _expires.subtract(const Duration(hours: 5, minutes: 20)),
    ));
    await tester.pump();
    expect(find.text(t('5 soat 20 daqiqa')), findsOneWidget);
  });

  testWidgets("muddat o'tgan bo'lsa MANFIY qiymat ko'rsatilmaydi",
      (tester) async {
    await tester.pumpWidget(screen(
      licence: status(state: LicenseState.expired, daysLeft: -3),
      now: _expires.add(const Duration(days: 3)),
    ));
    await tester.pump();
    expect(find.text(t('Muddat tugagan')), findsOneWidget);
    expect(find.textContaining('-3'), findsNothing);
  });

  testWidgets("joriy tarif ro'yxatda belgilanadi", (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pump();
    expect(find.text(t('Joriy')), findsOneWidget);
  });

  testWidgets("tejash foizi to'g'ri hisoblanadi", (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pump();
    // 3 oylik: 540 000 / 3 = 180 000 so'm/oy; 1 oylik 200 000 ga nisbatan
    // 10% tejash.
    expect(find.text(t('10% tejash')), findsOneWidget);
  });

  testWidgets("obuna holati aniqlanmagan bo'lsa ham sahifa ochiladi",
      (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();
    expect(find.text(t('Nihol gilam yuvish')), findsOneWidget);
    expect(find.text(t('Joriy tarif')), findsNothing);
  });
}
