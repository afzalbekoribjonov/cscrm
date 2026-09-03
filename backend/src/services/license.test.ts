import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import type { License } from '../types/license.js';
import { computeExpiry, evaluate, findPlan, sign, verify } from './license.js';

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 0, 15); // barqaror sana - test vaqtga bog'liq emas

function sub(overrides: Partial<License> = {}): License {
  return {
    tenantId: 't1',
    planId: 'm3',
    kind: 'subscription',
    startedAt: NOW - 30 * DAY,
    expiresAt: NOW + 30 * DAY,
    ...overrides,
  };
}

describe('computeExpiry', () => {
  it('sinov muddatini kunlarda hisoblaydi', () => {
    const trial = findPlan('trial')!;
    assert.equal(computeExpiry(trial, NOW), NOW + 14 * DAY);
  });

  it('oylik rejani kalendar oyi bo\'yicha hisoblaydi', () => {
    const m3 = findPlan('m3')!;
    const got = new Date(computeExpiry(m3, NOW)!);
    assert.equal(got.getUTCMonth(), 3); // yanvar + 3 oy = aprel
    assert.equal(got.getUTCDate(), 15);
  });

  it('bir umrlik uchun muddat yo\'q', () => {
    const lifetime = findPlan('lifetime')!;
    assert.equal(computeExpiry(lifetime, NOW), null);
  });
});

describe('evaluate — muddatli obuna', () => {
  it('muddat uzoq bo\'lsa faol va bloklanmagan', () => {
    const r = evaluate(sub(), NOW);
    assert.equal(r.state, 'active');
    assert.equal(r.blocked, false);
    assert.equal(r.daysLeft, 30);
  });

  it('7 kundan kam qolsa ogohlantiradi, lekin bloklamaydi', () => {
    const r = evaluate(sub({ expiresAt: NOW + 5 * DAY }), NOW);
    assert.equal(r.state, 'expiring');
    assert.equal(r.blocked, false);
  });

  it('muddat tugagach grace davrida ishlashda davom etadi', () => {
    const r = evaluate(sub({ expiresAt: NOW - 1 * DAY }), NOW);
    assert.equal(r.state, 'grace');
    assert.equal(r.blocked, false, 'grace davrida bloklanmasligi kerak');
  });

  it('grace tugagach bloklaydi', () => {
    const r = evaluate(sub({ expiresAt: NOW - 5 * DAY }), NOW);
    assert.equal(r.state, 'expired');
    assert.equal(r.blocked, true);
  });

  it('grace chegarasining aynan o\'zida hali bloklanmaydi', () => {
    // grace = 3 kun; 3 kun o'tgan payt hali "expired" emas.
    const r = evaluate(sub({ expiresAt: NOW - 3 * DAY }), NOW);
    assert.equal(r.state, 'grace');
  });
});

describe('evaluate — bir umrlik', () => {
  const lifetime = (over: Partial<License> = {}) =>
    sub({ planId: 'lifetime', kind: 'lifetime', expiresAt: null, ...over });

  it('yillik to\'lov muddati kelmagan bo\'lsa faol', () => {
    const r = evaluate(lifetime({ nextAnnualFeeAt: NOW + 100 * DAY }), NOW);
    assert.equal(r.state, 'active');
    assert.equal(r.blocked, false);
  });

  it('yillik to\'lov kechikkanda avval ogohlantiradi', () => {
    const r = evaluate(lifetime({ nextAnnualFeeAt: NOW - 1 * DAY }), NOW);
    assert.equal(r.state, 'lifetime_fee_due');
    assert.equal(r.blocked, false);
  });

  it('yillik to\'lov grace\'dan ham o\'tsa bloklaydi', () => {
    const r = evaluate(lifetime({ nextAnnualFeeAt: NOW - 10 * DAY }), NOW);
    assert.equal(r.state, 'lifetime_fee_due');
    assert.equal(r.blocked, true);
  });
});

describe('evaluate — to\'xtatilgan', () => {
  it('suspended har qanday muddatdan ustun turadi', () => {
    const r = evaluate(
      sub({ suspended: true, expiresAt: NOW + 300 * DAY }),
      NOW,
    );
    assert.equal(r.state, 'suspended');
    assert.equal(r.blocked, true, 'muddat yetarli bo\'lsa ham bloklanadi');
  });

  it('to\'xtatish sababi ko\'rsatiladi', () => {
    const r = evaluate(
      sub({ suspended: true, suspendedReason: 'To\'lov qaytarildi' }),
      NOW,
    );
    assert.equal(r.message, 'To\'lov qaytarildi');
  });
});

describe('imzo', () => {
  it('o\'zi yaratgan imzoni tasdiqlaydi', () => {
    const p = evaluate(sub(), NOW);
    assert.equal(verify(p, sign(p)), true);
  });

  it('payload o\'zgartirilsa imzo yaroqsiz bo\'ladi', () => {
    // Muddati TUGAGAN litsenziyadan boshlaymiz - aks holda "o'zgartirish"
    // hech narsani o'zgartirmagan bo'lardi va test bekorga o'tib ketardi.
    const p = evaluate(sub({ expiresAt: NOW - 30 * DAY }), NOW);
    assert.equal(p.blocked, true, 'boshlang\'ich holat bloklangan bo\'lishi kerak');

    const signature = sign(p);
    // Hujumchi "bloklanmagan" deb o'zgartirmoqchi bo'ldi.
    const tampered = { ...p, blocked: false, state: 'active' as const };
    assert.equal(verify(tampered, signature), false);
  });

  it('muddatni cho\'zishga urinish ham aniqlanadi', () => {
    const p = evaluate(sub({ expiresAt: NOW - 10 * DAY }), NOW);
    const signature = sign(p);
    const tampered = { ...p, expiresAt: NOW + 999 * DAY };
    assert.equal(verify(tampered, signature), false);
  });

  it('noto\'g\'ri uzunlikdagi imzo yiqilmaydi, faqat false qaytaradi', () => {
    const p = evaluate(sub(), NOW);
    assert.equal(verify(p, 'qisqa'), false);
  });
});
