import { env } from '../config/env.js';
import { db } from '../lib/firebase.js';
import type { LicenseState, PlanKind } from '../types/license.js';
import { loadUserActivity, summarizeActivity } from './activity.js';
import { loadArchives, loadTenantRows } from './admin.js';
import { listPendingPayments } from './payment-request.js';

/**
 * Super-admin "Umumiy" sahifasi — BITTA so'rovda.
 *
 * Qoida: bu yerdagi har bir raqam bazadagi haqiqiy yozuvdan
 * hisoblanadi. Taxminiy, "chiroyli" yoki to'ldiruvchi qiymat yo'q:
 * ma'lumot bo'lmasa — 0 yoki `null`, sahifa esa buni ochiq aytadi.
 *
 * Vaqt TOSHKENT bo'yicha (UTC+5, yozgi vaqt yo'q). Server Singapurda
 * turadi, lekin "bugun" va "bu oy" mijozlarimiz uchun hisoblanadi —
 * aks holda Toshkentda kechki 19:00 dan keyingi to'lov ertangi kunga
 * tushib qolardi.
 */

export type OverviewRange = '7d' | '30d' | '90d' | '12m';
export const OVERVIEW_RANGES: readonly OverviewRange[] = ['7d', '30d', '90d', '12m'];

const DAY = 86_400_000;
const TZ_OFFSET = 5 * 3_600_000;
const ACTIVE_WINDOW = 7 * DAY;
const LIST_LIMIT = 6;

/* ------------------------------------------------------------------ */
/* Vaqt kesimlari                                                      */
/* ------------------------------------------------------------------ */

/** Toshkent bo'yicha kun boshi (UTC ms). */
export function localDayStart(t: number): number {
  return Math.floor((t + TZ_OFFSET) / DAY) * DAY - TZ_OFFSET;
}

function localMonthStart(t: number, monthsBack = 0): number {
  const d = new Date(t + TZ_OFFSET);
  return Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - monthsBack, 1) - TZ_OFFSET;
}

/**
 * Chart ustunlarining boshlanish vaqtlari va oldingi davr boshi.
 *
 *   7d  — 7 kun, kunlik       30d — 30 kun, kunlik
 *   90d — 13 hafta (dushanbadan)   12m — 12 oy
 *
 * Oxirgi ustun JORIY (tugallanmagan) kun/hafta/oy.
 */
export function buildBuckets(
  range: OverviewRange,
  now: number,
): { starts: number[]; prevStart: number } {
  const today = localDayStart(now);

  if (range === '7d' || range === '30d') {
    const n = range === '7d' ? 7 : 30;
    const first = today - (n - 1) * DAY;
    return {
      starts: Array.from({ length: n }, (_, i) => first + i * DAY),
      prevStart: first - n * DAY,
    };
  }

  if (range === '90d') {
    const weekday = new Date(today + TZ_OFFSET).getUTCDay(); // 0 — yakshanba
    const monday = today - ((weekday + 6) % 7) * DAY;
    const n = 13;
    const first = monday - (n - 1) * 7 * DAY;
    return {
      starts: Array.from({ length: n }, (_, i) => first + i * 7 * DAY),
      prevStart: first - n * 7 * DAY,
    };
  }

  // 12 oy — oylar uzunligi har xil, shuning uchun har biri alohida.
  return {
    starts: Array.from({ length: 12 }, (_, i) => localMonthStart(now, 11 - i)),
    prevStart: localMonthStart(now, 23),
  };
}

/** Vaqt qaysi ustunga tushadi; davrdan tashqarida bo'lsa -1. */
export function bucketIndex(starts: number[], t: number, now: number): number {
  if (starts.length === 0 || t < starts[0]! || t > now) return -1;
  let lo = 0;
  let hi = starts.length - 1;
  while (lo < hi) {
    const mid = Math.ceil((lo + hi) / 2);
    if (starts[mid]! <= t) lo = mid;
    else hi = mid - 1;
  }
  return lo;
}

/* ------------------------------------------------------------------ */
/* Sof yig'uvchi                                                       */
/* ------------------------------------------------------------------ */

export interface TenantInput {
  tenantId: string;
  name: string;
  createdAt: number;
  state: LicenseState;
  kind: PlanKind;
  blocked: boolean;
  daysLeft: number | null;
}

export interface PaymentInput {
  id: string;
  tenantId: string;
  tenantName: string;
  planName: string;
  amount: number;
  at: number;
}

export interface PendingInput {
  id: string;
  tenantId: string;
  tenantName: string;
  amount: number;
  createdAt: number;
}

/** Obuna holati — chartdagi 4 guruh. Har bir biznes AYNAN bittasiga tushadi. */
export type SubscriptionGroup = 'active' | 'trial' | 'expiring' | 'blocked';

