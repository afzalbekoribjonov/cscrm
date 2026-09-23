import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import {
  CARD_LABEL,
  CASH_LABEL,
  buildCabinetSummary,
  cabinetPeriod,
  expensesForRange,
  incomeForRange,
  paidAtDelivery,
} from './cabinet.js';

const HOUR = 3_600_000;
const DAY = 24 * HOUR;
/** Toshkent vaqti bo'yicha sana → UTC ms. */
const tash = (y: number, m: number, d: number, h = 0) => Date.UTC(y, m - 1, d, h) - 5 * HOUR;
const NOW = tash(2026, 9, 23, 14);

describe('cabinetPeriod — Toshkent kuni', () => {
  it('7 kun: bugun bilan birga, oldingi 7 kun bilan taqqoslanadi', () => {
    const p = cabinetPeriod('7d', NOW);
    assert.equal(p.start, tash(2026, 9, 17));
    assert.equal(p.end, tash(2026, 9, 24) - 1);
    assert.equal(p.prevStart, tash(2026, 9, 10));
    assert.equal(p.prevEnd, tash(2026, 9, 17) - 1);
    assert.equal(p.days, 7);
  });

  it('bugun — UTC 19:30 allaqachon Toshkentda ertangi kun', () => {
    const p = cabinetPeriod('today', Date.UTC(2026, 8, 22, 19, 30));
    assert.equal(p.start, tash(2026, 9, 23));
  });

  it('oy: 1-sanadan bugungacha, o\'tgan oyning xuddi shu kunlari bilan', () => {
    const p = cabinetPeriod('month', NOW);
    assert.equal(p.start, tash(2026, 9, 1));
    assert.equal(p.days, 23);
    assert.equal(p.prevStart, tash(2026, 8, 1));
    assert.equal(p.prevEnd, tash(2026, 8, 24) - 1);
  });

  it('oy: o\'tgan oy qisqa bo\'lsa, uning oxiridan oshmaydi', () => {
    const p = cabinetPeriod('month', tash(2026, 3, 31, 10));
    assert.equal(p.prevEnd, tash(2026, 3, 1) - 1); // fevralda 28 kun
  });
});

describe('incomeForRange — ilovadagi qoida bilan bir xil', () => {
  const start = tash(2026, 9, 1);
  const end = tash(2026, 10, 1) - 1;

  it('yetkazishda olingan pul yetkazilgan kunga, usuli bo\'yicha', () => {
    const r = incomeForRange(
      [
        { id: '1', deliveredAt: tash(2026, 9, 5), paymentMethod: CASH_LABEL, deliveryPaidAmount: 100_000 },
        { id: '2', deliveredAt: tash(2026, 9, 6), paymentMethod: CARD_LABEL, paymentAmount: 50_000 },
        { id: '3', deliveredAt: tash(2026, 9, 7), paymentMethod: 'Click', deliveryPaidAmount: 20_000 },
        { id: '4', deliveredAt: tash(2026, 8, 31, 23), paymentMethod: CASH_LABEL, deliveryPaidAmount: 999 },
        { id: '5', createdAt: tash(2026, 9, 7), paymentMethod: CASH_LABEL, deliveryPaidAmount: 777 },
      ],
      [],
      start,
      end,
    );
    assert.deepEqual(r, { cash: 100_000, card: 50_000, other: 20_000, debtPayments: 0, total: 170_000 });
  });

  it('keyin to\'langan qarz — to\'langan kunga va o\'z usuli bilan (jamlanma paymentAmount emas)', () => {
    const r = incomeForRange(
      [{ id: '1', deliveredAt: tash(2026, 8, 20), paymentMethod: CARD_LABEL, paymentAmount: 150_000, deliveryPaidAmount: 100_000 }],
      [
        { type: 'debt_settled', at: tash(2026, 9, 3), amount: 50_000, method: CASH_LABEL },
        { type: 'status_changed', at: tash(2026, 9, 3), amount: 1 },
        { type: 'debt_settled', at: tash(2026, 9, 4), amount: 0, method: CASH_LABEL },
      ],
      start,
      end,
    );
    assert.deepEqual(r, { cash: 50_000, card: 0, other: 0, debtPayments: 50_000, total: 50_000 });
  });

  it('eski yozuv: deliveryPaidAmount yo\'q — paymentAmount olinadi', () => {
    assert.equal(paidAtDelivery({ id: 'x', paymentAmount: 30 }), 30);
    assert.equal(paidAtDelivery({ id: 'x' }), 0);
  });
});

describe('chiqimlar', () => {
  it('sarflangan kun bo\'yicha; eski yozuvda — yozilgan kun', () => {
    const total = expensesForRange(
      [
        { amount: 10, spentAt: tash(2026, 9, 2) },
        { amount: 5, createdAt: tash(2026, 9, 3) },
        { amount: 7, spentAt: tash(2026, 8, 30) },
        { amount: -3, spentAt: tash(2026, 9, 2) },
      ],
      tash(2026, 9, 1),
      tash(2026, 10, 1) - 1,
    );
    assert.equal(total, 15);
  });
});

describe('buildCabinetSummary', () => {
  const s = buildCabinetSummary({
    range: '7d',
    now: NOW,
    ordersInPeriod: [
      { id: '1', createdAt: tash(2026, 9, 18), deliveredAt: tash(2026, 9, 20), paymentMethod: CASH_LABEL, deliveryPaidAmount: 100 },
      // Ikkala so'rovda ham chiqqan — bir marta sanaladi.
      { id: '1', createdAt: tash(2026, 9, 18), deliveredAt: tash(2026, 9, 20), paymentMethod: CASH_LABEL, deliveryPaidAmount: 100 },
      { id: '2', createdAt: tash(2026, 9, 12) },
    ],
    activeOrders: [
      { id: '3', createdAt: tash(2026, 9, 23, 9), status: 'yuvishda', active: true },
      { id: '4', createdAt: tash(2026, 9, 1), status: 'yetgazishga_tayyor', active: true },
    ],
    debtors: [{ id: '9', debtAmount: 40 }, { id: '8', debtAmount: 0 }],
    history: [{ type: 'debt_settled', at: tash(2026, 9, 14), amount: 30, method: CARD_LABEL }],
    expenses: [{ amount: 25, spentAt: tash(2026, 9, 21) }],
  });

  it('tushum, chiqim, foyda va taqqoslash', () => {
    assert.equal(s.income.total, 100);
    assert.equal(s.previousIncome, 30);
    assert.equal(s.expenses, 25);
    assert.equal(s.profit, 75);
  });

  it('buyurtmalar: qabul, topshirish, ishda, tayyor', () => {
    assert.deepEqual(s.orders, { created: 2, previousCreated: 1, delivered: 1, active: 2, readyToDeliver: 1 });
  });

  it('qarzdorlar — faqat haqiqiy qarz', () => {
    assert.deepEqual(s.debt, { count: 1, total: 40 });
  });

  it('kunlik qator: 7 kun, tushum topshirilgan kunda', () => {
    assert.equal(s.series.starts.length, 7);
    assert.equal(s.series.income[3], 100); // 20-sentabr
    assert.equal(s.series.income.reduce((a, b) => a + b, 0), 100);
    assert.equal(s.series.created[6], 1); // bugun qabul qilingan
    assert.equal(s.series.starts[0], tash(2026, 9, 17));
  });
});
