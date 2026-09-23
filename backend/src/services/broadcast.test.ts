import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { toPublicBroadcast } from './broadcast.js';

describe('toPublicBroadcast — ilovaga ketadigan xabar', () => {
  const stored = {
    id: 'b1',
    title: 'Yangilik',
    body: 'Matn',
    kind: 'yangilik' as const,
    createdAt: 1,
    createdBy: 'uid_super_admin',
    expiresAt: null,
  };

  it('super-admin UID\'i chiqmaydi', () => {
    const out = toPublicBroadcast(stored);
    assert.equal('createdBy' in out, false);
    assert.ok(!JSON.stringify(out).includes('uid_super_admin'));
  });

  it('keyinchalik qo\'shilgan ichki maydon ham chiqmaydi', () => {
    const out = toPublicBroadcast({ ...stored, internalNote: 'x' } as never);
    assert.deepEqual(Object.keys(out).sort(), [
      'body', 'createdAt', 'expiresAt', 'id', 'kind', 'title',
    ]);
  });

  it('kerakli maydonlar saqlanadi', () => {
    const out = toPublicBroadcast({ ...stored, expiresAt: 99 });
    assert.equal(out.title, 'Yangilik');
    assert.equal(out.expiresAt, 99);
  });
});
