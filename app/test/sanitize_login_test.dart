import 'package:cscrm/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Login server tomonida `admin_logins/{login}` BAZA KALITI bo'lib
/// yoziladi. RTDB kalitida `.` `#` `$` `/` `[` `]` bo'lishi mumkin emas.
///
/// Bu testlar `backend/src/services/tenant.test.ts` bilan bir xil —
/// ikki tomon bir xil tozalashi shart, aks holda odam ro'yxatdan
/// o'tgan login bilan kira olmay qoladi.
void main() {
  const forbidden = ['.', '#', '\$', '/', '[', ']'];

  test('RTDB kalitida taqiqlangan belgilarni olib tashlaydi', () {
    for (final ch in forbidden) {
      expect(
        AuthService.sanitizeLogin('ali${ch}vali'),
        'alivali',
        reason: '"$ch" belgisi qolib ketdi',
      );
    }
  });

  test('nuqtali login ro\'yxatdan o\'tishni buzmaydi', () {
    expect(AuthService.sanitizeLogin('ali.vali'), 'alivali');
  });

  test('bir xil kiritma har doim bir xil natija beradi', () {
    const typed = '  Ali.Vali  ';
    expect(
      AuthService.sanitizeLogin(typed),
      AuthService.sanitizeLogin(AuthService.sanitizeLogin(typed)),
    );
  });

  test('ruxsat etilgan belgilarni saqlaydi', () {
    expect(AuthService.sanitizeLogin('ali_vali-99'), 'ali_vali-99');
  });

  test('katta harfni kichkinaga aylantiradi', () {
    expect(AuthService.sanitizeLogin('AliVali'), 'alivali');
  });

  test('bo\'sh joy va yozuv belgilarini tashlaydi', () {
    expect(AuthService.sanitizeLogin(' ali vali! '), 'alivali');
  });
}
