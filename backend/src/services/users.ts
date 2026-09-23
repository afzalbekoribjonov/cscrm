import type { UserRecord } from 'firebase-admin/auth';

import { auth, db } from '../lib/firebase.js';
import { staffUid } from '../lib/staff.js';
import { ApiError } from '../middleware/error.js';
import type { EmployeeRecord } from '../types/tenant.js';
import { lastActiveOf } from './activity.js';
import { auditUpdate, type Actor } from './audit.js';
import { AUTH_EMAIL_DOMAIN } from './tenant.js';

/**
 * Platforma foydalanuvchilari — bizneslarning egalari va xodimlari.
 *
 * Manba ikkita: baza (kim qaysi biznesda, ismi, telefoni) va Firebase
 * Auth (oxirgi faollik, hisob o'chirilganmi). Xodim hali bir marta ham
 * kirmagan bo'lsa Auth'da hisobi yo'q — u baribir ro'yxatda, "hali
 * kirmagan" deb.
 *
 * Panel xodimlari va super-admin bu ro'yxatda YO'Q (ular "Rollar"da).
 * PIN, parol va boshqa maxfiy maydonlar javobga tushmaydi.
 */

export interface PlatformUser {
  uid: string;
  kind: 'owner' | 'staff';
  tenantId: string;
  tenantName: string;
  tenantArchived: boolean;
  /** Ega — login; xodim — ism familiya. */
  name: string;
  login?: string;
  phone?: string;
  /** Xodim ilovada faolmi (egasi o'chirib qo'ymaganmi). */
  active: boolean;
  /** Hech kirmagan xodimda Auth hisobi yo'q. */
  hasAccount: boolean;
  createdAt: number | null;
  lastActiveAt: number | null;
  disabled: boolean;
}

interface TenantPeople {
  tenantId: string;
  name: string;
  members: string[];
  employees: Record<string, Pick<EmployeeRecord, 'firstName' | 'lastName' | 'phone' | 'active' | 'createdAt'>>;
}

type AuthInfo = Pick<UserRecord, 'uid' | 'email' | 'disabled'> & {
  metadata: { creationTime?: string; lastSignInTime?: string; lastRefreshTime?: string | null };
};

function loginOf(email: string | undefined): string | undefined {
  return email?.endsWith(AUTH_EMAIL_DOMAIN) ? email.slice(0, -AUTH_EMAIL_DOMAIN.length) : undefined;
}

function created(meta: AuthInfo['metadata'] | undefined, fallback?: number): number | null {
  const t = meta?.creationTime ? Date.parse(meta.creationTime) : Number.NaN;
  return Number.isFinite(t) ? t : (fallback ?? null);
}

/**
 * Baza + Auth → ro'yxat. Sof funksiya — sinovda tekshiriladi.
 *
 * `excluded` — panel xodimlari va super-admin: ular biznes a'zosi
 * bo'lib qolgan bo'lsa ham bu yerda ko'rsatilmaydi.
 */
export function buildUserList(
  tenants: TenantPeople[],
  users: ReadonlyMap<string, AuthInfo>,
  archived: ReadonlySet<string>,
  excluded: ReadonlySet<string>,
): PlatformUser[] {
  const out: PlatformUser[] = [];

  for (const t of tenants) {
    const tenantArchived = archived.has(t.tenantId);

    for (const uid of t.members) {
      if (excluded.has(uid)) continue;
      const u = users.get(uid);
      const login = loginOf(u?.email);
      out.push({
        uid,
        kind: 'owner',
        tenantId: t.tenantId,
        tenantName: t.name,
        tenantArchived,
        name: login ?? u?.email ?? 'Biznes egasi',
        ...(login ? { login } : {}),
        active: true,
        hasAccount: Boolean(u),
        createdAt: created(u?.metadata),
        lastActiveAt: u ? lastActiveOf(u.metadata) : null,
        disabled: u?.disabled ?? false,
      });
    }

    for (const [employeeId, e] of Object.entries(t.employees)) {
      const uid = staffUid(t.tenantId, employeeId);
      if (excluded.has(uid)) continue;
      const u = users.get(uid);
      const name = [e.firstName, e.lastName].filter(Boolean).join(' ').trim();
      out.push({
        uid,
        kind: 'staff',
        tenantId: t.tenantId,
        tenantName: t.name,
        tenantArchived,
        name: name || 'Xodim',
        ...(e.phone ? { phone: e.phone } : {}),
        active: e.active !== false,
        hasAccount: Boolean(u),
        createdAt: created(u?.metadata, e.createdAt),
        lastActiveAt: u ? lastActiveOf(u.metadata) : null,
        disabled: u?.disabled ?? false,
      });
    }
  }

  return out;
}