export function subscriptionGroup(t: Pick<TenantInput, 'blocked' | 'state' | 'kind'>): SubscriptionGroup {
  if (t.blocked) return 'blocked';
  if (t.state === 'expiring') return 'expiring';
  if (t.kind === 'trial') return 'trial';
  return 'active';
}

export type AttentionReason = 'pending_payment' | 'blocked' | 'expiring';

export interface AttentionItem {
  tenantId: string;
  name: string;
  reason: AttentionReason;
  state: LicenseState;
  daysLeft: number | null;
  /** To'lov so'rovi uchun — mijoz aytgan summa. */
  amount?: number;
  /** Tartiblash va "qachondan beri" uchun. */
  at?: number;
}

export interface Overview {
  range: OverviewRange;
  generatedAt: number;
  period: { start: number; prevStart: number };
  revenue: { current: number; previous: number; count: number };
  registrations: { current: number; previous: number };
  /**
   * Guruhlar (chart uchun, har biznes bittasida) + kesishadigan sonlar:
   * `paid` — pullik va bloklanmagan (muddati yaqinlari ham), `onTrial` —
   * sinovda va bloklanmagan. "Faol obunalar" ko'rsatkichi `paid` dan.
   */
  tenants: Record<SubscriptionGroup, number> & { total: number; paid: number; onTrial: number };
  /** `null` — faollikni aniqlab bo'lmadi (sahifa buni ochiq aytadi). */
  activity: { activeTenants: number; activeUsers: number; totalUsers: number } | null;
  pendingPayments: number;
  series: { starts: number[]; revenue: number[]; registrations: number[] };
  attention: AttentionItem[];
  recentTenants: (Pick<TenantInput, 'tenantId' | 'name' | 'createdAt' | 'state' | 'kind'> & {
    lastActiveAt: number | null;
  })[];
  recentPayments: PaymentInput[];
}

/**
 * "Bugun kim bilan ishlash kerak" — muhimlik tartibida:
 *   1) to'lov so'rovi (mijoz to'lagan, tasdiq kutyapti — eng eskisi oldin);
 *   2) bloklangan (ishi to'xtagan);
 *   3) muddati yaqin (eng kami qolgan oldin).
 * Bir biznes ro'yxatda BIR marta — eng muhim sababi bilan.
 */
export function buildAttention(
  tenants: TenantInput[],
  pending: PendingInput[],
  limit = LIST_LIMIT,
): AttentionItem[] {
  const byId = new Map(tenants.map((t) => [t.tenantId, t]));
  const seen = new Set<string>();
  const items: AttentionItem[] = [];

  for (const p of [...pending].sort((a, b) => a.createdAt - b.createdAt)) {
    if (seen.has(p.tenantId)) continue;
    seen.add(p.tenantId);
    const t = byId.get(p.tenantId);
    items.push({
      tenantId: p.tenantId,
      name: t?.name ?? p.tenantName,
      reason: 'pending_payment',
      state: t?.state ?? 'expired',
      daysLeft: t?.daysLeft ?? null,
      amount: p.amount,
      at: p.createdAt,
    });
  }

  // Bloklanganlar: ENG YAQINDA bloklangan birinchi (daysLeft 0 ga eng
  // yaqini) — ular bilan hali gaplashib, qaytarib olish mumkin.
  // Muddatsiz bloklar (to'xtatilgan) oxirida.
  const blocked = tenants
    .filter((t) => t.blocked && !seen.has(t.tenantId))
    .sort((a, b) => (b.daysLeft ?? -1e9) - (a.daysLeft ?? -1e9));
  const expiring = tenants
    .filter((t) => !t.blocked && t.state === 'expiring' && !seen.has(t.tenantId))
    .sort((a, b) => (a.daysLeft ?? 1e9) - (b.daysLeft ?? 1e9));

  for (const t of blocked) {
    items.push({ tenantId: t.tenantId, name: t.name, reason: 'blocked', state: t.state, daysLeft: t.daysLeft });
  }
  for (const t of expiring) {
    items.push({ tenantId: t.tenantId, name: t.name, reason: 'expiring', state: t.state, daysLeft: t.daysLeft });
  }

  return items.slice(0, limit);
}

