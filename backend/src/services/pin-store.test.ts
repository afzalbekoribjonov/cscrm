import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { pickPinHash, pinHashUpdates, secretPath } from './pin-store.js';

/**
 * RTDB ko'p-yo'lli yozuvda bir yo'l boshqasining OTASI bo'lsa, butun
 * yozuv rad etiladi. Yangilanishlar boshqa yo'llar bilan birga
 * yuborilgani uchun bu shart sinovda tekshiriladi.
 */
function assertNoOverlap(paths: string[]) {
  for (const a of paths) {
    for (const b of paths) {
      if (a !== b) {
        assert.ok(!b.startsWith(`${a}/`), `${a} — ${b} ning otasi`);
      }
    }
  }
}

describe('pickPinHash — qaysi hash amal qiladi', () => {
  it('yangi joydagi hash ustun', () => {
    assert.deepEqual(pickPinHash({ pinHash: 'new' }, 'old'), {
      hash: 'new',
      legacy: false,
    });
  });

  it('yangi joyda bo\'lmasa — eski hash, ko\'chirish kerak deb belgilanadi', () => {
    assert.deepEqual(pickPinHash(null, 'old'), { hash: 'old', legacy: true });
  });

  it('ikkalasi ham yo\'q — hash yo\'q', () => {
    assert.deepEqual(pickPinHash(null, undefined), {
      hash: undefined,
      legacy: false,
    });
  });

  it('bo\'sh yoki noto\'g\'ri turdagi qiymat hash hisoblanmaydi', () => {
    assert.deepEqual(pickPinHash({ pinHash: '' }, 42), {
      hash: undefined,
      legacy: false,
    });
  });
});

describe('pinHashUpdates — ko\'chirish yozuvi', () => {
  const u = pinHashUpdates('t1', 'e1', 'hash');

  it('hash YOPIQ tugunga yoziladi', () => {
    assert.equal(u[`${secretPath('t1', 'e1')}/pinHash`], 'hash');
  });

  it('xodim yozuvidagi eski hash o\'chiriladi', () => {
    assert.equal(u['tenants/t1/employees/e1/pinHash'], null);
  });

  it('boshqa maydonlar bilan birga yuborilganda yo\'llar to\'qnashmaydi', () => {
    assertNoOverlap([
      ...Object.keys(u),
      'tenants/t1/employees/e1/failedAttempts',
      'tenants/t1/employees/e1/lockedUntil',
    ]);
  });
});