/** Bir vaqtda ko'pi bilan `limit` ta so'rov — bazani bir zumda bosib ketmaslik. */
async function mapLimited<T, R>(items: T[], limit: number, fn: (item: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(items.length);
  let next = 0;
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, async () => {
      while (next < items.length) {
        const i = next++;
        out[i] = await fn(items[i]!);
      }
    }),
  );
  return out;
}

async function readTenantPeople(tenantId: string): Promise<TenantPeople | null> {
  const [name, members, employees] = await Promise.all([
    db().ref(`tenants/${tenantId}/profile/name`).get(),
    db().ref(`tenants/${tenantId}/members`).get(),
    db().ref(`tenants/${tenantId}/employees`).get(),
  ]);
  if (!name.exists()) return null;
  const raw = (employees.val() ?? {}) as Record<string, EmployeeRecord>;
  return {
    tenantId,
    name: String(name.val()),
    members: Object.keys((members.val() ?? {}) as Record<string, unknown>),
    // Faqat ko'rsatiladigan maydonlar — PIN va urinishlar soni tashlanadi.
    employees: Object.fromEntries(
      Object.entries(raw).map(([id, e]) => [
        id,
        { firstName: e.firstName, lastName: e.lastName, phone: e.phone, active: e.active, createdAt: e.createdAt },
      ]),
    ),
  };
}

export async function loadUsers(excluded: ReadonlySet<string>): Promise<PlatformUser[]> {
  const [dir, archive] = await Promise.all([db().ref('tenant_directory').get(), db().ref('tenant_archive').get()]);
  const ids = Object.keys((dir.val() ?? {}) as Record<string, unknown>);
  const archived = new Set(Object.keys((archive.val() ?? {}) as Record<string, unknown>));

  const tenants = (await mapLimited(ids, 10, readTenantPeople)).filter((t): t is TenantPeople => t !== null);

  const users = new Map<string, AuthInfo>();
  let pageToken: string | undefined;
  do {
    const page = await auth().listUsers(1000, pageToken);
    for (const u of page.users) users.set(u.uid, u);
    pageToken = page.pageToken;
  } while (pageToken);

  return buildUserList(tenants, users, archived, excluded);
}

/**
 * Foydalanuvchini barcha qurilmalardan chiqaradi (telefon yo'qolgan,
 * xodim ishdan ketgan). Parol va PIN o'zgarmaydi — keyingi kirishda
 * so'raladi.
 */
export async function signOutEverywhere(params: {
  uid: string;
  excluded: ReadonlySet<string>;
  actor: Actor;
  now: number;
}): Promise<void> {
  if (params.excluded.has(params.uid)) {
    throw ApiError.forbidden('Panel xodimining seanslari bu yerdan boshqarilmaydi.');
  }
  let user: UserRecord;
  try {
    user = await auth().getUser(params.uid);
  } catch {
    throw ApiError.notFound('Bu foydalanuvchi hali tizimga kirmagan — chiqaradigan seans yo\'q.');
  }
  await auth().revokeRefreshTokens(user.uid);

  // Jurnalda kim ekani odam o'qiydigan ko'rinishda: ega — login, xodim — ismi.
  const staff = /^staff_([^_]+)_(.+)$/.exec(user.uid);
  const tenantId = (user.customClaims?.tenantId as string | undefined) ?? staff?.[1];
  const [tenantName, employee] = await Promise.all([
    tenantId ? db().ref(`tenants/${tenantId}/profile/name`).get() : null,
    staff ? db().ref(`tenants/${staff[1]}/employees/${staff[2]}`).get() : null,
  ]);
  const e = employee?.val() as Pick<EmployeeRecord, 'firstName' | 'lastName'> | null | undefined;
  const who = e ? `Xodim: ${[e.firstName, e.lastName].filter(Boolean).join(' ')}` : `Ega: ${loginOf(user.email) ?? user.email ?? '—'}`;

  await db().ref().update(
    auditUpdate({
      at: params.now,
      action: 'user.signout',
      actor: params.actor,
      ...(tenantId ? { tenantId } : {}),
      ...(tenantName?.exists() ? { tenantName: String(tenantName.val()) } : {}),
      note: who,
    }),
  );
}
