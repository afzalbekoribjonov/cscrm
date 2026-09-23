import { randomInt } from 'node:crypto';

import { env } from '../config/env.js';
import { auth, db } from '../lib/firebase.js';
import {
  ALL_PERMISSIONS,
  PERMISSIONS,
  sanitizePermissions,
  type Permission,
} from '../lib/permissions.js';
import { ApiError } from '../middleware/error.js';
import { auditUpdate, diff, type Actor } from './audit.js';
import { AUTH_EMAIL_DOMAIN } from './tenant.js';

/**
 * Panel xodimlari va rollar.
 *
 *   admin_roles/{roleId}   { name, description?, permissions: ["tenants.read", …], createdAt, createdBy, updatedAt? }
 *   admin_members/{uid}    { email, roleId, addedAt, addedBy }
 *
 * Super-admin (`SUPER_ADMIN_UIDS`) bu yerda YO'Q — u server sozlamasida,
 * uni panel orqali olib tashlab yoki o'zgartirib bo'lmaydi. Ikkala
 * tugun ham faqat serverga ochiq (qoidalar).
 */

export interface AdminRole {
  id: string;
  name: string;
  description?: string;
  permissions: Permission[];
  createdAt: number;
  createdBy: string;
  updatedAt?: number;
}

export interface AdminMemberRecord {
  email: string;
  roleId: string;
  addedAt: number;
  addedBy: string;
}

export type Access =
  | { kind: 'super'; permissions: Permission[] }
  | { kind: 'member'; role: { id: string; name: string } | null; permissions: Permission[] };

const ROLE_NAME_MIN = 2;
const ROLE_NAME_MAX = 60;

/* ------------------------------------------------------------------ */
/* Sof funksiyalar                                                     */
/* ------------------------------------------------------------------ */

/**
 * Bazadagi vakolatlar → tartiblangan ro'yxat (noma'lumlari tashlanadi).
 *
 * Ro'yxat (massiv) sifatida saqlanadi: vakolat nomidagi nuqta
 * (`tenants.read`) bazada KALIT bo'la olmaydi. Baza massivni ba'zan
 * `{0: …, 1: …}` ko'rinishida qaytaradi — ikkalasi ham o'qiladi.
 */
export function permissionsFromRecord(record: unknown): Permission[] {
  if (!record || typeof record !== 'object') return [];
  return sanitizePermissions(Array.isArray(record) ? record : Object.values(record));
}

export function permissionsToRecord(list: readonly Permission[]): string[] {
  return [...list];
}

/**
 * Kimning qanday kirishi bor.
 *
 * Rol o'chirilgan yoki topilmasa — xodim panelga KIRADI, lekin hech
 * narsa qila olmaydi (vakolatsiz). Bu "hech narsa ko'rinmayapti" degan
 * aniq holat, jimgina hamma narsani ochib qo'yishdan xavfsizroq.
 */
