import { describe, expect, it } from 'vitest';

import { canFrom } from './auth';
import { PERMISSION_GROUPS, PERMISSION_LABELS, togglePermission } from './permissions';

describe('togglePermission — bog\'liq vakolatlar', () => {
  it('belgilanganda kerakli vakolat o\'zi qo\'shiladi', () => {
    expect(togglePermission([], 'tenants.delete', true).sort()).toEqual(
      ['tenants.archive', 'tenants.delete', 'tenants.read'].sort(),
    );
  });

  it('asosiy vakolat olinsa, unga tayanganlar ham olinadi', () => {
    const all = togglePermission(togglePermission([], 'tenants.edit', true), 'payments.manage', true);
    expect(togglePermission(all, 'tenants.read', false)).toEqual([]);
  });

  it('bog\'liq bo\'lmagan vakolatga tegilmaydi', () => {
    const list = togglePermission(['audit.read', 'users.read', 'users.manage'], 'users.read', false);
    expect(list).toEqual(['audit.read']);
  });
});

describe('guruhlar', () => {
  it('panel xodimlarini boshqarish rolga berilmaydi — ro\'yxatda yo\'q', () => {
    expect(PERMISSION_GROUPS.flatMap((g) => g.items)).not.toContain('admins.manage');
  });

  it('har bir vakolatning nomi bor', () => {
    for (const p of PERMISSION_GROUPS.flatMap((g) => g.items)) expect(PERMISSION_LABELS[p]).toBeTruthy();
  });
});

describe('canFrom', () => {
  it('kirmagan — hech narsa', () => {
    expect(canFrom(null)('tenants.read')).toBe(false);
  });

  it('super-admin — hammasi', () => {
    expect(canFrom({ isSuperAdmin: true, role: null, permissions: [] })('admins.manage')).toBe(true);
  });

  it('rol — faqat berilgani', () => {
    const can = canFrom({ isSuperAdmin: false, role: { id: 'r', name: 'Op' }, permissions: ['tenants.read'] });
    expect(can('tenants.read')).toBe(true);
    expect(can('tenants.delete')).toBe(false);
  });
});
