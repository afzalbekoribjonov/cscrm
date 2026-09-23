import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { lastActiveOf, summarizeActivity, tenantOfUser } from './activity.js';
import {
  bucketIndex,
  buildAttention,
  buildBuckets,
  buildOverview,
  localDayStart,
  subscriptionGroup,
  type PaymentInput,
  type TenantInput,
} from './overview.js';

const DAY = 86_400_000;
const HOUR = 3_600_000;

/** Toshkent vaqti bo'yicha sana → UTC ms. */
const tash = (y: number, m: number, d: number, h = 0, min = 0) =>
  Date.UTC(y, m - 1, d, h, min) - 5 * HOUR;

// 2026-09-23 (chorshanba), Toshkentda 14:00.
const NOW = tash(2026, 9, 23, 14);

describe('Toshkent kuni', () => {
  it('kechki 19:30 UTC — Toshkentda ERTANGI kun', () => {
    // 22-sentabr 19:30 UTC = 23-sentabr 00:30 Toshkent.
    const t = Date.UTC(2026, 8, 22, 19, 30);
    assert.equal(localDayStart(t), tash(2026, 9, 23));
  });

  it('Toshkentda 23:59 — hali o\'sha kun', () => {
    const t = tash(2026, 9, 23, 23, 59);
    assert.equal(localDayStart(t), tash(2026, 9, 23));
  });
});

describe('buildBuckets', () => {
  it('30 kun: oxirgisi bugun, oldingi davr aynan 30 kun oldin', () => {
    const { starts, prevStart } = buildBuckets('30d', NOW);
    assert.equal(starts.length, 30);
    assert.equal(starts.at(-1), tash(2026, 9, 23));
    assert.equal(starts[0], tash(2026, 8, 25));
    assert.equal(starts[0]! - prevStart, 30 * DAY);
  });

  it('90 kun: 13 hafta, har biri DUSHANBADAN', () => {
    const { starts } = buildBuckets('90d', NOW);
    assert.equal(starts.length, 13);
    for (const s of starts) {
      assert.equal(new Date(s + 5 * HOUR).getUTCDay(), 1, 'dushanba');
    }
    // 23-sentabr chorshanba — joriy hafta 21-sentabr dushanbadan.
    assert.equal(starts.at(-1), tash(2026, 9, 21));
  });

  it('12 oy: har biri oyning 1-kuni, oxirgisi joriy oy', () => {
    const { starts, prevStart } = buildBuckets('12m', NOW);
    assert.equal(starts.length, 12);
    assert.equal(starts.at(-1), tash(2026, 9, 1));
    assert.equal(starts[0], tash(2025, 10, 1));
    assert.equal(prevStart, tash(2024, 10, 1));
  });
});

describe('bucketIndex', () => {
  const { starts } = buildBuckets('7d', NOW);

  it('davrdan oldin va kelajakda — hech qaysi ustunga tushmaydi', () => {
    assert.equal(bucketIndex(starts, starts[0]! - 1, NOW), -1);
    assert.equal(bucketIndex(starts, NOW + 1, NOW), -1);
  });

  it('chegara aynan ustun boshida', () => {
    assert.equal(bucketIndex(starts, starts[3]!, NOW), 3);
    assert.equal(bucketIndex(starts, starts[3]! - 1, NOW), 2);
  });

  it('bugungi to\'lov oxirgi ustunda', () => {
    assert.equal(bucketIndex(starts, NOW - HOUR, NOW), 6);
  });
});

const tenant = (over: Partial<TenantInput> & { tenantId: string }): TenantInput => ({
  name: over.tenantId,
  createdAt: tash(2026, 1, 1),
  state: 'active',
  kind: 'subscription',
  blocked: false,
  daysLeft: 60,
  ...over,
});