export function accessFrom(
  uid: string,
  superAdminUids: ReadonlySet<string>,
  member: Partial<AdminMemberRecord> | null,
  role: { name?: unknown; permissions?: unknown } | null,
  roleId?: string,
): Access | null {
  if (superAdminUids.has(uid)) return { kind: 'super', permissions: [...ALL_PERMISSIONS] };
  if (!member) return null;
  if (!role || typeof role.name !== 'string') return { kind: 'member', role: null, permissions: [] };
  return {
    kind: 'member',
    role: { id: roleId ?? member.roleId ?? '', name: role.name },
    permissions: permissionsFromRecord(role.permissions),
  };
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

/** Panel xodimi emaili: haqiqiy pochta, ilova loginlari (`@cscrm.local`) emas. */
export function normalizeStaffEmail(raw: string): string {
  const email = raw.trim().toLowerCase();
  if (!EMAIL.test(email) || email.length > 200) {
    throw ApiError.badRequest('Email manzilini to\'g\'ri kiriting.');
  }
  if (email.endsWith(AUTH_EMAIL_DOMAIN)) {
    throw ApiError.badRequest('Bu biznes egasining ilova logini. Panel uchun alohida email kiriting.');
  }
  return email;
}

export function normalizeRoleInput(input: {
  name?: unknown;
  description?: unknown;
  permissions?: unknown;
}): { name?: string; description?: string | null; permissions?: Permission[] } {
  const out: { name?: string; description?: string | null; permissions?: Permission[] } = {};
  if (input.name !== undefined) {
    const name = String(input.name).trim().replace(/\s+/g, ' ');
    if (name.length < ROLE_NAME_MIN || name.length > ROLE_NAME_MAX) {
      throw ApiError.badRequest(`Rol nomi ${ROLE_NAME_MIN}–${ROLE_NAME_MAX} belgidan iborat bo'lsin.`);
    }
    out.name = name;
  }
  if (input.description !== undefined) {
    const d = input.description === null ? '' : String(input.description).trim();
    out.description = d.length > 0 ? d.slice(0, 300) : null;
  }
  if (input.permissions !== undefined) out.permissions = sanitizePermissions(input.permissions);
  return out;
}

/** O'qish oson, adashtiradigan belgilarsiz (0/O, 1/l yo'q) vaqtinchalik parol. */
export function temporaryPassword(length = 12): string {
  const alphabet = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
  return Array.from({ length }, () => alphabet[randomInt(alphabet.length)]).join('');
}

/* ------------------------------------------------------------------ */
/* Kirish huquqi (so'rovlar uchun, qisqa keshi bilan)                 */
/* ------------------------------------------------------------------ */

const CACHE_MS = 30_000;
const cache = new Map<string, { at: number; access: Access | null }>();

/** Rol yoki xodim o'zgarganda — keyingi so'rov yangi huquq bilan ishlaydi. */
export function clearAccessCache(): void {
  cache.clear();
}

/**
 * Foydalanuvchining panelga kirishi. Har bir admin so'rovida chaqiriladi,
 * shuning uchun 30 soniya keshlanadi: bazaga har so'rovda murojaat yo'q,
 * o'zgarish esa ko'pi bilan yarim daqiqada kuchga kiradi (shu jarayondagi
 * o'zgarish — darhol, `clearAccessCache`).
 */
export async function resolveAccess(uid: string, now = Date.now()): Promise<Access | null> {
  if (env.superAdminUids.has(uid)) return accessFrom(uid, env.superAdminUids, null, null);

  const hit = cache.get(uid);
  if (hit && now - hit.at < CACHE_MS) return hit.access;

  const memberSnap = await db().ref(`admin_members/${uid}`).get();
  const member = memberSnap.exists() ? (memberSnap.val() as AdminMemberRecord) : null;
  const roleSnap = member?.roleId ? await db().ref(`admin_roles/${member.roleId}`).get() : null;
  const access = accessFrom(uid, env.superAdminUids, member, roleSnap?.exists() ? roleSnap.val() : null);

  cache.set(uid, { at: now, access });
  return access;
}

/** Hisob panel xodimimi (super-admin yoki rolga ega). */
export async function isPanelAccount(uid: string): Promise<boolean> {
  if (env.superAdminUids.has(uid)) return true;
  return (await db().ref(`admin_members/${uid}`).get()).exists();
}

/* ------------------------------------------------------------------ */
/* Rollar                                                              */
/* ------------------------------------------------------------------ */

type RoleRecord = Omit<AdminRole, 'id' | 'permissions'> & { permissions?: unknown };

async function readRoles(): Promise<AdminRole[]> {
  const snap = await db().ref('admin_roles').get();
  if (!snap.exists()) return [];
  return Object.entries(snap.val() as Record<string, RoleRecord>)
    .map(([id, r]) => ({
      id,
      name: r.name,
      ...(r.description ? { description: r.description } : {}),
      permissions: permissionsFromRecord(r.permissions),
      createdAt: r.createdAt,
      createdBy: r.createdBy,
      ...(r.updatedAt ? { updatedAt: r.updatedAt } : {}),
    }))
    .sort((a, b) => a.createdAt - b.createdAt);
}

async function readMembers(): Promise<Record<string, AdminMemberRecord>> {
  const snap = await db().ref('admin_members').get();
  return snap.exists() ? (snap.val() as Record<string, AdminMemberRecord>) : {};
}

function assertUniqueName(roles: AdminRole[], name: string, exceptId?: string) {
  const lower = name.toLocaleLowerCase('uz');
  if (roles.some((r) => r.id !== exceptId && r.name.toLocaleLowerCase('uz') === lower)) {
    throw new ApiError(409, 'Bunday nomli rol bor. Boshqa nom tanlang.', 'role_exists');
  }
}

export interface AccessOverview {
  roles: (AdminRole & { memberCount: number })[];
  members: {
    uid: string;
    email: string;
    roleId: string;
    roleName: string | null;
    addedAt: number;
    lastSignInAt: number | null;
    disabled: boolean;
  }[];
  superAdmins: { uid: string; email: string | null; lastSignInAt: number | null }[];
  permissions: { id: Permission; label: string; superOnly: boolean }[];
}

/** Rollar sahifasi uchun hammasi bitta so'rovda. */
export async function loadAccessOverview(): Promise<AccessOverview> {
  const [roles, members] = await Promise.all([readRoles(), readMembers()]);
  const memberUids = Object.keys(members);
  const superUids = [...env.superAdminUids];

  const lookup = [...memberUids, ...superUids].map((uid) => ({ uid }));
  const users = new Map<string, { email?: string; lastSignInTime?: string; disabled: boolean }>();
  for (let i = 0; i < lookup.length; i += 100) {
    const res = await auth().getUsers(lookup.slice(i, i + 100));
    for (const u of res.users) {
      users.set(u.uid, { email: u.email, lastSignInTime: u.metadata.lastSignInTime, disabled: u.disabled });
    }
  }
  const signedIn = (uid: string) => {
    const t = users.get(uid)?.lastSignInTime;
    const ms = t ? Date.parse(t) : Number.NaN;
    return Number.isFinite(ms) ? ms : null;
  };

  const counts = new Map<string, number>();
  for (const m of Object.values(members)) counts.set(m.roleId, (counts.get(m.roleId) ?? 0) + 1);

  return {
    roles: roles.map((r) => ({ ...r, memberCount: counts.get(r.id) ?? 0 })),
    members: memberUids
      .map((uid) => {
        const m = members[uid]!;
        return {
          uid,
          email: users.get(uid)?.email ?? m.email,
          roleId: m.roleId,
          roleName: roles.find((r) => r.id === m.roleId)?.name ?? null,
          addedAt: m.addedAt,
          lastSignInAt: signedIn(uid),
          disabled: users.get(uid)?.disabled ?? false,
        };
      })
      .sort((a, b) => a.addedAt - b.addedAt),
    superAdmins: superUids.map((uid) => ({
      uid,
      email: users.get(uid)?.email ?? null,
      lastSignInAt: signedIn(uid),
    })),
    permissions: (Object.keys(PERMISSIONS) as Permission[]).map((id) => ({
      id,
      label: PERMISSIONS[id],
      superOnly: id === 'admins.manage',
    })),
  };
}

export async function createRole(params: {
  input: { name?: unknown; description?: unknown; permissions?: unknown };
  actor: Actor;
  now: number;
}): Promise<{ id: string }> {
  const input = normalizeRoleInput(params.input);
  if (!input.name) throw ApiError.badRequest('Rol nomini kiriting.');
  const roles = await readRoles();
  assertUniqueName(roles, input.name);

  const id = db().ref('admin_roles').push().key!;
  const permissions = input.permissions ?? [];
  await db().ref().update({
    [`admin_roles/${id}`]: {
      name: input.name,
      ...(input.description ? { description: input.description } : {}),
      permissions: permissionsToRecord(permissions),
      createdAt: params.now,
      createdBy: params.actor.uid,
    },
    ...auditUpdate({
      at: params.now,
      action: 'role.create',
      actor: params.actor,
      note: `${input.name}: ${permissions.length} ta vakolat`,
    }),
  });
  clearAccessCache();
  return { id };
}

export async function updateRole(params: {
  roleId: string;
  input: { name?: unknown; description?: unknown; permissions?: unknown };
  actor: Actor;
  now: number;
}): Promise<{ changed: string[] }> {
  const roles = await readRoles();
  const role = roles.find((r) => r.id === params.roleId);
  if (!role) throw ApiError.notFound('Rol topilmadi.');
  const input = normalizeRoleInput(params.input);
  if (input.name) assertUniqueName(roles, input.name, role.id);

  const before = { name: role.name, description: role.description ?? null, permissions: role.permissions.join(', ') };
  const after = {
    name: input.name ?? role.name,
    description: input.description !== undefined ? input.description : (role.description ?? null),
    permissions: (input.permissions ?? role.permissions).join(', '),
  };
  const changes = diff(before, after);
  const changed = Object.keys(changes);
  if (changed.length === 0) return { changed };

  const base = `admin_roles/${role.id}`;
  await db().ref().update({
    [`${base}/name`]: after.name,
    [`${base}/description`]: after.description,
    ...(input.permissions ? { [`${base}/permissions`]: permissionsToRecord(input.permissions) } : {}),
    [`${base}/updatedAt`]: params.now,
    ...auditUpdate({ at: params.now, action: 'role.update', actor: params.actor, note: after.name, changes }),
  });
  clearAccessCache();
  return { changed };
}

export async function deleteRole(params: { roleId: string; actor: Actor; now: number }): Promise<void> {
  const [roles, members] = await Promise.all([readRoles(), readMembers()]);
  const role = roles.find((r) => r.id === params.roleId);
  if (!role) throw ApiError.notFound('Rol topilmadi.');
  const used = Object.values(members).filter((m) => m.roleId === role.id).length;
  if (used > 0) {
    throw new ApiError(409, `Bu rolda ${used} ta xodim bor. Avval ularni boshqa rolga o'tkazing.`, 'role_in_use');
  }
  await db().ref().update({
    [`admin_roles/${role.id}`]: null,
    ...auditUpdate({ at: params.now, action: 'role.delete', actor: params.actor, note: role.name }),
  });
  clearAccessCache();
}

/* ------------------------------------------------------------------ */
/* Panel xodimlari                                                     */
/* ------------------------------------------------------------------ */

/**
 * Xodim qo'shish. Hisob yo'q bo'lsa yaratiladi va vaqtinchalik parol
 * BIR MARTA qaytariladi (hech qayerda saqlanmaydi).
 *
 * Biznesga bog'langan hisob (ilova egasi yoki xodimi) panelga qo'shilmaydi:
 * aks holda o'sha biznesning parolini tiklash huquqi bor admin shu yo'l
 * bilan boshqa panel xodimining hisobini egallab olishi mumkin bo'lardi.
 */
export async function addMember(params: {
  email: string;
  roleId: string;
  actor: Actor;
  now: number;
}): Promise<{ uid: string; created: boolean; temporaryPassword?: string }> {
  const email = normalizeStaffEmail(params.email);
  const roles = await readRoles();
  const role = roles.find((r) => r.id === params.roleId);
  if (!role) throw ApiError.badRequest('Rolni tanlang.');

  let uid: string;
  let created = false;
  let password: string | undefined;
  try {
    const user = await auth().getUserByEmail(email);
    uid = user.uid;
    const claims = user.customClaims ?? {};
    if (typeof claims.tenantId === 'string' || uid.startsWith('staff_')) {
      throw new ApiError(409, 'Bu hisob biznesga bog\'langan. Panel uchun alohida email ishlating.', 'tenant_account');
    }
  } catch (err) {
    if (err instanceof ApiError) throw err;
    if ((err as { code?: string }).code !== 'auth/user-not-found') throw err;
    password = temporaryPassword();
    const user = await auth().createUser({ email, password, emailVerified: false });
    uid = user.uid;
    created = true;
  }

  if (env.superAdminUids.has(uid)) {
    throw new ApiError(409, 'Bu hisob allaqachon to\'liq huquqli administrator.', 'already_super');
  }
  const [linked, existing] = await Promise.all([
    db().ref(`user_tenants/${uid}`).get(),
    db().ref(`admin_members/${uid}`).get(),
  ]);
  if (linked.exists()) {
    throw new ApiError(409, 'Bu hisob biznesga bog\'langan. Panel uchun alohida email ishlating.', 'tenant_account');
  }
  if (existing.exists()) {
    throw new ApiError(409, 'Bu xodim allaqachon panelda. Rolini ro\'yxatdan o\'zgartiring.', 'already_member');
  }

  await db().ref().update({
    [`admin_members/${uid}`]: { email, roleId: role.id, addedAt: params.now, addedBy: params.actor.uid },
    ...auditUpdate({
      at: params.now,
      action: 'admin.add',
      actor: params.actor,
      note: `${email} — ${role.name}${created ? ' (yangi hisob)' : ''}`,
    }),
  });
  clearAccessCache();
  return { uid, created, ...(password ? { temporaryPassword: password } : {}) };
}

export async function setMemberRole(params: {
  uid: string;
  roleId: string;
  actor: Actor;
  now: number;
}): Promise<void> {
  const [roles, memberSnap] = await Promise.all([readRoles(), db().ref(`admin_members/${params.uid}`).get()]);
  if (!memberSnap.exists()) throw ApiError.notFound('Xodim topilmadi.');
  const member = memberSnap.val() as AdminMemberRecord;
  const role = roles.find((r) => r.id === params.roleId);
  if (!role) throw ApiError.badRequest('Rolni tanlang.');
  if (member.roleId === role.id) return;

  await db().ref().update({
    [`admin_members/${params.uid}/roleId`]: role.id,
    ...auditUpdate({
      at: params.now,
      action: 'admin.role',
      actor: params.actor,
      note: member.email,
      changes: {
        role: { from: roles.find((r) => r.id === member.roleId)?.name ?? null, to: role.name },
      },
    }),
  });
  clearAccessCache();
}

/** Paneldan chiqarish: huquq olinadi, ochiq seanslar yopiladi. Hisobning o'zi qoladi. */
export async function removeMember(params: { uid: string; actor: Actor; now: number }): Promise<void> {
  if (params.uid === params.actor.uid) {
    throw ApiError.badRequest('O\'zingizni paneldan chiqara olmaysiz.');
  }
  const snap = await db().ref(`admin_members/${params.uid}`).get();
  if (!snap.exists()) throw ApiError.notFound('Xodim topilmadi.');
  const member = snap.val() as AdminMemberRecord;

  await db().ref().update({
    [`admin_members/${params.uid}`]: null,
    ...auditUpdate({ at: params.now, action: 'admin.remove', actor: params.actor, note: member.email }),
  });
  clearAccessCache();
  await auth().revokeRefreshTokens(params.uid);
}

/** Panel hisoblari (super-admin + xodimlar) — bizneslar ro'yxatlaridan chiqariladi. */
export async function panelUids(): Promise<Set<string>> {
  const members = await readMembers();
  return new Set([...env.superAdminUids, ...Object.keys(members)]);
}
