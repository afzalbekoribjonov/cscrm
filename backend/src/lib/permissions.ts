/**
 * Boshqaruv paneli vakolatlari.
 *
 * HOZIR: faqat super-admin bor va u HAMMA vakolatga ega.
 * KEYIN: rollar (operator, yordam xizmati…) shu ro'yxatdan vakolat
 * oladi. Shuning uchun har bir admin yo'li hozirdanoq o'z vakolatini
 * `requirePermission` bilan tekshiradi — rol qo'shilganda yo'llarni
 * qayta ko'rib chiqish shart bo'lmaydi.
 *
 * Tekshiruv BACKENDDA: panelda tugmani yashirish qulaylik, himoya emas.
 */
export const PERMISSIONS = {
  'tenants.read': 'Bizneslarni ko\'rish',
  'tenants.edit': 'Biznes ma\'lumotini tahrirlash',
  'tenants.suspend': 'Hisobni to\'xtatish va yoqish',
  'tenants.archive': 'Arxivlash va arxivdan qaytarish',
  'tenants.delete': 'Biznesni butunlay o\'chirish',
  'subscriptions.manage': 'Obunani to\'lovsiz o\'zgartirish',
  'payments.manage': 'To\'lovni tasdiqlash va rad etish',
  'credentials.manage': 'Egasining login va parolini almashtirish',
  'broadcasts.manage': 'Xabarlar yuborish',
  'plans.manage': 'Tarif narxlari',
  'settings.manage': 'Sayt sozlamalari',
  'audit.read': 'Amallar jurnalini ko\'rish',
} as const;

export type Permission = keyof typeof PERMISSIONS;

export const ALL_PERMISSIONS = Object.keys(PERMISSIONS) as Permission[];

export function hasPermission(
  user: { isSuperAdmin: boolean; permissions?: ReadonlySet<Permission> | undefined } | undefined,
  permission: Permission,
): boolean {
  if (!user) return false;
  if (user.isSuperAdmin) return true;
  return user.permissions?.has(permission) ?? false;
}
