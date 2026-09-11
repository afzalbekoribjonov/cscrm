import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { normalizeDownloadUrl } from './site-settings.js';

/**
 * Yuklab olish manzilining tekshiruvi.
 *
 * Bu sinovlar "chiroyli ko'rinish" haqida emas: manzil saytda
 * `<a href>` ichiga tushadi. Tekshiruvsiz `javascript:` sxemasi
 * yozilsa, uni bosgan har bir mehmonning brauzerida begona kod
 * ishga tushardi. Shuning uchun bu yerda eng muhimi — RAD ETILADIGAN
 * qiymatlar.
 */
describe('normalizeDownloadUrl', () => {
  it('to\'g\'ri https manzilni qabul qiladi', () => {
    const url = 'https://drive.google.com/file/d/abc123/view';
    assert.equal(normalizeDownloadUrl(url), url);
  });

  it('http ham qabul qilinadi', () => {
    assert.equal(normalizeDownloadUrl('http://example.uz/app.apk'), 'http://example.uz/app.apk');
  });

  it('bo\'sh qiymat xatolik emas — manzil hali yo\'q degani', () => {
    assert.equal(normalizeDownloadUrl(''), '');
    assert.equal(normalizeDownloadUrl('   '), '');
  });

  it('chetdagi bo\'shliqni tashlaydi', () => {
    assert.equal(
      normalizeDownloadUrl('  https://example.uz/a.apk  '),
      'https://example.uz/a.apk',
    );
  });

  it('javascript: sxemasini RAD ETADI', () => {
    // Eng muhim sinov: bu sxema saytga kod kiritishning to'g'ridan-
    // to'g'ri yo'li.
    assert.throws(() => normalizeDownloadUrl('javascript:alert(1)'));
  });

  it('data: sxemasini rad etadi', () => {
    assert.throws(() => normalizeDownloadUrl('data:text/html,<script>x</script>'));
  });

  it('sxemasiz manzilni rad etadi', () => {
    // "example.uz/app.apk" — brauzer buni nisbiy yo'l deb o'qiydi va
    // havola o'z saytimizning ichiga ishora qilib qolardi.
    assert.throws(() => normalizeDownloadUrl('example.uz/app.apk'));
  });

  it('umuman manzil bo\'lmagan matnni rad etadi', () => {
    assert.throws(() => normalizeDownloadUrl('shunchaki matn'));
  });
});
