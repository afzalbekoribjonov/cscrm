import { db } from '../lib/firebase.js';
import { whereEquals } from '../lib/query.js';

/**
 * Amallar jurnali — muhim admin harakatlari: KIM, NIMA, QACHON.
 *
 * Nega bazada: Render loglari bepul tarifda tez o'chadi va ularni
 * panelda ko'rsatib bo'lmaydi. Jurnal esa biznes kartasining "Tarix"
 * bo'limida va umumiy jurnal sahifasida o'qiladi.
 *
 * MAXFIY MA'LUMOT YOZILMAYDI: parol, PIN, token, hash — kalit nomi
 * shunga o'xshasa qiymat umuman saqlanmaydi (`sanitizeChanges`).
 * Parol almashtirilgani yoziladi, parolning o'zi — hech qachon.
 *
 * Tugun mijozga butunlay yopiq (qoidalar), faqat backend yozadi.
 */

export type AuditAction =
  | 'payment.confirm'
  | 'payment.reject'
  | 'tenant.update'
  | 'tenant.suspend'
  | 'tenant.unsuspend'
  | 'tenant.archive'
  | 'tenant.restore'
  | 'tenant.delete'
  | 'tenant.purge'
  | 'license.update'
  | 'credentials.login'
  | 'credentials.password'
  | 'plan.price'
  | 'plan.price_reset'
  | 'broadcast.create'
  | 'broadcast.delete'
  | 'site.settings'
  | 'role.create'
  | 'role.update'
  | 'role.delete'
  | 'admin.add'
  | 'admin.role'
  | 'admin.remove'
  | 'user.signout';

export interface Actor {
  uid: string;
  email: string | null;
}

/** Tizimning o'zi bajargan amal (masalan, 30 kunlik arxivni tozalash). */
export const SYSTEM_ACTOR: Actor = { uid: 'system', email: null };

export interface AuditChange {
  from: unknown;
  to: unknown;
}

export interface AuditEntry {
  at: number;
  action: AuditAction;
  actor: Actor;
  tenantId?: string;
  tenantName?: string;
  /** Odam o'qiydigan qisqa izoh (sabab va h.k.). */
  note?: string;
  changes?: Record<string, AuditChange>;
}

const SECRET_KEY = /pass|parol|pin|token|secret|hash|key/i;
const MAX_TEXT = 300;

function clip(v: unknown): unknown {
  if (typeof v === 'string') return v.length > MAX_TEXT ? `${v.slice(0, MAX_TEXT)}…` : v;
  if (v === undefined) return null;
  return v;
}

/**
 * O'zgarishlardan maxfiy maydonlarni olib tashlaydi, matnni qisqartiradi.
 * Maxfiy maydon o'zgargani qayd qilinadi — qiymatisiz.
 *
 * Sof funksiya — sinovda tekshiriladi.
 */
export function sanitizeChanges(
  changes: Record<string, AuditChange> | undefined,
): Record<string, AuditChange> | undefined {
  if (!changes) return undefined;
  const out: Record<string, AuditChange> = {};
  for (const [key, change] of Object.entries(changes)) {
    // RTDB kaliti bo'la olmaydigan belgilar — kalit nomini tozalaymiz.
    const safeKey = key.replace(/[.#$/[\]]/g, '_');
    out[safeKey] = SECRET_KEY.test(key)
      ? { from: '[yashirilgan]', to: '[yashirilgan]' }
      : { from: clip(change.from), to: clip(change.to) };
  }
  return Object.keys(out).length > 0 ? out : undefined;
}

/** Faqat haqiqatan o'zgargan maydonlar. */
export function diff(
  before: Record<string, unknown>,
  after: Record<string, unknown>,
): Record<string, AuditChange> {
  const out: Record<string, AuditChange> = {};
  for (const key of Object.keys(after)) {
    const from = before[key] ?? null;
    const to = after[key] ?? null;
    if (JSON.stringify(from) !== JSON.stringify(to)) out[key] = { from, to };
  }
  return out;
}

export function auditRecord(entry: AuditEntry): Record<string, unknown> {
  const changes = sanitizeChanges(entry.changes);
  return {
    at: entry.at,
    action: entry.action,
    actor: { uid: entry.actor.uid, email: entry.actor.email ?? null },
    ...(entry.tenantId ? { tenantId: entry.tenantId } : {}),
    ...(entry.tenantName ? { tenantName: clip(entry.tenantName) } : {}),
    ...(entry.note ? { note: clip(entry.note) } : {}),
    ...(changes ? { changes } : {}),
  };
}

/**
 * Ko'p-yo'lli yozuvga qo'shiladigan jurnal yozuvi — amal bilan BIRGA,
 * bitta atomar yozuvda. Amal bajarilib, jurnali yozilmay qolmaydi.
 */
export function auditUpdate(entry: AuditEntry): Record<string, unknown> {
  const key = db().ref('admin_audit').push().key!;
  return { [`admin_audit/${key}`]: auditRecord(entry) };
}

/** Alohida yozish — amal ko'p-yo'lli yozuvga sig'maydigan hollarda. */
export async function writeAudit(entry: AuditEntry): Promise<void> {
  try {
    await db().ref().update(auditUpdate(entry));
  } catch (err) {
    // Amal bajarilgan — jurnal yozuvi uni bekor qilmasligi kerak.
    // eslint-disable-next-line no-console
    console.error('[cscrm] jurnalga yozib bo\'lmadi', entry.action, err);
  }
}

export interface AuditRow extends AuditEntry {
  id: string;
}

/** Sahifalash kursori — oxirgi ko'rilgan yozuvning push-kaliti. */
export const AUDIT_CURSOR = /^[-_A-Za-z0-9]{10,40}$/;

/**
 * Jurnal — eng yangisi birinchi.
 *
 * Umumiy jurnal KALIT tartibida o'qiladi: push-kalit yaratilgan vaqtni
 * o'z ichiga oladi, ya'ni kalit tartibi = vaqt tartibi, va bu uchun
 * indeks kerak emas. `before` — oxirgi ko'rilgan yozuv kaliti ("ko'proq").
 *
 * `tenantId` berilsa — faqat shu biznes (`tenantId` indeksi orqali;
 * indeks hali joylanmagan bo'lsa ham ishlaydi — qarang: `whereEquals`).
 */
export async function listAudit(params: {
  tenantId?: string;
  limit?: number;
  before?: string;
}): Promise<AuditRow[]> {
  const limit = Math.min(Math.max(params.limit ?? 50, 1), 200);
  const ref = db().ref('admin_audit');

  let raw: Record<string, AuditEntry>;
  if (params.tenantId) {
    raw = await whereEquals<AuditEntry>(ref, 'tenantId', params.tenantId, limit);
  } else {
    const byKey = ref.orderByKey();
    const snap = await (params.before ? byKey.endBefore(params.before) : byKey).limitToLast(limit).get();
    raw = (snap.val() ?? {}) as Record<string, AuditEntry>;
  }

  return Object.entries(raw)
    .map(([id, e]) => ({ id, ...e }))
    .sort((a, b) => (a.id < b.id ? 1 : -1));
}
