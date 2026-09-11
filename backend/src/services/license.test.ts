import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import type { License } from '../types/license.js';
import {
  computeExpiry,
  evaluate,
  findPlan,
  GRACE_DAYS,
  LIFETIME_FEE_GRACE_DAYS,
  sign,
  verify,
  WARN_BEFORE_DAYS,
} from './license.js';

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
    assert.equal(computeExpiry(trial, NOW), NOW + 1 * DAY);
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

  it('sozlamada qo\'shimcha kunlar YO\'Q', () => {
    // Bu sinov qiymatning o'zini qo'riqlaydi. Qoida "muddat tugadi —
    // darhol bloklanadi" bo'lgani uchun, kimdir raqamni qaytadan
    // ko'tarsa buni BILIB qilishi kerak: quyidagi sinovlar emas, aynan
    // shu bittasi yiqiladi va sababini aytadi.
    assert.equal(GRACE_DAYS, 0, 'obunaga qo\'shimcha vaqt berilmaydi');
  });

  it('muddat tugagan zahoti bloklanadi', () => {
    // Bir soniya o'tgani ham yetarli — kun kutilmaydi.
    const r = evaluate(sub({ expiresAt: NOW - 1000 }), NOW);
    assert.equal(r.state, 'expired');
    assert.equal(r.blocked, true);
  });

  it('bir kun o\'tgach ham, besh kun o\'tgach ham bir xil — bloklangan', () => {
    for (const days of [1, 3, 5, 30]) {
      const r = evaluate(sub({ expiresAt: NOW - days * DAY }), NOW);
      assert.equal(r.state, 'expired', `${days} kun o'tgach`);
      assert.equal(r.blocked, true, `${days} kun o'tgach`);
    }
  });

  it('muddatning AYNAN o\'zida hali bloklanmaydi', () => {
    // Chegara sinovi: tugash lahzasi hali "o'tgan" emas. Aks holda
    // to'lagan kuni kirgan odam bloklangan ekranni ko'rardi.
    const r = evaluate(sub({ expiresAt: NOW }), NOW);
    assert.equal(r.blocked, false);
  });

  it('SINOV ham tugagan zahoti bloklanadi', () => {
    const r = evaluate(
      sub({ planId: 'trial', kind: 'trial', expiresAt: NOW - 1000 }),
      NOW,
    );
    assert.equal(r.state, 'expired');
    assert.equal(r.blocked, true);
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

  it('to\'lov sanasi yaqinlashganda OLDINDAN ogohlantiradi', () => {
    // Eng muhim sinov. Qo'shimcha kunlar olib tashlangach, bu yagona
    // ogohlantirish bo'lib qoldi: busiz mijoz uchun hammasi joyida
    // ko'rinar, keyin bir kuni ilova qulflanardi.
    const r = evaluate(lifetime({ nextAnnualFeeAt: NOW + 5 * DAY }), NOW);
    assert.equal(r.state, 'expiring');
    assert.equal(r.blocked, false, 'ogohlantirish — bloklash emas');
    assert.match(r.message, /baza to'lovigacha 5 kun/);
  });

  it('ogohlantirish jadvali obunanikiga mos', () => {
    const first = Math.max(...WARN_BEFORE_DAYS);

    // Jadvaldan bir kun oldin — hali jim.
    const before = evaluate(
      lifetime({ nextAnnualFeeAt: NOW + (first + 1) * DAY }),
      NOW,
    );
    assert.equal(before.state, 'active');

    // Jadvalning aynan boshi — ogohlantirish boshlanadi.
    const at = evaluate(lifetime({ nextAnnualFeeAt: NOW + first * DAY }), NOW);
    assert.equal(at.state, 'expiring');
  });

  it('to\'lov sanasining o\'zida "bugun" deb aytadi', () => {
    // `${daysToFee} kun qoldi` bu yerda "0 kun qoldi" bo'lib chiqardi.
    const r = evaluate(lifetime({ nextAnnualFeeAt: NOW }), NOW);
    assert.equal(r.blocked, false);
    assert.match(r.message, /bugun/);
  });

  it('yillik to\'lovga ham qo\'shimcha vaqt berilmaydi', () => {
    // Qiymatning o'zini qo'riqlaydi — obunanikiga o'xshab. Sozlama
    // alohida bo'lgani uchun uni alohida tekshirish kerak: obuna
    // qoidasi o'zgarsa bu sinov bundan xabar bermaydi, va aksincha.
    assert.equal(LIFETIME_FEE_GRACE_DAYS, 0);
  });

  it('to\'lov sanasi o\'tgan zahoti bloklaydi', () => {
    // Ogohlantirish oynasi YO'Q: to'lov kuni kelgan zahoti blok
    // ekrani chiqadi.
    const r = evaluate(lifetime({ nextAnnualFeeAt: NOW - 1000 }), NOW);
    assert.equal(r.state, 'lifetime_fee_due');
    assert.equal(r.blocked, true);
  });

  it('bir kun o\'tgach ham, o\'n kun o\'tgach ham bloklangan', () => {
    for (const days of [1, 3, 10]) {
      const r = evaluate(lifetime({ nextAnnualFeeAt: NOW - days * DAY }), NOW);
      assert.equal(r.blocked, true, `${days} kun o'tgach`);
    }
  });

  it('to\'lov sanasining AYNAN o\'zida hali bloklanmaydi', () => {
    // Obunadagi kabi chegara sinovi: sana kelgan lahza hali "o'tgan"
    // emas. Aks holda to'lagan kuni kirgan odam blok ekranini ko'rardi.
    const r = evaluate(lifetime({ nextAnnualFeeAt: NOW }), NOW);
    assert.equal(r.blocked, false);
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
