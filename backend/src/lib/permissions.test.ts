import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { ASSIGNABLE_PERMISSIONS, hasPermission, sanitizePermissions } from './permissions.js';

describe('vakolatlar', () => {
  it('super-admin hammasiga ega', () => {
    assert.equal(hasPermission({ isSuperAdmin: true }, 'admins.manage'), true);
    assert.equal(hasPermission({ isSuperAdmin: true }, 'tenants.delete'), true);
  });

  it('rol faqat bergan vakolatiga ega', () => {
    const user = { isSuperAdmin: false, permissions: new Set(['tenants.read'] as const) };
    assert.equal(hasPermission(user, 'tenants.read'), true);
    assert.equal(hasPermission(user, 'tenants.delete'), false);
    assert.equal(hasPermission(undefined, 'tenants.read'), false);
  });

  it('panel xodimlarini boshqarish rolga BERILMAYDI — hatto to\'plamda bo\'lsa ham', () => {
    const user = { isSuperAdmin: false, permissions: new Set(['admins.manage'] as const) };
    assert.equal(hasPermission(user, 'admins.manage'), false);
    assert.equal(ASSIGNABLE_PERMISSIONS.includes('admins.manage'), false);
  });

  it('tozalash: noma\'lum, takror va faqat super-adminniki olib tashlanadi, tartib barqaror', () => {
    assert.deepEqual(
      sanitizePermissions(['audit.read', 'x.y', 'tenants.read', 'audit.read', 'admins.manage', 5]),
      ['tenants.read', 'audit.read'],
    );
    assert.deepEqual(sanitizePermissions('tenants.read'), []);
  });
});
