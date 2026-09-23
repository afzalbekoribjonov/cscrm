import { db } from '../lib/firebase.js';

/**
 * Xodimlarning PIN hashlari qayerda saqlanadi.
 *
 * NEGA ALOHIDA TUGUN. Avval hash xodim yozuvining ICHIDA turardi
 * (`tenants/{t}/employees/{e}/pinHash`) va qoidada unga `.read: false`
 * qo'yilgan edi. Lekin RTDB'da o'qish ruxsati ota tugundan bolalarga
 * MEROS o'tadi va bola darajasida BEKOR QILIB BO'LMAYDI: `employees`
 * biznesning har bir a'zosiga ochiq bo'lgani uchun `.read: false`
 * ishlamasdi — har bir xodim hamkasblarining hashini o'qiy olardi.
 * 4 xonali PIN'ni bcrypt hashidan tanlab topish oddiy kompyuterda
 * bir necha daqiqa oladi.
 *
 * Endi hash `employee_secrets/{t}/{e}` da — bu tugun mijozga BUTUNLAY
 * yopiq, uni faqat backend (Admin SDK) o'qiydi.
 *
 * ESKI HASHLAR. Mavjud yozuvlar bir martalik skript bilan ko'chirilmaydi
 * (jonli bazaga qo'lda tegilmaydi). Buning o'rniga:
 *   * yangi xodim, PIN almashtirish — hash darhol yangi joyga yoziladi;
 *   * eski hashli xodim muvaffaqiyatli kirganda — hash yangi joyga
 *     KO'CHIRILADI va eski joydan o'chiriladi.
 */
export function secretPath(tenantId: string, employeeId: string): string {
  return `employee_secrets/${tenantId}/${employeeId}`;
}

export function employeePath(tenantId: string, employeeId: string): string {
  return `tenants/${tenantId}/employees/${employeeId}`;
}

/**
 * Qaysi hash amal qiladi: yangi joydagisi, bo'lmasa eskisi.
 *
 * Sof funksiya — sinovda tekshiriladi.
 */
export function pickPinHash(
  secret: unknown,
  legacy: unknown,
): { hash: string | undefined; legacy: boolean } {
  if (secret && typeof secret === 'object') {
    const value = (secret as { pinHash?: unknown }).pinHash;
    if (typeof value === 'string' && value.length > 0) {
      return { hash: value, legacy: false };
    }
  }
  if (typeof legacy === 'string' && legacy.length > 0) {
    return { hash: legacy, legacy: true };
  }
  return { hash: undefined, legacy: false };
}

/** Xodimning amaldagi hashini o'qiydi. */
export async function readPinHash(
  tenantId: string,
  employeeId: string,
  record: { pinHash?: unknown },
): Promise<{ hash: string | undefined; legacy: boolean }> {
  const snap = await db().ref(secretPath(tenantId, employeeId)).get();
  return pickPinHash(snap.val(), record.pinHash);
}

/**
 * Hashni yangi joyga yozadi va eski joydan O'CHIRADI.
 *
 * Bitta ko'p-yo'lli yozuvning bir qismi sifatida ishlatiladi — shunda
 * hash bir lahza ham ikki joyda yoki hech qayerda bo'lmay qolmaydi.
 */
export function pinHashUpdates(
  tenantId: string,
  employeeId: string,
  hash: string,
): Record<string, unknown> {
  return {
    [`${secretPath(tenantId, employeeId)}/pinHash`]: hash,
    [`${employeePath(tenantId, employeeId)}/pinHash`]: null,
  };
}
