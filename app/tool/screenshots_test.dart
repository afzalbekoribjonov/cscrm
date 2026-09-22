// Ekranlarni PNG qilib chizadi — ko'z bilan tekshirish uchun.
//
// Ishga tushirish (`app/` papkasidan):
//     flutter test tool/screenshots_test.dart
//
// Fayllar `build/screens/` ga tushadi (git'ga kirmaydi).
//
// NEGA KERAK: joylashuv xatolari — matn chetdan chiqib ketishi, element
// bir-birining ustiga tushishi, tor ekranda siqilib qolishi — sinov
// tekshiruvlarida KO'RINMAYDI. Ular faqat chizilgan rasmda ko'rinadi.
//
// Fayl `test/` papkasidan tashqarida: bu tekshiruv emas, vosita.

import 'package:cscrm/screens/auth/register_business_screen.dart';
import 'package:cscrm/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'render.dart';

/// Odatiy telefon o'lchami (mantiqiy piksel).
const _phone = Size(390, 844);

/// Eng tor tarqalgan telefon — siqilish shu yerda ko'rinadi.
const _narrow = Size(320, 640);

Widget _app(Widget home, {bool dark = false}) => MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      // Burchakdagi qizil "DEBUG" lentasi rasmni bekitadi.
      debugShowCheckedModeBanner: false,
      home: home,
    );

void main() {
  testWidgets('ekranlar chiziladi', (tester) async {
    // Mavzu tarmoqqa chiqmasin: ilovaning asosiy shrifti (Manrope)
    // internetdan yuklanadi, bu yerda esa tarmoq yo'q. O'rniga
    // yuqorida yuklangan Roboto ishlatiladi — joylashuvni tekshirish
    // uchun shu yetarli.
    //
    // LOGOTIP bundan mustasno: uning shrifti ilovaga qo'shib
    // yuborilgan, shuning uchun u haqiqiy ko'rinishida chiziladi.
    AppTheme.textThemeSource = () => Typography.blackMountainView.apply(
          fontFamily: renderFont,
        );

    await loadRenderFont();

    await renderToPng(
      tester,
      child: _app(const RegisterBusinessScreen()),
      path: 'build/screens/register-1-biznes.png',
      size: _phone,
    );

    await renderToPng(
      tester,
      child: _app(const RegisterBusinessScreen(), dark: true),
      path: 'build/screens/register-1-biznes-tun.png',
      size: _phone,
    );

    await renderToPng(
      tester,
      child: _app(const RegisterBusinessScreen()),
      path: 'build/screens/register-1-tor.png',
      size: _narrow,
    );
  });
}
