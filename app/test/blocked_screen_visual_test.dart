import 'package:cscrm/models/license_status.dart';
import 'package:cscrm/screens/subscription/subscription_blocked_screen.dart';
import 'package:cscrm/services/license_service.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ekran haqiqiy telefon o'lchamlarida buzilmasligini tekshiradi.
///
/// Eng tor telefon (320px) ham, eng baland ro'yxat ham — hech qayerda
/// matn kesilmasligi yoki chegaradan chiqmasligi kerak.

class _Fake extends LicenseService {
  @override
  Future<PaymentRequest?> fetchPaymentRequest() async => null;

  @override
  Future<({List<SubscriptionPlan> plans, PaymentInfo payment})>
      fetchPlans() async => (plans: _plans, payment: PaymentInfo.empty);
}

const _plans = [
  SubscriptionPlan(
    id: 'm1', name: '1 oylik', price: 199000, description: 'Qisqa muddat.',
    kind: 'subscription', months: 1, highlight: false,
  ),
  SubscriptionPlan(
    id: 'm3', name: '3 oylik', price: 537000,
    description: 'Eng ko\'p tanlanadigan reja.',
    kind: 'subscription', months: 3, highlight: true,
  ),
  SubscriptionPlan(
    id: 'y1', name: '1 yillik', price: 1790000,
    description: 'Eng foydali reja.',
    kind: 'subscription', months: 12, highlight: false,
  ),
  SubscriptionPlan(
    id: 'lifetime', name: 'Bir umrlik', price: 4500000,
    description: 'Bir marta to\'lang.',
    kind: 'lifetime', months: null, highlight: false,
    lifetimeAnnualFeeUsd: 50,
  ),
];

LicenseStatus _status() => LicenseStatus(
      tenantId: 't1',
      state: LicenseState.expired,
      planId: 'm3',
      kind: 'subscription',
      expiresAt: 1766448000000,
      daysLeft: -2,
      checkedAt: 1766793600000,
      ttlSeconds: 21600,
      message: 'Obuna muddati tugagan.',
      blocked: true,
    );

Future<void> pumpAt(WidgetTester tester, Size size, {bool owner = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: SubscriptionBlockedScreen(
      status: _status(),
      isOwner: owner,
      service: _Fake(),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('eng tor telefonda buzilmaydi', (tester) async {
    await pumpAt(tester, const Size(320, 3000));
    expect(tester.takeException(), isNull);
    expect(find.text('Rejani tanlang'), findsOneWidget);
  });

  testWidgets('odatiy telefonda buzilmaydi', (tester) async {
    await pumpAt(tester, const Size(390, 3000));
    expect(tester.takeException(), isNull);
  });

  testWidgets('barcha rejalar chiziladi', (tester) async {
    await pumpAt(tester, const Size(390, 3000));
    for (final p in _plans) {
      expect(find.text(p.name), findsOneWidget, reason: p.id);
    }
  });

  testWidgets('oylik narx faqat ko\'p oylik rejalarda', (tester) async {
    await pumpAt(tester, const Size(390, 3000));
    // 3 oylik: 537000 / 3 = 179 000
    expect(find.textContaining('179'), findsOneWidget);
    // 1 oylikda oylik narx takrorlanmaydi.
    expect(find.textContaining('199 000 so\'m/oy'), findsNothing);
  });

  testWidgets('ommabop reja standart tanlangan', (tester) async {
    await pumpAt(tester, const Size(390, 3000));
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
  });

  testWidgets('boshqa reja bosilsa tanlov ko\'chadi', (tester) async {
    await pumpAt(tester, const Size(390, 3000));
    await tester.tap(find.text('1 yillik'));
    await tester.pump();
    expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bir umrlik yillik to\'lovi ko\'rinadi', (tester) async {
    await pumpAt(tester, const Size(390, 3000));
    expect(find.textContaining('Yiliga \$50'), findsOneWidget);
  });
}
