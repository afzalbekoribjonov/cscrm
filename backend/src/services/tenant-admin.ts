import { env } from '../config/env.js';
import { auth, db } from '../lib/firebase.js';
import { normalizePhone } from '../lib/phone.js';
import { staffUid } from '../lib/staff.js';
import { ApiError } from '../middleware/error.js';
import type { License, Plan } from '../types/license.js';
import type { TenantProfile } from '../types/tenant.js';
import { SYSTEM_ACTOR, auditUpdate, diff, type Actor } from './audit.js';
import { findPlanWithPrice } from './plan-prices.js';

/**
 * Super-admin: biznesni boshqarish amallari.
 *
 * Har bir amal jurnal yozuvi bilan BITTA atomar yozuvda bajariladi —
 * amal bo'lib, jurnali yo'q bo'lib qolmaydi (va aksincha).
 */

const DAY = 86_400_000;

/** Arxivdagi biznes shuncha kundan keyin butunlay o'chiriladi. */
export const ARCHIVE_DAYS = 30;

/** Arxivlangan biznes ilovasida ko'radigan xabar. */
export const ARCHIVED_MESSAGE =
  'Hisobingiz arxivlangan. Yordam xizmatiga murojaat qiling.';

export interface ArchiveEntry {
  archivedAt: number;
  archivedBy: string;
  reason: string;
  /** Shu vaqtdan keyin avtomatik o'chiriladi. */
  purgeAfter: number;
  /** Arxivdan qaytarilganda tiklanadigan holat. */
  previous: { suspended: boolean; suspendedReason: string | null };
}

type LicenseRecord = Omit<License, 'tenantId'>;

async function readTenant(tenantId: string) {
  const [profileSnap, licenseSnap, archiveSnap] = await Promise.all([
    db().ref(`tenants/${tenantId}/profile`).get(),
    db().ref(`tenants/${tenantId}/license`).get(),
    db().ref(`tenant_archive/${tenantId}`).get(),
  ]);
  if (!profileSnap.exists() || !licenseSnap.exists()) {
    throw ApiError.notFound('Biznes topilmadi.');
  }
  return {
    profile: profileSnap.val() as TenantProfile,
    license: licenseSnap.val() as LicenseRecord,
    archive: (archiveSnap.val() as ArchiveEntry | null) ?? null,
  };
}

/** Arxivdagi biznes — to'lov, to'xtatish, obuna amallari taqiqlangan. */
export async function assertNotArchived(tenantId: string): Promise<void> {
  const snap = await db().ref(`tenant_archive/${tenantId}`).get();
  if (snap.exists()) {
    throw new ApiError(
      409,
      'Biznes arxivda. Bu amal uchun avval uni arxivdan qaytaring.',
      'archived',
    );
  }
}

/* ------------------------------------------------------------------ */
/* Profil                                                              */
/* ------------------------------------------------------------------ */

export interface ProfileInput {
  name?: string;
  phone?: string | null;
  address?: string | null;
}

/**
 * Kiritilgan profil ma'lumotini tekshiradi va bir ko'rinishga keltiradi.
 * Bo'sh telefon yoki manzil — o'chirish (`null`).
 *
 * Sof funksiya — sinovda tekshiriladi.
 */
export function normalizeProfileInput(input: ProfileInput): {
  name?: string;
  phone?: string | null;
  address?: string | null;
} {
  const out: { name?: string; phone?: string | null; address?: string | null } = {};

  if (input.name !== undefined) {
    const name = input.name.trim().replace(/\s+/g, ' ');
    if (name.length < 2) throw ApiError.badRequest('Biznes nomi kamida 2 ta belgidan iborat bo\'lsin.');
    if (name.length > 120) throw ApiError.badRequest('Biznes nomi juda uzun (ko\'pi bilan 120 belgi).');
    out.name = name;
  }

  if (input.phone !== undefined) {
    const raw = (input.phone ?? '').trim();
    if (raw === '') {
      out.phone = null;
    } else {
      const phone = normalizePhone(raw);
      if (phone.length !== 12) throw ApiError.badRequest('Telefon raqamini to\'liq kiriting: +998 XX XXX XX XX.');
      out.phone = phone;
    }
  }

  if (input.address !== undefined) {
    const address = (input.address ?? '').trim().replace(/\s+/g, ' ');
    if (address.length > 300) throw ApiError.badRequest('Manzil juda uzun (ko\'pi bilan 300 belgi).');
    out.address = address === '' ? null : address;
  }

  return out;
}

