import 'package:cscrm/models/license_status.dart';
import 'package:cscrm/services/license_service.dart';
import 'package:cscrm/screens/subscription/subscription_blocked_screen.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bloklash ekrani to'g'ri chizilishini tekshiradi.
///
/// Ekran rejalarni serverdan olishga harakat qiladi; testda tarmoq yo'q,
/// shuning uchun so'rov xatolik bilan tugaydi. Bu ATAYLAB tekshiriladi —
/// server javob bermasa ham ekran ishlashi va "Tekshirish" tugmasi ochiq
/// qolishi kerak.

LicenseStatus status({
  LicenseState state = LicenseState.expired,
  String message = 'Obuna muddati tugagan.',
  bool blocked = true,
  String kind = 'subscription',
}) {
  return LicenseStatus(
    tenantId: 't1',
    state: state,
    planId: 'm3',
    kind: kind,
    expiresAt: 1766448000000,
    daysLeft: -2,
    checkedAt: 1766793600000,
    ttlSeconds: 21600,
    message: message,
    blocked: blocked,
  );
}

Widget wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: child,
    );

/// Sinov oynasini BALAND qilamiz.
///
/// Ekran `ListView` ichida chiziladi, u esa ko'rinmaydigan elementni
/// umuman qurmaydi. Odatiy 600px li sinov oynasida pastdagi tugmalar
/// qurilmay qoladi va test ularni "yo'q" deb hisoblaydi — holbuki
/// haqiqiy qurilmada foydalanuvchi ularni skroll qilib ko'radi.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Serverga chiqmaydigan soxta xizmat.
///
/// Haqiqiy `LicenseService` tarmoqqa boradi; testda esa aynan qaysi
/// javob kelganda ekran nima ko'rsatishini tekshirmoqchimiz.
class _FakeService extends LicenseService {
  _FakeService({this.request, this.plans = const []});

  final PaymentRequest? request;
  final List<SubscriptionPlan> plans;

  @override
  Future<PaymentRequest?> fetchPaymentRequest() async => request;

  @override
  Future<({List<SubscriptionPlan> plans, PaymentInfo payment})>
      fetchPlans() async => (
            plans: plans,
            payment: const PaymentInfo(
              cards: [
                PaymentCardInfo(number: '9860 0000 0000 0000', type: 'Humo'),
                PaymentCardInfo(number: '8600 0000 0000 0000', type: 'Uzcard'),
              ],
              cardHolder: 'CSCRM',
              phone: '',
              email: '',
              telegram: '',
              note: '',
              configured: true,
            ),
          );
}

PaymentRequest request({
  String status = 'pending',
  String? rejectReason,
}) =>
    PaymentRequest(
      id: 'r1',
      planId: 'm3',
      planName: '3 oylik',
      amount: 300000,
      createdAt: 1766793600000,
      status: status,
      rejectReason: rejectReason,
    );

const _plan = SubscriptionPlan(
  id: 'm3',
  name: '3 oylik',
  price: 300000,
  description: '',
  kind: 'subscription',
  months: 3,
  highlight: true,
);

