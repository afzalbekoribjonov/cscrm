import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { ApiError } from '../middleware/error.js';
import {
  accessFrom,
  normalizeRoleInput,
  normalizeStaffEmail,
  permissionsFromRecord,
  permissionsToRecord,
  temporaryPassword,
} from './admin-access.js';

const SUPER = new Set(['root']);
const member = { email: 'a@b.uz', roleId: 'r1', addedAt: 1, addedBy: 'root' };

const rejects = (fn: () => unknown) =>
  assert.throws(fn, (e: unknown) => e instanceof ApiError && e.status === 400);

describe('accessFrom — kim panelga kiradi', () => {
  it('super-admin — hamma vakolat', () => {
    const a = accessFrom('root', SUPER, null, null);
    assert.equal(a?.kind, 'super');
    assert.ok(a?.permissions.includes('admins.manage'));
  });

  it('a\'zo emas — kira olmaydi', () => {
    assert.equal(accessFrom('x', SUPER, null, null), null);
  });

  it('rol vakolatlari', () => {
    const a = accessFrom('u1', SUPER, member, {
      name: 'Operator',
      permissions: ['payments.manage', 'tenants.read'],
    });
    assert.deepEqual(a, {
      kind: 'member',
      role: { id: 'r1', name: 'Operator' },
      permissions: ['tenants.read', 'payments.manage'],
    });
  });

  it('rol o\'chirilgan — kiradi, lekin vakolatsiz (hamma narsa ochilib qolmaydi)', () => {
    assert.deepEqual(accessFrom('u1', SUPER, member, null), { kind: 'member', role: null, permissions: [] });
  });

  it('bazada qo\'lda yozilgan super vakolat rolga o\'tmaydi', () => {
    const a = accessFrom('u1', SUPER, member, {
      name: 'X',
      permissions: ['admins.manage', 'audit.read'],
    });
    assert.deepEqual(a?.permissions, ['audit.read']);
  });
});

describe('rol ma\'lumoti', () => {
  it('ro\'yxat sifatida saqlanadi — nuqtali nom bazada kalit bo\'la olmaydi', () => {
    assert.deepEqual(permissionsToRecord(['tenants.read', 'audit.read']), ['tenants.read', 'audit.read']);
    for (const p of permissionsToRecord(['tenants.read'])) assert.equal(typeof p, 'string');
  });

  it('bazadan o\'qish: massiv ham, {0: …} ham; tartib barqaror', () => {
    assert.deepEqual(permissionsFromRecord(['audit.read', 'tenants.read', 'x']), ['tenants.read', 'audit.read']);
    assert.deepEqual(permissionsFromRecord({ 0: 'audit.read', 2: 'tenants.read' }), ['tenants.read', 'audit.read']);
    assert.deepEqual(permissionsFromRecord(null), []);
  });

  it('nom tozalanadi va tekshiriladi', () => {
    assert.equal(normalizeRoleInput({ name: '  Yordam   xizmati ' }).name, 'Yordam xizmati');
    rejects(() => normalizeRoleInput({ name: 'A' }));
    rejects(() => normalizeRoleInput({ name: 'x'.repeat(61) }));
  });

  it('bo\'sh tavsif — o\'chiriladi', () => {
    assert.equal(normalizeRoleInput({ description: '  ' }).description, null);
    assert.equal(normalizeRoleInput({ description: null }).description, null);
  });
});

describe('panel xodimi emaili', () => {
  it('kichik harfga keltiriladi', () => {
    assert.equal(normalizeStaffEmail('  Ali@Example.UZ '), 'ali@example.uz');
  });

  it('noto\'g\'ri email va ilova logini rad etiladi', () => {
    rejects(() => normalizeStaffEmail('ali'));
    rejects(() => normalizeStaffEmail('ali@x'));
    rejects(() => normalizeStaffEmail('dokon@cscrm.local'));
  });
});

describe('vaqtinchalik parol', () => {
  it('uzunligi to\'g\'ri, adashtiradigan belgilar yo\'q', () => {
    for (let i = 0; i < 50; i++) {
      const p = temporaryPassword();
      assert.equal(p.length, 12);
      assert.doesNotMatch(p, /[0O1lI]/);
    }
  });
});