export async function updateTenantProfile(params: {
  tenantId: string;
  input: ProfileInput;
  actor: Actor;
  now: number;
}): Promise<{ changed: string[] }> {
  const { tenantId } = params;
  const { profile } = await readTenant(tenantId);
  const next = normalizeProfileInput(params.input);

  const before = {
    name: profile.name,
    phone: profile.phone ?? null,
    address: profile.address ?? null,
  };
  const after = { ...before, ...next };
  const changes = diff(before, after);
  const changed = Object.keys(changes);
  if (changed.length === 0) return { changed };

  const updates: Record<string, unknown> = {};
  for (const key of changed) {
    updates[`tenants/${tenantId}/profile/${key}`] = after[key as keyof typeof after];
  }

  // Nom o'zgarsa — xodim kirishida "qaysi biznes?" ro'yxatida ham yangilanadi.
  if (changes.name) {
    const employees = await db().ref(`tenants/${tenantId}/employees`).get();
    for (const e of Object.values((employees.val() ?? {}) as Record<string, { phone?: string }>)) {
      if (e.phone) updates[`employee_phone_index/${e.phone}/${tenantId}/tenantName`] = after.name;
    }
  }

  Object.assign(
    updates,
    auditUpdate({
      at: params.now,
      action: 'tenant.update',
      actor: params.actor,
      tenantId,
      tenantName: after.name,
      changes,
    }),
  );

  await db().ref().update(updates);
  return { changed };
}

/* ------------------------------------------------------------------ */
/* Obuna — to'lovsiz o'zgartirish                                      */
/* ------------------------------------------------------------------ */

export interface LicenseInput {
  planId: string;
  /** Muddatli reja uchun — tugash vaqti (ms). */
  expiresAt?: number | null;
  /** Bir umrlik reja uchun — keyingi yillik to'lov vaqti (ms). */
  nextAnnualFeeAt?: number | null;
  /** Nega o'zgartirildi — jurnal uchun MAJBURIY. */
  reason: string;
}

const MIN_DATE = Date.UTC(2020, 0, 1);
const MAX_AHEAD = 10 * 366 * DAY;

/**
 * Qo'lda o'zgartirilgan obuna yozuvi.
 *
 * Bu TO'LOV EMAS: tushumga yozilmaydi. Masalan, xato tuzatish, sovg'a
 * kunlar yoki boshqa yo'l bilan olingan to'lov. Shuning uchun sabab
 * majburiy va jurnalga tushadi.
 *
 * To'xtatilganlik holatiga tegilmaydi — bu alohida amal.
 *
 * Sof funksiya — sinovda tekshiriladi.
 */
export function buildManualLicense(
  current: LicenseRecord,
  plan: Plan,
  input: LicenseInput,
  now: number,
): LicenseRecord {
  if (input.reason.trim().length < 3) {
    throw ApiError.badRequest('O\'zgartirish sababini yozing.');
  }

  const validDate = (t: number | null | undefined): t is number =>
    typeof t === 'number' && Number.isFinite(t) && t >= MIN_DATE && t <= now + MAX_AHEAD;

  const base: LicenseRecord = {
    planId: plan.id,
    kind: plan.kind,
    // Reja o'zgarmasa boshlanish sanasi saqlanadi — tarix buzilmasin.
    startedAt: plan.id === current.planId ? current.startedAt : now,
    expiresAt: null,
    nextAnnualFeeAt: null,
    suspended: current.suspended ?? false,
    suspendedReason: current.suspendedReason ?? null,
  };

  if (plan.kind === 'lifetime') {
    if (!validDate(input.nextAnnualFeeAt)) {
      throw ApiError.badRequest('Keyingi yillik to\'lov sanasini to\'g\'ri kiriting.');
    }
    return { ...base, nextAnnualFeeAt: input.nextAnnualFeeAt };
  }

  if (!validDate(input.expiresAt)) {
    throw ApiError.badRequest('Obuna tugash sanasini to\'g\'ri kiriting.');
  }
  return { ...base, expiresAt: input.expiresAt };
}

