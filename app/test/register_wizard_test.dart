import 'package:cscrm/screens/auth/register_business_screen.dart';
import 'package:cscrm/services/auth_service.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ro'yxatdan o'tish sehrgari — har bir savol alohida ekranda.
///
/// Bu sinovlar asosan BIR narsani qo'riqlaydi: foydalanuvchi to'ldirmay
/// oldinga o'tib keta olmasligi. Sehrgarning butun ma'nosi shunda —
/// aks holda u shunchaki bo'laklarga bo'lingan formaga aylanadi va
/// oxirida "nimadir to'ldirilmagan" degan xabar chiqadi.

Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

/// Serverga chiqmaydigan soxta xizmat.
class _FakeAuth implements BusinessRegistrar {
  _FakeAuth(this.failure);

  final AuthFailure failure;
  var calls = 0;

  @override
  Future<SignInResult> registerBusiness({
    required String businessName,
    required String login,
    required String password,
    String? phone,
  }) async {
    calls++;
    throw failure;
  }
}

/// Tugma yoniqmi.
bool actionEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(find.byType(FilledButton));
  return button.onPressed != null;
}

/// Joriy qadamdagi maydonga yozadi.
Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump();
}

/// Asosiy tugmani bosadi va o'tish animatsiyasini tugatadi.
Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('birinchi savol biznes nomi', (tester) async {
    await tester.pumpWidget(wrap(const RegisterBusinessScreen()));
    await tester.pump();

    expect(find.text('Biznesingiz nomi'), findsOneWidget);
    expect(
      find.byType(TextField),
      findsOneWidget,
      reason: 'bir vaqtda faqat bitta savol ko\'rinishi kerak',
    );
  });

  testWidgets('bo\'sh maydonda davom etib bo\'lmaydi', (tester) async {
    await tester.pumpWidget(wrap(const RegisterBusinessScreen()));
    await tester.pump();

    expect(actionEnabled(tester), isFalse);

    await type(tester, 'N');
    expect(actionEnabled(tester), isFalse, reason: 'bitta harf yetarli emas');

    await type(tester, 'Nihol');
    expect(actionEnabled(tester), isTrue);
  });

  testWidgets('to\'liq bo\'lmagan telefon o\'tkazmaydi', (tester) async {
    await tester.pumpWidget(wrap(const RegisterBusinessScreen()));
    await tester.pump();

    await type(tester, 'Nihol gilam yuvish');
    await tapNext(tester);
    expect(find.text('Telefon raqamingiz'), findsOneWidget);

    await type(tester, '+998 90 123');
    expect(
      actionEnabled(tester),
      isFalse,
      reason: 'mahalliy qismi 9 xonaga yetmagan',
    );

    await type(tester, '+998 90 123 45 67');
    expect(actionEnabled(tester), isTrue);
  });

  testWidgets('qisqa login va parol o\'tkazmaydi', (tester) async {
    await tester.pumpWidget(wrap(const RegisterBusinessScreen()));
    await tester.pump();

    await type(tester, 'Nihol');
    await tapNext(tester);
    await type(tester, '998901234567');
    await tapNext(tester);

    expect(find.text('Login o\'ylab toping'), findsOneWidget);
    await type(tester, 'ni');
    expect(actionEnabled(tester), isFalse);

    // Belgilar tozalangach 3 ta harf qoladi — yetarli.
    await type(tester, 'ni!!hol');
    expect(actionEnabled(tester), isTrue);

    await tapNext(tester);
    expect(find.text('Parol yarating'), findsOneWidget);

    await type(tester, '12345');
    expect(actionEnabled(tester), isFalse);
    await type(tester, '123456');
    expect(actionEnabled(tester), isTrue);
  });

  testWidgets('orqaga qaytganda oldingi javob saqlanadi', (tester) async {
    await tester.pumpWidget(wrap(const RegisterBusinessScreen()));
    await tester.pump();

    // Ko'rsatma matni bilan bir xil bo'lmasin — aks holda qidiruv
    // ikkalasini ham topib, sinov noto'g'ri sababdan yiqilardi.
    await type(tester, 'Nihol servis');
    await tapNext(tester);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Biznesingiz nomi'), findsOneWidget);
    expect(
      find.text('Nihol servis'),
      findsOneWidget,
      reason: 'orqaga qaytganda yozilgan matn yo\'qolmasligi kerak',
    );
  });

  testWidgets('band login foydalanuvchini LOGIN qadamiga qaytaradi',
      (tester) async {
    // Eng muhim sinov. Xatolik oxirgi (parol) ekranida ko'rsatilsa,
    // foydalanuvchi "nimani tuzatay?" degan savol bilan qolardi —
    // tuzatiladigan maydon boshqa ekranda.
    final auth = _FakeAuth(
      AuthFailure('Bu login band. Boshqasini tanlang.', code: 'login_taken'),
    );

    await tester.pumpWidget(wrap(RegisterBusinessScreen(service: auth)));
    await tester.pump();

    await type(tester, 'Nihol');
    await tapNext(tester);
    await type(tester, '998901234567');
    await tapNext(tester);
    await type(tester, 'nihol');
    await tapNext(tester);
    await type(tester, 'parol123');
    await tapNext(tester);

    expect(auth.calls, 1);
    expect(find.text('Login o\'ylab toping'), findsOneWidget);
    expect(find.text('Bu login band. Boshqasini tanlang.'), findsOneWidget);
  });

  testWidgets('boshqa xatolik joyida ko\'rsatiladi', (tester) async {
    final auth = _FakeAuth(AuthFailure('Server javob bermadi.'));

    await tester.pumpWidget(wrap(RegisterBusinessScreen(service: auth)));
    await tester.pump();

    await type(tester, 'Nihol');
    await tapNext(tester);
    await type(tester, '998901234567');
    await tapNext(tester);
    await type(tester, 'nihol');
    await tapNext(tester);
    await type(tester, 'parol123');
    await tapNext(tester);

    expect(find.text('Parol yarating'), findsOneWidget);
    expect(find.text('Server javob bermadi.'), findsOneWidget);
  });

  testWidgets('xatolik yangi harf kiritilganda yo\'qoladi', (tester) async {
    final auth = _FakeAuth(AuthFailure('Server javob bermadi.'));

    await tester.pumpWidget(wrap(RegisterBusinessScreen(service: auth)));
    await tester.pump();

    await type(tester, 'Nihol');
    await tapNext(tester);
    await type(tester, '998901234567');
    await tapNext(tester);
    await type(tester, 'nihol');
    await tapNext(tester);
    await type(tester, 'parol123');
    await tapNext(tester);

    expect(find.text('Server javob bermadi.'), findsOneWidget);

    await type(tester, 'parol1234');
    expect(find.text('Server javob bermadi.'), findsNothing);
  });
}
