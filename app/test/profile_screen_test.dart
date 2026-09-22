import 'package:cscrm/models/employee.dart';
import 'package:cscrm/models/license_status.dart';
import 'package:cscrm/screens/admin/profile_screen.dart';
import 'package:cscrm/services/license_controller.dart';
import 'package:cscrm/services/license_service.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:flutter/material.dart';
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

Widget screen({LicenseStatus? licence}) {
  LicenseController.instance.value = licence == null
      ? null
      : LicenseResolution(status: licence, fromCache: false);

  return wrap(ProfileScreen(
    businessName: 'Nihol gilam yuvish',
    service: _FakeService(_plans),
    employees: Stream.value(const [
      Employee(
        id: 'e1',
        firstName: 'Sardor',
        lastName: '',
        phone: '998901234567',
        active: true,
        createdAt: 0,
        createdBy: '',
      ),
      Employee(
        id: 'e2',
        firstName: 'Malika',
        lastName: '',
        phone: '998901234568',
        active: false,
        createdAt: 0,
        createdBy: '',
      ),
    ]),
  ));
}

void main() {
  tearDown(() => LicenseController.instance.value = null);

  testWidgets('biznes nomi sarlavhada turadi', (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pumpAndSettle();

    expect(find.text('Nihol gilam yuvish'), findsOneWidget);
  });

  testWidgets('xodimlar soni va faollari alohida sanaladi', (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget, reason: 'jami xodim');
    expect(find.text('1'), findsOneWidget, reason: 'faol xodim');
  });

  testWidgets('joriy tarif nomi va qolgan muddat ko\'rinadi', (tester) async {
    await tester.pumpWidget(screen(licence: status()));
    await tester.pumpAndSettle();

    expect(find.text('JORIY TARIF'), findsOneWidget);
    expect(find.text('12 kun'), findsOneWidget);
  });

  testWidgets('muddat o\'tgan bo\'lsa MANFIY kun ko\'rsatilmaydi',
      (tester) async {
    // `-3 kun` degan yozuv ma'nosiz. Bu holatni alohida aytamiz.
    await tester.pumpWidget(screen(
      licence: status(state: LicenseState.expired, daysLeft: -3),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Muddat o\'tgan'), findsOneWidget);
    expect(find.textContaining('-3'), findsNothing);
  });

  testWidgets('joriy tarif ro\'yxatda belgilanadi', (tester) async {
    await tester.pumpWidget(screen(licence: status(planId: 'm3')));
    await tester.pumpAndSettle();

    expect(find.text('Joriy'), findsOneWidget);
  });

  testWidgets('tejash foizi to\'g\'ri hisoblanadi', (tester) async {
    // 1 oylik: 200 000/oy. 3 oylik: 540 000 / 3 = 180 000/oy.
    // Farq: 10%.
    await tester.pumpWidget(screen(licence: status()));
    await tester.pumpAndSettle();

    expect(find.text('10% tejash'), findsOneWidget);
    // Ajratgich belgisi lokaldan kelib chiqadi (oddiy bo'shliqmi yoki
    // uzilmaydiganmi) — sinov unga bog'lanmasligi kerak.
    expect(
      find.textContaining(RegExp(r'180.?000 so')),
      findsOneWidget,
      reason: 'taqqoslashda asosiy raqam — OYLIK narx',
    );
  });

  testWidgets('obuna holati aniqlanmagan bo\'lsa ham sahifa ochiladi',
      (tester) async {
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();

    expect(find.text('Nihol gilam yuvish'), findsOneWidget);
    expect(find.text('JORIY TARIF'), findsNothing);
  });
}
