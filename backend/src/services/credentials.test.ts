import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { isVerifiedOwner } from './credentials.js';

const TENANT = 't_abc';
const OWNER = 'uid_owner';
const ADMIN = 'uid_super_admin';
const admins = new Set([ADMIN]);

const base = {
  tenantId: TENANT,
  uid: OWNER,
  claims: { tenantId: TENANT, role: 'owner' } as Record<string, unknown>,
  userTenant: TENANT,
  isMember: true,
  superAdminUids: admins,
};

describe('isVerifiedOwner — parolni tiklashdan oldingi tekshiruv', () => {
  it('haqiqiy ega o\'tadi', () => {
    assert.equal(isVerifiedOwner(base), true);
  });

  it('HUJUM: ownerUid ga super-admin yozilgan — rad etiladi', () => {
    // Ega o'z profiliga super-admin UID'ini yozgan. Super-admin
    // hisobida tenant da'volari yo'q, lekin tekshiruv baribir unga
    // yetib bormasdan to'xtashi kerak.
    assert.equal(
      isVerifiedOwner({
        ...base,
        uid: ADMIN,
        claims: undefined,
        userTenant: null,
        isMember: false,
      }),
      false,
    );
  });

  it('super-admin hatto indekslar mos bo\'lsa ham ega bo\'la olmaydi', () => {
    assert.equal(isVerifiedOwner({ ...base, uid: ADMIN }), false);
  });

  it('HUJUM: boshqa biznesning egasi — rad etiladi', () => {
    // Nomzodning da'volari va indeksi BOSHQA biznesni ko'rsatadi.
    assert.equal(
      isVerifiedOwner({
        ...base,
        uid: 'uid_victim',
        claims: { tenantId: 't_victim', role: 'owner' },
        userTenant: 't_victim',
        isMember: false,
      }),
      false,
    );
  });

  it('xodim da\'vosi ega o\'rnida o\'tmaydi', () => {
    assert.equal(
      isVerifiedOwner({
        ...base,
        claims: { tenantId: TENANT, role: 'staff' },
        userTenant: null,
        isMember: false,
      }),
      false,
    );
  });

  it('da\'vosi hali yo\'q eski hisob — indekslar orqali o\'tadi', () => {
    assert.equal(isVerifiedOwner({ ...base, claims: undefined }), true);
  });

  it('indeksning bittasi yetmaydi — ikkalasi ham kerak', () => {
    assert.equal(
      isVerifiedOwner({ ...base, claims: undefined, isMember: false }),
      false,
    );
    assert.equal(
      isVerifiedOwner({ ...base, claims: undefined, userTenant: 't_other' }),
      false,
    );
  });

  it('bo\'sh UID rad etiladi', () => {
    assert.equal(isVerifiedOwner({ ...base, uid: '' }), false);
  });
});