export async function setLicenseManually(params: {
  tenantId: string;
  input: LicenseInput;
  actor: Actor;
  now: number;
}): Promise<{ license: License }> {
  const { tenantId } = params;
  const { profile, license, archive } = await readTenant(tenantId);
  if (archive) {
    throw new ApiError(409, 'Biznes arxivda. Obunani o\'zgartirish uchun avval uni arxivdan qaytaring.', 'archived');
  }

  const plan = await findPlanWithPrice(params.input.planId);
  if (!plan) throw ApiError.badRequest('Bunday reja topilmadi.');

  const next = buildManualLicense(license, plan, params.input, params.now);
  const pick = (l: LicenseRecord) => ({
    planId: l.planId,
    expiresAt: l.expiresAt ?? null,
    nextAnnualFeeAt: l.nextAnnualFeeAt ?? null,
  });

  await db().ref().update({
    [`tenants/${tenantId}/license/planId`]: next.planId,
    [`tenants/${tenantId}/license/kind`]: next.kind,
    [`tenants/${tenantId}/license/startedAt`]: next.startedAt,
    [`tenants/${tenantId}/license/expiresAt`]: next.expiresAt,
    [`tenants/${tenantId}/license/nextAnnualFeeAt`]: next.nextAnnualFeeAt ?? null,
    ...auditUpdate({
      at: params.now,
      action: 'license.update',
      actor: params.actor,
      tenantId,
      tenantName: profile.name,
      note: params.input.reason.trim(),
      changes: diff(pick(license), pick(next)),
    }),
  });

  return { license: { tenantId, ...next } };
}

/* ------------------------------------------------------------------ */
/* Arxiv                                                               */
/* ------------------------------------------------------------------ */

/**
 * Biznesni arxivlaydi: ilova bloklanadi (to'xtatilgan holat orqali —
 * ilovaning mavjud versiyasi uni allaqachon tushunadi), ma'lumot
 * saqlanadi, 30 kundan keyin avtomatik o'chiriladi.
 */
export async function archiveTenant(params: {
  tenantId: string;
  reason: string;
  actor: Actor;
  now: number;
}): Promise<{ purgeAfter: number }> {
  const { tenantId, now } = params;
  const { profile, license, archive } = await readTenant(tenantId);
  if (archive) throw new ApiError(409, 'Biznes allaqachon arxivda.', 'archived');

  const reason = params.reason.trim();
  if (reason.length < 3) throw ApiError.badRequest('Arxivlash sababini yozing.');

  const entry: ArchiveEntry = {
    archivedAt: now,
    archivedBy: params.actor.uid,
    reason,
    purgeAfter: now + ARCHIVE_DAYS * DAY,
    previous: {
      suspended: license.suspended === true,
      suspendedReason: license.suspendedReason ?? null,
    },
  };

  await db().ref().update({
    [`tenant_archive/${tenantId}`]: entry,
    [`tenants/${tenantId}/license/suspended`]: true,
    [`tenants/${tenantId}/license/suspendedReason`]: ARCHIVED_MESSAGE,
    ...auditUpdate({
      at: now,
      action: 'tenant.archive',
      actor: params.actor,
      tenantId,
      tenantName: profile.name,
      note: reason,
    }),
  });

  return { purgeAfter: entry.purgeAfter };
}

/** Arxivdan qaytaradi — arxivlashdan oldingi holat tiklanadi. */
export async function restoreTenant(params: {
  tenantId: string;
  actor: Actor;
  now: number;
}): Promise<void> {
  const { tenantId } = params;
  const { profile, archive } = await readTenant(tenantId);
  if (!archive) throw new ApiError(409, 'Biznes arxivda emas.', 'not_archived');

  await db().ref().update({
    [`tenant_archive/${tenantId}`]: null,
    [`tenants/${tenantId}/license/suspended`]: archive.previous?.suspended ?? false,
    [`tenants/${tenantId}/license/suspendedReason`]: archive.previous?.suspendedReason ?? null,
    ...auditUpdate({
      at: params.now,
      action: 'tenant.restore',
      actor: params.actor,
      tenantId,
      tenantName: profile.name,
    }),
  });
}