describe('subscriptionGroup — har biznes aynan bitta guruhda', () => {
  it('guruhlar', () => {
    assert.equal(subscriptionGroup({ blocked: true, state: 'expired', kind: 'subscription' }), 'blocked');
    assert.equal(subscriptionGroup({ blocked: true, state: 'suspended', kind: 'trial' }), 'blocked');
    assert.equal(subscriptionGroup({ blocked: false, state: 'expiring', kind: 'trial' }), 'expiring');
    assert.equal(subscriptionGroup({ blocked: false, state: 'active', kind: 'trial' }), 'trial');
    assert.equal(subscriptionGroup({ blocked: false, state: 'active', kind: 'lifetime' }), 'active');
  });
});

describe('buildAttention — kim bilan bugun ishlash kerak', () => {
  const tenants = [
    tenant({ tenantId: 'exp5', state: 'expiring', daysLeft: 5 }),
    tenant({ tenantId: 'exp1', state: 'expiring', daysLeft: 1 }),
    tenant({ tenantId: 'blockedOld', state: 'expired', blocked: true, daysLeft: -40 }),
    tenant({ tenantId: 'blockedNew', state: 'expired', blocked: true, daysLeft: -1 }),
    tenant({ tenantId: 'suspended', state: 'suspended', blocked: true, daysLeft: null }),
    tenant({ tenantId: 'paid', state: 'expired', blocked: true, daysLeft: -3 }),
    tenant({ tenantId: 'ok' }),
  ];
  const pending = [
    { id: 'r2', tenantId: 'paid', tenantName: 'x', amount: 199_000, createdAt: 2 },
  ];

  it('tartib: to\'lov so\'rovi → yaqinda bloklangan → muddati eng kam qolgan', () => {
    const list = buildAttention(tenants, pending, 10);
    assert.deepEqual(
      list.map((i) => `${i.reason}:${i.tenantId}`),
      [
        'pending_payment:paid',
        'blocked:blockedNew',
        'blocked:blockedOld',
        'blocked:suspended',
        'expiring:exp1',
        'expiring:exp5',
      ],
    );
  });

  it('bir biznes faqat bir marta — eng muhim sababi bilan', () => {
    const list = buildAttention(tenants, pending, 10);
    assert.equal(list.filter((i) => i.tenantId === 'paid').length, 1);
  });

  it('muammosiz biznes ro\'yxatga tushmaydi', () => {
    assert.ok(!buildAttention(tenants, pending, 10).some((i) => i.tenantId === 'ok'));
  });

  it('chegara', () => {
    assert.equal(buildAttention(tenants, pending, 3).length, 3);
  });
});