void main() {
  testWidgets('muddat tugaganda sabab va xabar ko\'rinadi', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
      status: status(message: 'Obuna muddati tugagan. To\'lov qiling.'),
      isOwner: true,
    )));
    await tester.pump();

    expect(find.text('Obuna muddati tugadi'), findsOneWidget);
    expect(find.text('Obuna muddati tugagan. To\'lov qiling.'), findsOneWidget);
  });

  testWidgets('"Tekshirish" tugmasi ikkala rolga ham ko\'rinadi',
      (tester) async {
    useTallSurface(tester);
    for (final isOwner in [true, false]) {
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: isOwner,
      )));
      await tester.pump();

      expect(
        find.text('Tekshirish'),
        findsOneWidget,
        reason: 'xodim ham to\'lov o\'tganini o\'zi tekshira olishi kerak '
            '(isOwner=$isOwner)',
      );
    }
  });

  testWidgets('xodimga to\'lov emas, ko\'rsatma ko\'rsatiladi',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
      status: status(),
      isOwner: false,
    )));
    await tester.pump();

    expect(find.text('Nima qilish kerak'), findsOneWidget);
    expect(find.textContaining('biznes rahbari'), findsOneWidget);
    expect(
      find.text('Rejalar'),
      findsNothing,
      reason: 'xodim reja tanlamaydi',
    );
  });

  testWidgets('to\'xtatilgan hisob boshqacha sarlavha bilan chiqadi',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
      status: status(
        state: LicenseState.suspended,
        message: 'Hisobingiz vaqtincha to\'xtatilgan.',
      ),
      isOwner: true,
    )));
    await tester.pump();

    expect(find.text('Hisob to\'xtatilgan'), findsOneWidget);
  });

  group('ogohlantirish holati — hali hech narsa tugamagan', () {
    // Bu ekran ogohlantirish chizig'i bosilganda ham ochiladi. Ilgari
    // `expiring` holati `default` shoxga tushib, "Obuna muddati tugadi"
    // deb YOLG'ON aytardi: muddat hali tugamagan, faqat yaqinlashgan.

    testWidgets('bir umrlik: baza to\'lovi yaqinligini aytadi',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(
          state: LicenseState.expiring,
          kind: 'lifetime',
          blocked: false,
          message: 'Yillik baza to\'lovigacha 5 kun qoldi.',
        ),
        isOwner: true,
      )));
      await tester.pump();

      expect(find.text('Yillik baza to\'lovi yaqin'), findsOneWidget);
      expect(
        find.text('Obuna muddati tugadi'),
        findsNothing,
        reason: 'bir umrlik rejada obuna degan narsa yo\'q',
      );
    });

    testWidgets('obuna: muddat tugagan deb aytmaydi', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(
          state: LicenseState.expiring,
          blocked: false,
          message: 'Muddat tugashiga 3 kun qoldi.',
        ),
        isOwner: true,
      )));
      await tester.pump();

      expect(find.text('Muddat tugayapti'), findsOneWidget);
      expect(find.text('Obuna muddati tugadi'), findsNothing);
    });
  });

  testWidgets('bir umrlik yillik to\'lov alohida ko\'rinadi', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
      status: status(
        state: LicenseState.lifetimeFeeDue,
        message: 'Yillik baza to\'lovi muddati o\'tdi.',
      ),
      isOwner: true,
    )));
    await tester.pump();

    expect(find.text('Yillik baza to\'lovi'), findsOneWidget);
  });

  testWidgets('server javob bermasa ham ekran ishlaydi', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
      status: status(),
      isOwner: true,
    )));
    // Rejalar so'rovi tugashini kutamiz (tarmoq yo'q - xatolik bilan).
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tekshirish'), findsOneWidget);
    expect(find.text('Biz bilan bog\'laning'), findsOneWidget);
  });

  group('to\'lov so\'rovi', () {
    testWidgets('kutilayotgan so\'rov ikkala rolga ham ko\'rinadi',
        (tester) async {
      useTallSurface(tester);
      for (final isOwner in [true, false]) {
        await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
          status: status(),
          isOwner: isOwner,
          service: _FakeService(request: request(), plans: const [_plan]),
        )));
        await tester.pump();

        expect(
          find.text('Tasdiqlanishi kutilmoqda'),
          findsOneWidget,
          reason: 'xodim ham xabar berilganini bilishi kerak '
              '(isOwner=$isOwner)',
        );
      }
    });

    testWidgets('kutilayotgan so\'rov paytida tugma yashiriladi',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: true,
        service: _FakeService(request: request(), plans: const [_plan]),
      )));
      await tester.pump();

      expect(
        find.text('To\'lov haqida xabar berish'),
        findsNothing,
        reason: 'server ikkinchi so\'rovni qabul qilmaydi',
      );
    });

    testWidgets('so\'rov yo\'q bo\'lsa egaga tugma ko\'rinadi',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: true,
        service: _FakeService(plans: const [_plan]),
      )));
      await tester.pump();

      expect(find.text('To\'lov haqida xabar berish'), findsOneWidget);
    });

    testWidgets('xodimga to\'lov tugmasi berilmaydi', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: false,
        service: _FakeService(plans: const [_plan]),
      )));
      await tester.pump();

      expect(find.text('To\'lov haqida xabar berish'), findsNothing);
    });

    testWidgets('rad etilgan so\'rovda sabab ko\'rsatiladi', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: true,
        service: _FakeService(
          request: request(status: 'rejected', rejectReason: 'To\'lov kelmadi'),
          plans: const [_plan],
        ),
      )));
      await tester.pump();

      expect(find.text('So\'rov rad etildi'), findsOneWidget);
      expect(find.textContaining('To\'lov kelmadi'), findsOneWidget);
    });
  });

  group('to\'lov rekvizitlari', () {
    testWidgets('karta ma\'lumotlari KO\'RSATILMAYDI', (tester) async {
      // Rekvizitlar endi Telegram yoki telefon orqali beriladi —
      // ilovada karta raqami turmaydi.
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: true,
        service: _FakeService(plans: const [_plan]),
      )));
      await tester.pump();

      expect(find.textContaining('9860'), findsNothing);
      expect(find.textContaining('kartasi'), findsNothing);
      expect(find.textContaining('Chekni yuborish'), findsNothing);
    });

    testWidgets('aloqa tugmalari ikkala rolga ham ko\'rinadi',
        (tester) async {
      useTallSurface(tester);
      for (final isOwner in [true, false]) {
        await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
          status: status(),
          isOwner: isOwner,
          service: _FakeService(plans: const [_plan]),
        )));
        await tester.pump();

        expect(find.text('Telegram'), findsOneWidget,
            reason: 'isOwner=$isOwner');
        expect(find.text('Qo\'ng\'iroq'), findsOneWidget,
            reason: 'isOwner=$isOwner');
      }
    });

    testWidgets('egaga reja tanlash beriladi', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: true,
        service: _FakeService(plans: const [_plan]),
      )));
      await tester.pump();

      expect(find.text('Rejani tanlang'), findsOneWidget);
      expect(find.text('3 oylik'), findsOneWidget);
    });

    testWidgets('xodimga reja ko\'rsatilmaydi', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(wrap(SubscriptionBlockedScreen(
        status: status(),
        isOwner: false,
        service: _FakeService(plans: const [_plan]),
      )));
      await tester.pump();

      expect(find.text('Rejani tanlang'), findsNothing);
    });
  });
}