/* ------------------------------------------------------------------ */
/* Butunlay o'chirish                                                  */
/* ------------------------------------------------------------------ */

const APOSTROPHES = /[‘’ʻʼ`´]/g;

/**
 * Tasdiqlash uchun yozilgan nom mosmi — saytdagi `matchesConfirmation`
 * bilan AYNAN bir qoida (katta-kichik harf, bo'shliq, tutuq belgisi
 * turi hisobga olinmaydi). Server ham tekshiradi: API'ga to'g'ridan-
 * to'g'ri yuborilgan so'rov ham nomsiz o'tmasin.
 */
export function sameName(input: string, expected: string): boolean {
  const norm = (s: string) =>
    s.replace(APOSTROPHES, "'").trim().replace(/\s+/g, ' ').toLocaleLowerCase('uz');
  const target = norm(expected);
  return target.length > 0 && norm(input) === target;
}

export interface DeletionTargets {
  tenantId: string;
  memberUids: string[];
  employees: { id: string; phone?: string }[];
  loginKeys: string[];
  pendingIds: string[];
  pushTokens: string[];
}

/**
 * O'chiriladigan barcha yo'llar — bitta atomar yozuv uchun.
 *
 * `payments_log` ATAYLAB tegilmaydi: bu platformaning o'z tushum
 * tarixi, biznes o'chsa ham hisob-kitob o'zgarmasligi kerak.
 *
 * Sof funksiya — sinovda tekshiriladi.
 */
export function deletionUpdates(t: DeletionTargets): Record<string, null> {
  const out: Record<string, null> = {
    [`tenants/${t.tenantId}`]: null,
    [`tenant_directory/${t.tenantId}`]: null,
    [`tenant_archive/${t.tenantId}`]: null,
    // PIN hashlari (qarang: pin-store.ts) — biznesning barcha xodimlari.
    [`employee_secrets/${t.tenantId}`]: null,
  };
  for (const login of t.loginKeys) out[`admin_logins/${login}`] = null;
  for (const uid of t.memberUids) out[`user_tenants/${uid}`] = null;
  for (const e of t.employees) {
    if (e.phone) out[`employee_phone_index/${e.phone}/${t.tenantId}`] = null;
  }
  for (const id of t.pendingIds) out[`pending_payments/${id}`] = null;
  for (const token of t.pushTokens) out[`push_tokens/${token}`] = null;
  return out;
}

/**
 * Auth'dan o'chiriladigan hisoblar: egalar va har bir xodim.
 *
 * Super-admin hisobi (`protectedUids`) HECH QACHON o'chirilmaydi — u
 * biror biznesga a'zo bo'lib qolgan bo'lsa ham (masalan, sinov uchun
 * o'zi ro'yxatdan o'tgan): aks holda biznesni o'chirish panelga kirishni
 * ham yo'qotardi.
 */
export function authUidsToDelete(t: DeletionTargets, protectedUids: ReadonlySet<string> = new Set()): string[] {
  return [
    ...t.memberUids.filter((uid) => !protectedUids.has(uid)),
    ...t.employees.map((e) => staffUid(t.tenantId, e.id)),
  ];
}

const keysOf = (v: unknown): string[] => (v && typeof v === 'object' ? Object.keys(v) : []);

async function collectDeletionTargets(tenantId: string): Promise<DeletionTargets> {
  const [members, employees, logins, pending, tokens] = await Promise.all([
    db().ref(`tenants/${tenantId}/members`).get(),
    db().ref(`tenants/${tenantId}/employees`).get(),
    db().ref('admin_logins').orderByChild('tenantId').equalTo(tenantId).get(),
    db().ref('pending_payments').orderByChild('tenantId').equalTo(tenantId).get(),
    db().ref('push_tokens').orderByChild('tenantId').equalTo(tenantId).get(),
  ]);

  const memberUids = keysOf(members.val());
  // `user_tenants/{uid}` faqat SHU biznesga ishora qilsa o'chiriladi.
  const owned = await Promise.all(
    memberUids.map(async (uid) => ((await db().ref(`user_tenants/${uid}`).get()).val() === tenantId ? uid : null)),
  );

  return {
    tenantId,
    memberUids: owned.filter((u): u is string => u !== null),
    employees: Object.entries((employees.val() ?? {}) as Record<string, { phone?: string }>).map(
      ([id, e]) => ({ id, ...(e.phone ? { phone: e.phone } : {}) }),
    ),
    loginKeys: keysOf(logins.val()),
    pendingIds: keysOf(pending.val()),
    pushTokens: keysOf(tokens.val()),
  };
}

/**
 * Biznesni BUTUNLAY o'chiradi. Qaytarib bo'lmaydi.
 *
 * Faqat ARXIVDAGI biznes o'chiriladi — to'g'ridan-to'g'ri o'chirish
 * yo'q: avval arxiv (qaytarsa bo'ladi), keyin o'chirish.
 * Qo'lda o'chirishda biznes nomi server tomonida ham tekshiriladi.
 */
export async function deleteTenantPermanently(params: {
  tenantId: string;
  /** Qo'lda o'chirishda majburiy; avtomatik tozalashda yo'q. */
  confirmName?: string;
  actor: Actor;
  now: number;
  mode: 'manual' | 'purge';
}): Promise<{ users: number; employees: number }> {
  const { tenantId, now } = params;
  const { profile, archive } = await readTenant(tenantId);
  if (!archive) {
    throw new ApiError(409, 'Faqat arxivdagi biznesni butunlay o\'chirish mumkin.', 'not_archived');
  }
  if (params.mode === 'manual' && !sameName(params.confirmName ?? '', profile.name)) {
    throw ApiError.badRequest('Biznes nomi mos kelmadi. O\'chirish bekor qilindi.');
  }
  if (params.mode === 'purge' && archive.purgeAfter > now) {
    throw new ApiError(409, 'Arxiv muddati hali tugamagan.', 'not_due');
  }

  const targets = await collectDeletionTargets(tenantId);

  await db().ref().update({
    ...deletionUpdates(targets),
    ...auditUpdate({
      at: now,
      action: params.mode === 'purge' ? 'tenant.purge' : 'tenant.delete',
      actor: params.actor,
      tenantId,
      tenantName: profile.name,
      note: `Arxivlash sababi: ${archive.reason}`,
    }),
  });

  // Auth hisoblari — ma'lumot o'chirilgandan KEYIN. Muvaffaqiyatsiz
  // bo'lsa ham xavfsiz: hisob biznessiz qoladi, qoidalar unga hech
  // narsa ochmaydi. Hech qachon kirmagan xodimning hisobi yo'q — xato emas.
  const uids = authUidsToDelete(targets, env.superAdminUids);
  let users = 0;
  for (let i = 0; i < uids.length; i += 1000) {
    const res = await auth().deleteUsers(uids.slice(i, i + 1000));
    users += res.successCount;
  }

  return { users, employees: targets.employees.length };
}

/* ------------------------------------------------------------------ */
/* 30 kunlik avtomatik tozalash                                        */
/* ------------------------------------------------------------------ */

/** Muddati o'tgan arxivlar. Sof funksiya — sinovda tekshiriladi. */
export function dueForPurge(archives: Record<string, Partial<ArchiveEntry>> | null, now: number): string[] {
  if (!archives) return [];
  return Object.entries(archives)
    .filter(([, a]) => typeof a.purgeAfter === 'number' && Number.isFinite(a.purgeAfter) && a.purgeAfter <= now)
    .map(([id]) => id);
}

/**
 * Arxivda 30 kundan ortiq turgan bizneslarni o'chiradi.
 *
 * Server ishga tushganda va har 6 soatda chaqiriladi. Qayta chaqirish
 * xavfsiz: o'chirilgan biznes arxiv ro'yxatidan ham yo'qoladi.
 */
export async function purgeExpiredArchives(now: number): Promise<string[]> {
  const snap = await db().ref('tenant_archive').get();
  const due = dueForPurge(snap.val() as Record<string, ArchiveEntry> | null, now);
  const done: string[] = [];
  for (const tenantId of due) {
    try {
      await deleteTenantPermanently({ tenantId, actor: SYSTEM_ACTOR, now, mode: 'purge' });
      done.push(tenantId);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[cscrm] arxivdagi biznesni o'chirib bo'lmadi: ${tenantId}`, err);
    }
  }
  return done;
}
