import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { sanitizeLogin } from './tenant.js';

/**
 * Login `admin_logins/{login}` yo'lida BAZA KALITI bo'lib yoziladi.
 * RTDB kalitida taqiqlangan belgi qolib ketsa, ro'yxatdan o'tish 500
 * bilan yiqiladi — foydalanuvchi esa sababini bilmaydi.
 *
 * `app/lib/services/auth_service.dart` dagi nusxasi shu qoidalarga
 * AYNAN mos bo'lishi shart.
 */
describe('sanitizeLogin', () => {
  const forbidden = ['.', '#', '$', '/', '[', ']'];

  it('RTDB kalitida taqiqlangan belgilarni olib tashlaydi', () => {
    for (const ch of forbidden) {
      const out = sanitizeLogin(`ali${ch}vali`);
      assert.equal(
        out,
        'alivali',
        `"${ch}" belgisi qolib ketdi: "${out}"`,
      );
    }
  });

  it('nuqtali login ro\'yxatdan o\'tishni buzmaydi', () => {
    // Eng ehtimolli holat: odam "ali.vali" deb yozadi.
    assert.equal(sanitizeLogin('ali.vali'), 'alivali');
  });

  it('bir xil kiritma har doim bir xil natija beradi', () => {
    // Ro'yxatdan o'tishda va kirishda bir xil tozalash qo'llanadi -
    // shuning uchun foydalanuvchi o'zi yozgan matn bilan kira oladi.
    const typed = '  Ali.Vali  ';
    assert.equal(sanitizeLogin(typed), sanitizeLogin(sanitizeLogin(typed)));
  });

  it('ruxsat etilgan belgilarni saqlaydi', () => {
    assert.equal(sanitizeLogin('ali_vali-99'), 'ali_vali-99');
  });

  it('katta harfni kichkinaga aylantiradi', () => {
    assert.equal(sanitizeLogin('AliVali'), 'alivali');
  });

  it('bo\'sh joy va yozuv belgilarini tashlaydi', () => {
    assert.equal(sanitizeLogin(' ali vali! '), 'alivali');
  });
});