describe('buildOverview', () => {
  const pay = (id: string, at: number, amount: number): PaymentInput => ({
    id,
    tenantId: 't',
    tenantName: 'T',
    planName: '1 oylik',
    amount,
    at,
  });

  const overview = buildOverview({
    range: '7d',
    now: NOW,
    tenants: [
      tenant({ tenantId: 'new1', createdAt: NOW - 2 * HOUR }),
      tenant({ tenantId: 'new2', createdAt: NOW - 3 * DAY }),
      tenant({ tenantId: 'prev', createdAt: NOW - 10 * DAY }),
      tenant({ tenantId: 'old', createdAt: NOW - 400 * DAY, state: 'expired', blocked: true }),
    ],
    payments: [
      pay('a', NOW - HOUR, 199_000),
      pay('b', NOW - 2 * DAY, 537_000),
      pay('c', NOW - 9 * DAY, 199_000), // oldingi davr
      pay('d', NOW - 20 * DAY, 1_000_000), // hech qaysi davrga kirmaydi
    ],
    recentPayments: [pay('a', NOW - HOUR, 199_000), pay('b', NOW - 2 * DAY, 537_000)],
    pending: [],
    activity: null,
  });

  it('tushum: joriy va oldingi davr alohida', () => {
    assert.equal(overview.revenue.current, 736_000);
    assert.equal(overview.revenue.previous, 199_000);
    assert.equal(overview.revenue.count, 2);
  });

  it('ustunlar yig\'indisi joriy davr bilan teng', () => {
    assert.equal(overview.series.revenue.reduce((s, v) => s + v, 0), overview.revenue.current);
    assert.equal(overview.series.revenue.at(-1), 199_000);
  });

  it('ro\'yxatdan o\'tishlar', () => {
    assert.deepEqual(overview.registrations, { current: 2, previous: 1 });
    assert.equal(overview.series.registrations.at(-1), 1);
  });

  it('faol obunalar: muddati yaqin pullik obuna ham FAOL hisoblanadi', () => {
    const o = buildOverview({
      range: '7d',
      now: NOW,
      tenants: [
        tenant({ tenantId: 'a' }),
        tenant({ tenantId: 'b', state: 'expiring', daysLeft: 3 }),
        tenant({ tenantId: 'c', kind: 'trial', state: 'expiring', daysLeft: 1 }),
        tenant({ tenantId: 'd', blocked: true, state: 'expired' }),
      ],
      payments: [],
      recentPayments: [],
      pending: [],
      activity: null,
    });
    assert.equal(o.tenants.paid, 2);
    assert.equal(o.tenants.onTrial, 1);
    // Chart guruhlari esa kesishmaydi.
    assert.equal(o.tenants.expiring, 2);
  });

  it('guruhlar yig\'indisi jami bizneslar soniga teng', () => {
    const t = overview.tenants;
    assert.equal(t.active + t.trial + t.expiring + t.blocked, t.total);
    assert.equal(t.blocked, 1);
  });

  it('faollik aniqlanmasa — null (soxta 0 emas)', () => {
    assert.equal(overview.activity, null);
    assert.equal(overview.recentTenants[0]?.lastActiveAt, null);
  });

  it('eng yangi biznes birinchi', () => {
    assert.equal(overview.recentTenants[0]?.tenantId, 'new1');
  });
});

describe('faollik', () => {
  const admins = new Set(['admin1']);

  it('ega — da\'vosidan, xodim — UID\'idan', () => {
    assert.equal(tenantOfUser('uidA', { tenantId: 'abc234', role: 'owner' }, admins), 'abc234');
    assert.equal(tenantOfUser('staff_abc234_emp9xyz', undefined, admins), 'abc234');
  });

  it('super-admin va bog\'lanmagan hisob hisobga olinmaydi', () => {
    assert.equal(tenantOfUser('admin1', { tenantId: 'abc234' }, admins), null);
    assert.equal(tenantOfUser('random', undefined, admins), null);
  });

  it('oxirgi faollik — kirish va token yangilanishidan kechrog\'i', () => {
    assert.equal(
      lastActiveOf({ lastSignInTime: 'Mon, 01 Sep 2026 10:00:00 GMT', lastRefreshTime: 'Tue, 22 Sep 2026 08:00:00 GMT' }),
      Date.parse('Tue, 22 Sep 2026 08:00:00 GMT'),
    );
    assert.equal(lastActiveOf({}), null);
  });

  it('7 kunlik oyna: foydalanuvchi va bizneslar', () => {
    const s = summarizeActivity(
      [
        { uid: 'o1', tenantId: 't1', lastActiveAt: NOW - DAY },
        { uid: 's1', tenantId: 't1', lastActiveAt: NOW - 2 * DAY },
        { uid: 'o2', tenantId: 't2', lastActiveAt: NOW - 30 * DAY },
        { uid: 'o3', tenantId: 't3', lastActiveAt: null },
      ],
      NOW,
      7 * DAY,
    );
    assert.equal(s.totalUsers, 4);
    assert.equal(s.activeUsers, 2);
    assert.equal(s.activeTenants, 1);
    assert.equal(s.lastActiveByTenant.get('t1'), NOW - DAY);
    assert.equal(s.lastActiveByTenant.get('t2'), NOW - 30 * DAY);
    assert.equal(s.lastActiveByTenant.has('t3'), false);
  });
});
