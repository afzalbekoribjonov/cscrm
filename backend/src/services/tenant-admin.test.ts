import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { ApiError } from '../middleware/error.js';
import type { License, Plan } from '../types/license.js';
import { auditRecord, diff, sanitizeChanges, SYSTEM_ACTOR } from './audit.js';
import { findPlan } from './license.js';
import {
  authUidsToDelete,
  buildManualLicense,
  deletionUpdates,
  dueForPurge,
  normalizeProfileInput,
  sameName,
  type DeletionTargets,
} from './tenant-admin.js';

const DAY = 86_400_000;
const NOW = Date.UTC(2026, 8, 23, 9);

const badRequest = (fn: () => unknown) =>
  assert.throws(fn, (e: unknown) => e instanceof ApiError && e.status === 400);

describe('normalizeProfileInput', () => {
  it('nom tozalanadi', () => {
    assert.deepEqual(normalizeProfileInput({ name: '  Toza   Gilam  ' }), { name: 'Toza Gilam' });
  });

  it('juda qisqa va juda uzun nom rad etiladi', () => {
    badRequest(() => normalizeProfileInput({ name: ' a ' }));
    badRequest(() => normalizeProfileInput({ name: 'x'.repeat(121) }));
  });

  it('telefon bir ko\'rinishga keltiriladi', () => {
    assert.deepEqual(normalizeProfileInput({ phone: '+998 (90) 123-45-67' }), { phone: '998901234567' });
  });

  it('chala telefon rad etiladi, bo\'sh telefon — o\'chirish', () => {
    badRequest(() => normalizeProfileInput({ phone: '90 123' }));
    assert.deepEqual(normalizeProfileInput({ phone: '  ' }), { phone: null });
    assert.deepEqual(normalizeProfileInput({ address: '' }), { address: null });
  });

  it('berilmagan maydon tegilmaydi', () => {
    assert.deepEqual(normalizeProfileInput({}), {});
  });
});

describe('buildManualLicense — obunani to\'lovsiz o\'zgartirish', () => {
  const m3 = findPlan('m3') as Plan;
  const lifetime = findPlan('lifetime') as Plan;
  const current: Omit<License, 'tenantId'> = {
    planId: 'm3',
    kind: 'subscription',
    startedAt: NOW - 30 * DAY,
    expiresAt: NOW + 5 * DAY,
    nextAnnualFeeAt: null,
    suspended: true,
    suspendedReason: 'to\'lov kechikdi',
  };

  it('muddatni uzaytirish: boshlanish sanasi va to\'xtatilganlik saqlanadi', () => {
    const next = buildManualLicense(current, m3, { planId: 'm3', expiresAt: NOW + 60 * DAY, reason: 'Sovg\'a kunlar' }, NOW);
    assert.equal(next.expiresAt, NOW + 60 * DAY);
    assert.equal(next.startedAt, current.startedAt);
    assert.equal(next.suspended, true, 'to\'xtatish — alohida amal, bu yerda o\'zgarmaydi');
    assert.equal(next.suspendedReason, 'to\'lov kechikdi');
  });

  it('bir umrlikka o\'tish: muddat yo\'q, yillik to\'lov sanasi majburiy', () => {
    const next = buildManualLicense(current, lifetime, { planId: 'lifetime', nextAnnualFeeAt: NOW + 365 * DAY, reason: 'Naqd to\'ladi' }, NOW);
    assert.equal(next.expiresAt, null);
    assert.equal(next.nextAnnualFeeAt, NOW + 365 * DAY);
    assert.equal(next.kind, 'lifetime');
    assert.equal(next.startedAt, NOW, 'reja o\'zgardi — yangi boshlanish');
    badRequest(() => buildManualLicense(current, lifetime, { planId: 'lifetime', reason: 'sabab' }, NOW));
  });

  it('muddatli rejada tugash sanasi majburiy va aqlga sig\'adigan', () => {
    badRequest(() => buildManualLicense(current, m3, { planId: 'm3', reason: 'sabab' }, NOW));
    badRequest(() => buildManualLicense(current, m3, { planId: 'm3', expiresAt: Date.UTC(2010, 0, 1), reason: 'sabab' }, NOW));
    badRequest(() => buildManualLicense(current, m3, { planId: 'm3', expiresAt: NOW + 20 * 366 * DAY, reason: 'sabab' }, NOW));
  });

  it('sababsiz o\'zgartirib bo\'lmaydi', () => {
    badRequest(() => buildManualLicense(current, m3, { planId: 'm3', expiresAt: NOW + DAY, reason: '  ' }, NOW));
  });
});

