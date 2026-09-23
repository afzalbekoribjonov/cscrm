/**
 * Boshqaruv paneli vakolatlari.
 *
 * Super-admin (`SUPER_ADMIN_UIDS`) HAMMA vakolatga ega. Boshqa panel
 * xodimlari rol oladi, rol esa shu ro'yxatdan vakolatlar to'plami.
 * Har bir admin yo'li o'z vakolatini `requirePermission` bilan
 * tekshiradi — yangi rol qo'shilganda yo'llar o'zgarmaydi.
 *
 * Tekshiruv BACKENDDA: panelda tugmani yashirish qulaylik, himoya emas.
 */
export const PERMISSIONS = {
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
} as const;

export type Permission = keyof typeof PERMISSIONS;

export const ALL_PERMISSIONS = Object.keys(PERMISSIONS) as Permission[];

/**
 * Rolga BERIB BO'LMAYDIGAN vakolatlar — faqat super-admin.
 *
 * Panel xodimlarini boshqarish rolga berilsa, o'sha rol egasi o'ziga
 * istalgan vakolatni qo'sha oladi — ya'ni amalda super-admin bo'ladi.
 */
export const SUPER_ONLY: ReadonlySet<Permission> = new Set<Permission>(['admins.manage']);

export const ASSIGNABLE_PERMISSIONS = ALL_PERMISSIONS.filter((p) => !SUPER_ONLY.has(p));

export function isPermission(value: unknown): value is Permission {
  return typeof value === 'string' && Object.prototype.hasOwnProperty.call(PERMISSIONS, value);
}

/**
 * Rol uchun vakolatlar ro'yxatini tozalaydi: noma'lumi, takrori va
 * faqat super-adminnikini olib tashlaydi; tartib — `PERMISSIONS` dagidek.
 */
export function sanitizePermissions(input: unknown): Permission[] {
  if (!Array.isArray(input)) return [];
  const wanted = new Set(input.filter(isPermission));
  return ASSIGNABLE_PERMISSIONS.filter((p) => wanted.has(p));
}

export function hasPermission(
  user: { isSuperAdmin: boolean; permissions?: ReadonlySet<Permission> | undefined } | undefined,
  permission: Permission,
): boolean {
  if (!user) return false;
  if (user.isSuperAdmin) return true;
  if (SUPER_ONLY.has(permission)) return false;
  return user.permissions?.has(permission) ?? false;
}
