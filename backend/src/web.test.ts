import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { isSpaRoute } from './web.js';

describe('isSpaRoute — qaysi yo\'lga index.html beriladi', () => {
  it('sahifa yo\'llari SPA\'ga ketadi', () => {
    for (const p of ['/', '/narxlar', '/admin/tenants/t_abc', '/kirish']) {
      assert.equal(isSpaRoute(p), true, p);
    }
  });

  it('noma\'lum API yo\'li HTML olmaydi', () => {
    assert.equal(isSpaRoute('/api/v1/nope'), false);
  });

  it('eski yoki yo\'q JS fayl HTML olmaydi — 404', () => {
    assert.equal(isSpaRoute('/assets/index-OLD123.js'), false);
    assert.equal(isSpaRoute('/assets/index-OLD123.js.map'), false);
  });

  it('kengaytmali fayllar (robots.txt va h.k.) HTML olmaydi', () => {
    assert.equal(isSpaRoute('/robots.txt'), false);
    assert.equal(isSpaRoute('/sitemap.xml'), false);
  });

  it('nuqtali biznes ID\'si sahifa yo\'lini buzmaydi', () => {
    // Kengaytma faqat oxirgi bo'lakdagi harf-raqamli qo'shimcha.
    assert.equal(isSpaRoute('/admin/tenants/abc-123'), true);
  });
});
