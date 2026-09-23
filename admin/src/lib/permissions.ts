/**
 * Panel vakolatlari — backend/src/lib/permissions.ts bilan AYNAN bir xil.
 *
 * Panel ularga qarab menyu va tugmalarni ko'rsatadi yoki yashiradi.
 * Bu QULAYLIK: haqiqiy tekshiruv serverda, har bir so'rovda.
 */
export type Permission =
  | 'tenants.read'
  | 'tenants.edit'
  | 'tenants.suspend'
  | 'tenants.archive'
  | 'tenants.delete'
  | 'subscriptions.manage'
  | 'payments.manage'
  | 'credentials.manage'
  | 'users.read'
  | 'users.manage'
  | 'broadcasts.manage'
  | 'plans.manage'
  | 'settings.manage'
  | 'audit.read'
  | 'admins.manage';

/** Nomlar — backenddagi `PERMISSIONS` bilan bir xil matn. */
export const PERMISSION_LABELS: Record<Permission, string> = {
  'tenants.read': 'Bizneslarni ko\'rish',
  'tenants.edit': 'Biznes ma\'lumotini tahrirlash',
  'tenants.suspend': 'Hisobni to\'xtatish va qayta ochish',
  'tenants.archive': 'Arxivlash va arxivdan qaytarish',
  'tenants.delete': 'Biznesni butunlay o\'chirish',
  'subscriptions.manage': 'Obunani to\'lovsiz o\'zgartirish',
  'payments.manage': 'To\'lovni tasdiqlash va rad etish',
  'credentials.manage': 'Egasining login va parolini almashtirish',
  'users.read': 'Foydalanuvchilarni ko\'rish',
  'users.manage': 'Foydalanuvchini barcha qurilmalardan chiqarish',
  'broadcasts.manage': 'Xabarlar yuborish va o\'chirish',
  'plans.manage': 'Tarif narxlarini o\'zgartirish',
  'settings.manage': 'Sayt sozlamalari',
  'audit.read': 'Amallar jurnalini ko\'rish',
  'admins.manage': 'Panel xodimlari va rollar',
};

/** Rol tahririda vakolatlar shu guruhlarda ko'rsatiladi. */
export const PERMISSION_GROUPS: { title: string; items: Permission[] }[] = [
  {
    title: 'Bizneslar',
    items: ['tenants.read', 'tenants.edit', 'tenants.suspend', 'tenants.archive', 'tenants.delete'],
  },
  { title: 'To\'lov va obuna', items: ['payments.manage', 'subscriptions.manage'] },
  { title: 'Foydalanuvchilar', items: ['users.read', 'users.manage', 'credentials.manage'] },
  { title: 'Kontent va sozlamalar', items: ['broadcasts.manage', 'plans.manage', 'settings.manage'] },
  { title: 'Nazorat', items: ['audit.read'] },
];

/**
 * Bir vakolat boshqasisiz ma'nosiz bo'lsa — belgilanganda o'zi qo'shiladi.
 * Masalan, biznesni tahrirlash uchun avval uni ko'ra olish kerak.
 */
export const REQUIRES: Partial<Record<Permission, Permission[]>> = {
  'tenants.edit': ['tenants.read'],
  'tenants.suspend': ['tenants.read'],
  'tenants.archive': ['tenants.read'],
  'tenants.delete': ['tenants.read', 'tenants.archive'],
  'subscriptions.manage': ['tenants.read'],
  'payments.manage': ['tenants.read'],
  'credentials.manage': ['tenants.read'],
  'users.manage': ['users.read'],
};

/** Belgilash/olib tashlashdan keyingi to'plam — bog'liqliklar hisobga olingan. */
export function togglePermission(current: readonly Permission[], p: Permission, on: boolean): Permission[] {
  const next = new Set(current);
  if (on) {
    next.add(p);
    for (const dep of REQUIRES[p] ?? []) next.add(dep);
  } else {
    next.delete(p);
    // Shu vakolatga tayangan boshqalari ham olinadi.
    for (const [q, deps] of Object.entries(REQUIRES) as [Permission, Permission[]][]) {
      if (deps.includes(p)) next.delete(q);
    }
  }
  return [...next];
}
