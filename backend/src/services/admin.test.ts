import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { findPlan } from './license.js';
import { computeRenewal } from './admin.js';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 5, 15); // 15-iyun

describe('computeRenewal — muddat hisobi', () => {
  const m3 = findPlan('m3')!;
  const y1 = findPlan('y1')!;
  const lifetime = findPlan('lifetime')!;

  it('muddati tugagan obuna BUGUNDAN boshlanadi', () => {
    const expired = NOW - 40 * DAY;
    const r = computeRenewal(m3, expired, NOW);

    const got = new Date(r.expiresAt!);
    assert.equal(got.getUTCMonth(), 8, 'iyun + 3 oy = sentabr');
    assert.equal(got.getUTCDate(), 15);
  });

  it('muddati tugamagan obuna MAVJUDIGA qo\'shiladi', () => {
    // Yana 20 kun bor - mijoz oldindan to'ladi.
    const stillValid = NOW + 20 * DAY;
    const r = computeRenewal(m3, stillValid, NOW);

    const got = new Date(r.expiresAt!);
    // 5-iyul + 3 oy = 5-oktabr
    assert.equal(got.getUTCMonth(), 9);
    assert.equal(got.getUTCDate(), 5);
  });

  it('oldindan to\'lagan mijoz kunini yo\'qotmaydi', () => {
    const stillValid = NOW + 20 * DAY;
    const r = computeRenewal(m3, stillValid, NOW);
    assert.ok(
      r.expiresAt! > stillValid,
      'yangi muddat mavjudidan uzoqroq bo\'lishi shart',
    );
  });

  it('muddat yo\'q bo\'lsa bugundan boshlanadi', () => {
    const r = computeRenewal(m3, null, NOW);
    const got = new Date(r.expiresAt!);
    assert.equal(got.getUTCMonth(), 8);
  });

  it('yillik reja bir yil qo\'shadi', () => {
    const r = computeRenewal(y1, null, NOW);
    const got = new Date(r.expiresAt!);
    assert.equal(got.getUTCFullYear(), 2027);
    assert.equal(got.getUTCMonth(), 5);
  });

  it('bir umrlik: muddat yo\'q, lekin yillik baza to\'lovi bor', () => {
    const r = computeRenewal(lifetime, null, NOW);
    assert.equal(r.expiresAt, null);
    assert.notEqual(r.nextAnnualFeeAt, null);

    const fee = new Date(r.nextAnnualFeeAt!);
    assert.equal(fee.getUTCFullYear(), 2027, 'to\'lov bir yildan keyin');
  });

  it('bir umrlikka o\'tganda oldingi muddat e\'tiborga olinmaydi', () => {
    const r = computeRenewal(lifetime, NOW + 100 * DAY, NOW);
    assert.equal(r.expiresAt, null);
  });

  it('muddatli rejada yillik baza to\'lovi bo\'lmaydi', () => {
    const r = computeRenewal(m3, null, NOW);
    assert.equal(r.nextAnnualFeeAt, null);
  });
});
