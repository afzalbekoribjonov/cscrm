import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import type { Plan } from '../types/license.js';
import { mergePrices, type PlanOverride } from './plan-prices.js';

const base: Plan[] = [
  {
    id: 'm1',
    name: '1 oylik',
    months: 1,
    price: 199000,
    kind: 'subscription',
    description: '',
    highlight: false,
  },
  {
    id: 'lifetime',
    name: 'Bir umrlik',
    months: null,
    price: 4500000,
    kind: 'lifetime',
    description: '',
    highlight: false,
    lifetimeAnnualFeeUsd: 50,
  },
];

function override(o: Partial<PlanOverride>): PlanOverride {
  return { price: 0, updatedAt: 1, updatedBy: 'admin', ...o };
}

describe('reja narxlarini birlashtirish', () => {
  it('bazadagi narx fayl qiymatining ustiga qo\'yiladi', () => {
    const out = mergePrices(base, { m1: override({ price: 250000 }) });
    assert.equal(out[0]?.price, 250000);
  });

  it('bazada yo\'q reja fayl qiymatida qoladi', () => {
    const out = mergePrices(base, {});
    assert.equal(out[0]?.price, 199000);
    assert.equal(out[1]?.price, 4500000);
  });

  it('reja TUZILISHI o\'zgarmaydi', () => {
    // Narx bilan birga oy soni ham o'zgarsa, muddat hisobi buzilardi.
    const out = mergePrices(base, { m1: override({ price: 1 }) });
    assert.equal(out[0]?.months, 1);
    assert.equal(out[0]?.kind, 'subscription');
    assert.equal(out[0]?.name, '1 oylik');
  });

  it('bir umrlik yillik to\'lovi ham o\'zgartiriladi', () => {
    const out = mergePrices(base, {
      lifetime: override({ price: 5000000, lifetimeAnnualFeeUsd: 60 }),
    });
    assert.equal(out[1]?.price, 5000000);
    assert.equal(out[1]?.lifetimeAnnualFeeUsd, 60);
  });

  it('yillik to\'lov berilmasa eskisi qoladi', () => {
    const out = mergePrices(base, { lifetime: override({ price: 5000000 }) });
    assert.equal(out[1]?.lifetimeAnnualFeeUsd, 50);
  });

  it('nolga teng narx qabul qilinadi', () => {
    // "Narx kelishiladi" holati — 0 haqiqiy qiymat, uni tashlab
    // yubormaslik kerak.
    const out = mergePrices(base, { m1: override({ price: 0 }) });
    assert.equal(out[0]?.price, 0);
  });

  it('buzuq qiymat fayl narxini almashtirmaydi', () => {
    // Bazaga qandaydir yo'l bilan yaroqsiz qiymat tushsa, narx
    // yo'qolib ketmasligi kerak.
    const out = mergePrices(base, {
      m1: override({ price: -5 }),
    });
    assert.equal(out[0]?.price, 199000);

    const broken = mergePrices(base, {
      m1: { price: 'ko\'p' as unknown as number, updatedAt: 1, updatedBy: 'x' },
    });
    assert.equal(broken[0]?.price, 199000);
  });

  it('ro\'yxat tartibi va soni saqlanadi', () => {
    const out = mergePrices(base, { m1: override({ price: 1 }) });
    assert.equal(out.length, 2);
    assert.equal(out[0]?.id, 'm1');
    assert.equal(out[1]?.id, 'lifetime');
  });
});
