import { auth } from '../lib/firebase.js';

/**
 * Bizneslarning ilovadan HAQIQATAN foydalanayotgani.
 *
 * Qayerdan: Firebase Auth har bir hisob uchun oxirgi kirish va oxirgi
 * token yangilanishi vaqtini o'zi saqlaydi. Ilova ochiq turganda token
 * soatiga bir yangilanadi — ya'ni `lastRefreshTime` "oxirgi marta
 * qachon ishlatilgan" degan savolga ishonchli javob.
 *
 * Nega shunday: faollikni bazaga alohida yozish har bir ilovadan
 * qo'shimcha yozuv talab qilardi. Bu ma'lumot esa allaqachon bor va
 * uni o'qish bazaga umuman tegmaydi.
 */

export interface UserActivity {
  uid: string;
  tenantId: string;
  lastActiveAt: number | null;
}

export interface ActivitySummary {
  /** Biznes → uning biror foydalanuvchisining eng so'nggi faolligi. */
  lastActiveByTenant: Map<string, number>;
  totalUsers: number;
  activeUsers: number;
  activeTenants: number;
}

const STAFF_UID = /^staff_([^_]+)_(.+)$/;

/**
 * Hisob qaysi biznesga tegishli.
 *
 * * Ega — da'volarida `tenantId` bor (Admin SDK yozgan).
 * * Xodim — da'volari foydalanuvchi yozuvida EMAS, faqat tokenda
 *   (custom token). Lekin UID'i `staff_{tenantId}_{employeeId}`
 *   ko'rinishida — biznes shundan olinadi. Tenant ID alifbosida `_`
 *   yo'q, shuning uchun ajratish bir ma'noli.
 *
 * Super-admin va biznesga bog'lanmagan hisoblar hisobga olinmaydi.
 */
export function tenantOfUser(
  uid: string,
  claims: Record<string, unknown> | undefined,
  superAdminUids: ReadonlySet<string>,
): string | null {
  if (superAdminUids.has(uid)) return null;
  const claimed = claims?.tenantId;
  if (typeof claimed === 'string' && claimed.length > 0) return claimed;
  const m = STAFF_UID.exec(uid);
  return m?.[1] ?? null;
}

/** Ikki vaqtdan kechrog'i; Auth ularni matn ko'rinishida beradi. */
export function lastActiveOf(meta: {
  lastSignInTime?: string | null;
  lastRefreshTime?: string | null;
}): number | null {
  const times = [meta.lastSignInTime, meta.lastRefreshTime]
    .map((t) => (t ? Date.parse(t) : Number.NaN))
    .filter((t) => Number.isFinite(t));
  return times.length > 0 ? Math.max(...times) : null;
}

/** Sof hisob — sinovda Auth'siz tekshiriladi. */
export function summarizeActivity(
  users: UserActivity[],
  now: number,
  windowMs: number,
): ActivitySummary {
  const since = now - windowMs;
  const lastActiveByTenant = new Map<string, number>();
  const activeTenantSet = new Set<string>();
  let activeUsers = 0;

  for (const u of users) {
    if (u.lastActiveAt === null) continue;
    const prev = lastActiveByTenant.get(u.tenantId) ?? 0;
    if (u.lastActiveAt > prev) lastActiveByTenant.set(u.tenantId, u.lastActiveAt);
    if (u.lastActiveAt >= since) {
      activeUsers += 1;
      activeTenantSet.add(u.tenantId);
    }
  }

  return {
    lastActiveByTenant,
    totalUsers: users.length,
    activeUsers,
    activeTenants: activeTenantSet.size,
  };
}

/**
 * Auth'dagi barcha biznes hisoblarini o'qiydi (sahifalab, 1000 tadan).
 *
 * Bu Auth xizmatiga murojaat — bazaga emas. Xato bo'lsa chaqiruvchi
 * faollik ko'rsatkichini ko'rsatmaydi, butun sahifa yiqilmaydi.
 */
export async function loadUserActivity(
  superAdminUids: ReadonlySet<string>,
): Promise<UserActivity[]> {
  const out: UserActivity[] = [];
  let pageToken: string | undefined;

  do {
    const page = await auth().listUsers(1000, pageToken);
    for (const u of page.users) {
      const tenantId = tenantOfUser(u.uid, u.customClaims, superAdminUids);
      if (!tenantId) continue;
      out.push({ uid: u.uid, tenantId, lastActiveAt: lastActiveOf(u.metadata) });
    }
    pageToken = page.pageToken;
  } while (pageToken);

  return out;
}
