import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import type { Reference } from 'firebase-admin/database';

import { isMissingIndex, whereEquals } from './query.js';

const DATA = {
  '-b': { tenantId: 't1', n: 2 },
  '-a': { tenantId: 't1', n: 1 },
  '-c': { tenantId: 't2', n: 3 },
  '-d': { tenantId: 't1', n: 4 },
  bad: 'matn',
};

/** Indeksi yo'q bazani taqlid qiladi: so'rov yiqiladi, to'liq o'qish ishlaydi. */
function fakeRef(indexed: boolean): Reference {
  const query = {
    limitToLast: () => query,
    get: async () => {
      if (!indexed) throw new Error('Index not defined, add ".indexOn": "tenantId", for path "/x", to the rules');
      return { val: () => ({ '-a': DATA['-a'] }) };
    },
  };
  return {
    key: 'x',
    orderByChild: () => ({ equalTo: () => query }),
    get: async () => ({ val: () => DATA }),
  } as unknown as Reference;
}

describe('whereEquals', () => {
  it('indeks bor — bazaning javobi', async () => {
    assert.deepEqual(await whereEquals(fakeRef(true), 'tenantId', 't1'), { '-a': DATA['-a'] });
  });

  it('indeks yo\'q — to\'liq o\'qib saralaydi (kalit tartibida)', async () => {
    const r = await whereEquals(fakeRef(false), 'tenantId', 't1');
    assert.deepEqual(Object.keys(r), ['-a', '-b', '-d']);
  });

  it('indeks yo\'q + limitToLast — oxirgi N ta', async () => {
    const r = await whereEquals(fakeRef(false), 'tenantId', 't1', 2);
    assert.deepEqual(Object.keys(r), ['-b', '-d']);
  });

  it('boshqa xato yutilmaydi', async () => {
    const ref = {
      key: 'x',
      orderByChild: () => ({ equalTo: () => ({ get: async () => { throw new Error('Permission denied'); } }) }),
    } as unknown as Reference;
    await assert.rejects(whereEquals(ref, 'tenantId', 't1'), /Permission denied/);
  });

  it('isMissingIndex', () => {
    assert.equal(isMissingIndex(new Error('Index not defined, add ".indexOn"')), true);
    assert.equal(isMissingIndex(new Error('boshqa')), false);
    assert.equal(isMissingIndex('Index not defined'), false);
  });
});