describe('sameName — o\'chirishni tasdiqlash', () => {
  it('saytdagi qoida bilan bir xil', () => {
    assert.equal(sameName('  toza   GILAM ', 'Toza Gilam'), true);
    assert.equal(sameName('G’olib', 'G\'olib'), true);
    assert.equal(sameName('Toza Gila', 'Toza Gilam'), false);
    assert.equal(sameName('', ''), false);
  });
});

describe('deletionUpdates — butunlay o\'chirish zanjiri', () => {
  const t: DeletionTargets = {
    tenantId: 'abc234',
    memberUids: ['owner1'],
    employees: [{ id: 'e1', phone: '998901112233' }, { id: 'e2' }],
    loginKeys: ['tozagilam'],
    pendingIds: ['req1'],
    pushTokens: ['tok1', 'tok2'],
  };
  const u = deletionUpdates(t);
  const paths = Object.keys(u);

  it('biznesga bog\'liq HAR BIR tugun o\'chiriladi', () => {
    for (const p of [
      'tenants/abc234',
      'tenant_directory/abc234',
      'tenant_archive/abc234',
      'employee_secrets/abc234',
      'admin_logins/tozagilam',
      'user_tenants/owner1',
      'employee_phone_index/998901112233/abc234',
      'pending_payments/req1',
      'push_tokens/tok1',
      'push_tokens/tok2',
    ]) {
      assert.ok(paths.includes(p), `yo'q: ${p}`);
      assert.equal(u[p], null);
    }
  });

  it('tushum tarixiga (payments_log) TEGILMAYDI', () => {
    assert.ok(!paths.some((p) => p.startsWith('payments_log')));
  });

  it('boshqa bizneslarning telefon indeksi o\'chmaydi — faqat shu biznes kaliti', () => {
    assert.ok(!paths.includes('employee_phone_index/998901112233'));
  });

  it('yo\'llar bir-birining ichida emas (ko\'p-yo\'lli yozuv rad etilmaydi)', () => {
    for (const a of paths) {
      for (const b of paths) {
        if (a !== b) assert.ok(!b.startsWith(`${a}/`), `${a} — ${b} ning otasi`);
      }
    }
  });

  it('Auth: ega va har bir xodim hisobi', () => {
    assert.deepEqual(authUidsToDelete(t), ['owner1', 'staff_abc234_e1', 'staff_abc234_e2']);
  });

  it('Auth: super-admin a\'zo bo\'lsa ham uning hisobi o\'chirilmaydi', () => {
    assert.deepEqual(authUidsToDelete(t, new Set(['owner1'])), ['staff_abc234_e1', 'staff_abc234_e2']);
  });
});

describe('dueForPurge — 30 kunlik tozalash', () => {
  it('faqat muddati o\'tganlar', () => {
    const due = dueForPurge(
      {
        old: { purgeAfter: NOW - 1 },
        exact: { purgeAfter: NOW },
        fresh: { purgeAfter: NOW + DAY },
        broken: {},
      },
      NOW,
    );
    assert.deepEqual(due.sort(), ['exact', 'old']);
  });

  it('arxiv bo\'sh', () => {
    assert.deepEqual(dueForPurge(null, NOW), []);
  });
});

describe('jurnal — maxfiy ma\'lumot yozilmaydi', () => {
  it('parol, PIN, token qiymatlari yashiriladi', () => {
    const out = sanitizeChanges({
      password: { from: 'eski123', to: 'yangi456' },
      pinHash: { from: 'a', to: 'b' },
      name: { from: 'A', to: 'B' },
    })!;
    assert.deepEqual(out.password, { from: '[yashirilgan]', to: '[yashirilgan]' });
    assert.deepEqual(out.pinHash, { from: '[yashirilgan]', to: '[yashirilgan]' });
    assert.deepEqual(out.name, { from: 'A', to: 'B' });
    assert.ok(!JSON.stringify(out).includes('yangi456'));
  });

  it('diff — faqat o\'zgarganlar', () => {
    assert.deepEqual(diff({ a: 1, b: 'x', c: null }, { a: 1, b: 'y', c: undefined }), {
      b: { from: 'x', to: 'y' },
    });
  });

  it('yozuv: tizim amali va uzun matn qisqartiriladi', () => {
    const r = auditRecord({ at: NOW, action: 'tenant.purge', actor: SYSTEM_ACTOR, note: 'x'.repeat(500) });
    assert.deepEqual(r.actor, { uid: 'system', email: null });
    assert.ok((r.note as string).length <= 301);
  });
});