export function buildOverview(input: {
  range: OverviewRange;
  now: number;
  tenants: TenantInput[];
  /** `prevStart` dan hozirgacha bo'lgan to'lovlar. */
  payments: PaymentInput[];
  recentPayments: PaymentInput[];
  pending: PendingInput[];
  activity: ReturnType<typeof summarizeActivity> | null;
}): Overview {
  const { range, now, tenants, payments } = input;
  const { starts, prevStart } = buildBuckets(range, now);
  const start = starts[0]!;

  const revenue = new Array<number>(starts.length).fill(0);
  let revenueCurrent = 0;
  let revenuePrevious = 0;
  let paymentCount = 0;
  for (const p of payments) {
    const amount = Number.isFinite(p.amount) ? p.amount : 0;
    const i = bucketIndex(starts, p.at, now);
    if (i >= 0) {
      revenue[i]! += amount;
      revenueCurrent += amount;
      paymentCount += 1;
    } else if (p.at >= prevStart && p.at < start) {
      revenuePrevious += amount;
    }
  }

  const registrations = new Array<number>(starts.length).fill(0);
  let regPrevious = 0;
  const groups: Record<SubscriptionGroup, number> = { active: 0, trial: 0, expiring: 0, blocked: 0 };
  let paid = 0;
  let onTrial = 0;
  for (const t of tenants) {
    const i = bucketIndex(starts, t.createdAt, now);
    if (i >= 0) registrations[i]! += 1;
    else if (t.createdAt >= prevStart && t.createdAt < start) regPrevious += 1;
    groups[subscriptionGroup(t)] += 1;
    if (!t.blocked) {
      if (t.kind === 'trial') onTrial += 1;
      else paid += 1;
    }
  }

  const lastActive = input.activity?.lastActiveByTenant;

  return {
    range,
    generatedAt: now,
    period: { start, prevStart },
    revenue: { current: revenueCurrent, previous: revenuePrevious, count: paymentCount },
    registrations: {
      current: registrations.reduce((s, v) => s + v, 0),
      previous: regPrevious,
    },
    tenants: { ...groups, total: tenants.length, paid, onTrial },
    activity: input.activity
      ? {
          activeTenants: input.activity.activeTenants,
          activeUsers: input.activity.activeUsers,
          totalUsers: input.activity.totalUsers,
        }
      : null,
    pendingPayments: input.pending.length,
    series: { starts, revenue, registrations },
    attention: buildAttention(tenants, input.pending),
    recentTenants: [...tenants]
      .sort((a, b) => b.createdAt - a.createdAt)
      .slice(0, LIST_LIMIT)
      .map((t) => ({
        tenantId: t.tenantId,
        name: t.name,
        createdAt: t.createdAt,
        state: t.state,
        kind: t.kind,
        lastActiveAt: lastActive?.get(t.tenantId) ?? null,
      })),
    recentPayments: [...input.recentPayments].sort((a, b) => b.at - a.at).slice(0, LIST_LIMIT),
  };
}

/* ------------------------------------------------------------------ */
/* Bazadan o'qish                                                      */
/* ------------------------------------------------------------------ */

type LogEntry = { tenantId?: string; tenantName?: string; planName?: string; amount?: number; at?: number };

function toPayments(val: unknown): PaymentInput[] {
  if (!val || typeof val !== 'object') return [];
  return Object.entries(val as Record<string, LogEntry>).map(([id, p]) => ({
    id,
    tenantId: p.tenantId ?? '',
    tenantName: p.tenantName ?? '',
    planName: p.planName ?? '',
    amount: typeof p.amount === 'number' ? p.amount : 0,
    at: typeof p.at === 'number' ? p.at : 0,
  }));
}

/**
 * Barcha manbalar PARALLEL o'qiladi. `payments_log` indekslangan
 * (`at`) — faqat kerakli oraliq o'qiladi, butun tarix emas.
 */
export async function loadOverview(range: OverviewRange, now: number): Promise<Overview> {
  const { prevStart } = buildBuckets(range, now);

  const [allRows, archives, periodSnap, recentSnap, pending, activity] = await Promise.all([
    loadTenantRows(now),
    loadArchives(),
    db().ref('payments_log').orderByChild('at').startAt(prevStart).get(),
    db().ref('payments_log').orderByChild('at').limitToLast(LIST_LIMIT).get(),
    listPendingPayments(),
    // Faollik — qo'shimcha ma'lumot. Olinmasa sahifa baribir ochiladi.
    loadUserActivity(env.superAdminUids)
      .then((users) => summarizeActivity(users, now, ACTIVE_WINDOW))
      .catch(() => null),
  ]);

  // Arxivdagi bizneslar "Umumiy" hisobiga kirmaydi: ular o'chirilish
  // arafasida, "bloklangan — e'tibor bering" deb ko'rsatish chalg'itadi.
  const rows = allRows.filter((r) => !archives.has(r.summary.tenantId));

  return buildOverview({
    range,
    now,
    tenants: rows.map((r) => ({
      tenantId: r.summary.tenantId,
      name: r.summary.name,
      createdAt: r.summary.createdAt,
      state: r.summary.status.state,
      kind: r.summary.status.kind,
      blocked: r.summary.status.blocked,
      daysLeft: r.summary.status.daysLeft,
    })),
    payments: toPayments(periodSnap.val()),
    recentPayments: toPayments(recentSnap.val()),
    pending: pending.map((p) => ({
      id: p.id,
      tenantId: p.tenantId,
      tenantName: p.tenantName,
      amount: p.amount,
      createdAt: p.createdAt,
    })),
    activity,
  });
}
