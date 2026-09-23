import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { buildUserList } from './users.js';

const tenants = [
  {
    tenantId: 'abc',
    name: 'Toza Gilam',
    members: ['owner1', 'root'],
    employees: {
      e1: { firstName: 'Ali', lastName: 'Valiyev', phone: '998901112233', active: true, createdAt: 100 },
      e2: { firstName: 'Vali', lastName: '', phone: '998904445566', active: false, createdAt: 200 },
    },
  },
];

const users = new Map([
  [
    'owner1',
    {
      uid: 'owner1',
      email: 'tozagilam@cscrm.local',
      disabled: false,
      metadata: {
        creationTime: 'Mon, 01 Jun 2026 10:00:00 GMT',
        lastRefreshTime: 'Tue, 22 Sep 2026 09:00:00 GMT',
      },
    },
  ],
  [
    'staff_abc_e1',
    {
      uid: 'staff_abc_e1',
      email: undefined,
      disabled: false,
      metadata: { lastSignInTime: 'Wed, 23 Sep 2026 08:00:00 GMT' },
    },
  ],
]);

describe('buildUserList', () => {
  const list = buildUserList(tenants, users, new Set(['abc']), new Set(['root']));

  it('panel hisobi (super-admin) biznes a\'zosi bo\'lsa ham chiqmaydi', () => {
    assert.equal(list.some((u) => u.uid === 'root'), false);
    assert.equal(list.length, 3);
  });

  it('ega — login emaildan', () => {
    const o = list.find((u) => u.kind === 'owner')!;
    assert.equal(o.name, 'tozagilam');
    assert.equal(o.login, 'tozagilam');
    assert.equal(o.tenantArchived, true);
    assert.equal(o.lastActiveAt, Date.parse('Tue, 22 Sep 2026 09:00:00 GMT'));
  });

  it('xodim — ism, telefon; kirgan bo\'lsa faollik', () => {
    const e1 = list.find((u) => u.uid === 'staff_abc_e1')!;
    assert.equal(e1.name, 'Ali Valiyev');
    assert.equal(e1.phone, '998901112233');
    assert.equal(e1.hasAccount, true);
    assert.equal(e1.lastActiveAt, Date.parse('Wed, 23 Sep 2026 08:00:00 GMT'));
  });

  it('hech kirmagan va ilovada o\'chirilgan xodim', () => {
    const e2 = list.find((u) => u.uid === 'staff_abc_e2')!;
    assert.equal(e2.hasAccount, false);
    assert.equal(e2.active, false);
    assert.equal(e2.lastActiveAt, null);
    assert.equal(e2.createdAt, 200);
    assert.equal(e2.name, 'Vali');
  });

  it('maxfiy maydon yo\'q', () => {
    for (const u of list) assert.equal('pinHash' in u, false);
  });
});
