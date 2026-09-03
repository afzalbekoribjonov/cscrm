import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { resolveUpdates } from './payment-request.js';

describe('to\'lov so\'rovini yopish', () => {
  const base = {
    tenantId: 'biz1',
    requestId: 'req1',
    byUid: 'admin1',
    now: 1_700_000_000_000,
  };

  it('tasdiqlanganda navbatdan olib tashlanadi', () => {
    const u = resolveUpdates({ ...base, status: 'approved' });

    assert.equal(
      u['tenants/biz1/payment_requests/req1/status'],
      'approved',
    );
    assert.equal(
      u['pending_payments/req1'],
      null,
      'navbatdagi yozuv o\'chirilishi shart, aks holda navbat cheksiz o\'sadi',
    );
  });

  it('tasdiqlashda rad etish sababi qolmaydi', () => {
    const u = resolveUpdates({ ...base, status: 'approved' });

    assert.equal(
      u['tenants/biz1/payment_requests/req1/rejectReason'],
      null,
      'avval rad etilgan so\'rov keyin tasdiqlansa, eski sabab ko\'rinib qolmasligi kerak',
    );
  });

  it('rad etilganda sabab saqlanadi', () => {
    const u = resolveUpdates({
      ...base,
      status: 'rejected',
      rejectReason: 'To\'lov kelmadi',
    });

    assert.equal(u['tenants/biz1/payment_requests/req1/status'], 'rejected');
    assert.equal(
      u['tenants/biz1/payment_requests/req1/rejectReason'],
      'To\'lov kelmadi',
    );
    assert.equal(u['pending_payments/req1'], null);
  });

  it('kim va qachon yopgani yoziladi', () => {
    const u = resolveUpdates({ ...base, status: 'approved' });

    assert.equal(u['tenants/biz1/payment_requests/req1/resolvedBy'], 'admin1');
    assert.equal(u['tenants/biz1/payment_requests/req1/resolvedAt'], base.now);
  });
});
