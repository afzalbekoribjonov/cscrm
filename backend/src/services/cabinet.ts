import { auth, db } from '../lib/firebase.js';
import { staffUid } from '../lib/staff.js';
import { ApiError } from '../middleware/error.js';
import type { LicenseStatusPayload } from '../types/license.js';
import type { EmployeeRecord } from '../types/tenant.js';
import { lastActiveOf } from './activity.js';
import { evaluate, findPlan, loadLicense } from './license.js';
import { localDayStart } from './overview.js';

/**
 * Biznes egasining veb-kabineti — ilova ma'lumotidan hisob-kitob.
 *
 * Raqamlar ILOVADAGI hisobot bilan AYNAN bir xil qoidada hisoblanadi
 * (app/lib/utils/income_stats.dart): pul QAYSI KUNI olingan bo'lsa,
 * o'sha kunning daromadi —
 *  * yetkazishda olingan pul — yetkazilgan kunga (`deliveryPaidAmount`,
 *    eski yozuvlarda `paymentAmount`);
 *  * qarz to'lovlari — to'langan kunga, o'z usuli bilan
 *    (`order_history`, `type: 'debt_settled'`).
 * Vaqt — Toshkent kuni.
 *
 * Faqat O'QISH. Kabinet ilovadagi ma'lumotni o'zgartirmaydi.
 */

const DAY = 86_400_000;

/** Ilovadagi yorliqlar (app/lib/utils/delivery_stats.dart). */
export const CASH_LABEL = 'Naqd pul';
export const CARD_LABEL = 'Karta';

export type CabinetRange = 'today' | '7d' | '30d' | 'month';
export const CABINET_RANGES: readonly CabinetRange[] = ['today', '7d', '30d', 'month'];

export interface OrderInput {
  id: string;
  status?: string;
  createdAt?: number;
  deliveredAt?: number;
  paymentMethod?: string;
  paymentAmount?: number;
  deliveryPaidAmount?: number;
  debtAmount?: number;
  active?: boolean;
}

export interface HistoryInput {
  type?: string;
  at?: number;
  amount?: number;
  method?: string;
}

export interface ExpenseInput {
  amount?: number;
  spentAt?: number;
  createdAt?: number;
}

export interface Income {
  cash: number;
  card: number;
  other: number;
  /** Shu davrda qarz hisobiga tushgan pul (yuqoridagilar ichida). */
  debtPayments: number;
  total: number;
}

/**
 * Davr chegaralari (Toshkent kuni bo'yicha).
 *
 * `month` — joriy oy boshidan bugungacha; taqqoslash — o'tgan oyning
 * xuddi shuncha kuni (1–N). Boshqalari — shuncha kun va undan oldingi
 * xuddi shuncha kun.
 */
export function cabinetPeriod(range: CabinetRange, now: number): {
  start: number;
  end: number;
  prevStart: number;
  prevEnd: number;
  days: number;
} {
  const today = localDayStart(now);
  const end = today + DAY - 1;
  if (range === 'month') {
    const local = new Date(today + 5 * 3_600_000);
    const y = local.getUTCFullYear();
    const m = local.getUTCMonth();
    const start = Date.UTC(y, m, 1) - 5 * 3_600_000;
    const days = Math.round((today - start) / DAY) + 1;
    const prevStart = Date.UTC(y, m - 1, 1) - 5 * 3_600_000;
    const prevMonthDays = Math.round((start - prevStart) / DAY);
    const prevEnd = prevStart + Math.min(days, prevMonthDays) * DAY - 1;
    return { start, end, prevStart, prevEnd, days };
  }
  const days = range === 'today' ? 1 : range === '7d' ? 7 : 30;
  const start = today - (days - 1) * DAY;
  return { start, end, prevStart: start - days * DAY, prevEnd: start - 1, days };
}

const within = (t: number | undefined, start: number, end: number): t is number =>
  typeof t === 'number' && t >= start && t <= end;

/** Yetkazishda olingan pul — eski yozuvlarga chidamli. */
export function paidAtDelivery(o: OrderInput): number {
  return o.deliveryPaidAmount ?? o.paymentAmount ?? 0;
}

/** `incomeForRange` ning aynan nusxasi (app/lib/utils/income_stats.dart). */
export function incomeForRange(orders: OrderInput[], history: HistoryInput[], start: number, end: number): Income {
  let cash = 0;
  let card = 0;
  let other = 0;
  let debtPayments = 0;
  const add = (method: string | undefined, amount: number) => {
    if (!(amount > 0)) return;
    if (method === CASH_LABEL) cash += amount;
    else if (method === CARD_LABEL) card += amount;
    else other += amount;
  };

  for (const o of orders) {
    if (!within(o.deliveredAt, start, end)) continue;
    add(o.paymentMethod, paidAtDelivery(o));
  }
  for (const h of history) {
    if (h.type !== 'debt_settled' || !within(h.at, start, end)) continue;
    const amount = h.amount ?? 0;
    if (!(amount > 0)) continue;
    add(h.method, amount);
    debtPayments += amount;
  }
  return { cash, card, other, debtPayments, total: cash + card + other };
}

export function expensesForRange(expenses: ExpenseInput[], start: number, end: number): number {
  let total = 0;
  for (const e of expenses) {
    const at = e.spentAt ?? e.createdAt;
    if (within(at, start, end) && (e.amount ?? 0) > 0) total += e.amount!;
  }
  return total;
}

export interface CabinetSummary {
  range: CabinetRange;
  generatedAt: number;
  period: { start: number; end: number; prevStart: number; prevEnd: number };
  income: Income;
  previousIncome: number;
  expenses: number;
  previousExpenses: number;
  /** Tushum − chiqim. */
  profit: number;
  orders: {
    /** Davrda qabul qilingan. */
    created: number;
    previousCreated: number;
    /** Davrda topshirilgan. */
    delivered: number;
    /** Hozir ishda (topshirilmagan). */
    active: number;
    /** Hozir topshirishga tayyor. */
    readyToDeliver: number;
  };
  debt: { count: number; total: number };
  /** Kunlik: tushum va qabul qilingan buyurtmalar. */
  series: { starts: number[]; income: number[]; created: number[] };
}

/** Sof hisob — sinovda bazasiz tekshiriladi. */
export function buildCabinetSummary(input: {
  range: CabinetRange;
  now: number;
  ordersInPeriod: OrderInput[];
  activeOrders: OrderInput[];
  debtors: OrderInput[];
  history: HistoryInput[];
  expenses: ExpenseInput[];
}): CabinetSummary {
  const { range, now } = input;
  const p = cabinetPeriod(range, now);

  // Bir buyurtma bir nechta so'rovda chiqishi mumkin — ID bo'yicha bitta.
  const byId = new Map<string, OrderInput>();
  for (const o of [...input.ordersInPeriod, ...input.activeOrders]) byId.set(o.id, o);
  const orders = [...byId.values()];

  const income = incomeForRange(orders, input.history, p.start, p.end);
  const previousIncome = incomeForRange(orders, input.history, p.prevStart, p.prevEnd).total;
  const expenses = expensesForRange(input.expenses, p.start, p.end);
  const previousExpenses = expensesForRange(input.expenses, p.prevStart, p.prevEnd);

  const starts = Array.from({ length: p.days }, (_, i) => p.start + i * DAY);
  const series = {
    starts,
    income: starts.map((s) => incomeForRange(orders, input.history, s, s + DAY - 1).total),
    created: starts.map((s) => orders.filter((o) => within(o.createdAt, s, s + DAY - 1)).length),
  };

  const active = input.activeOrders.filter((o) => o.active !== false && o.status !== 'yetgazildi');
  const debtors = input.debtors.filter((o) => (o.debtAmount ?? 0) > 0);

  return {
    range,
    generatedAt: now,
    period: { start: p.start, end: p.end, prevStart: p.prevStart, prevEnd: p.prevEnd },
    income,
    previousIncome,
    expenses,
    previousExpenses,
    profit: income.total - expenses,
    orders: {
      created: orders.filter((o) => within(o.createdAt, p.start, p.end)).length,
      previousCreated: orders.filter((o) => within(o.createdAt, p.prevStart, p.prevEnd)).length,
      delivered: orders.filter((o) => within(o.deliveredAt, p.start, p.end)).length,
      active: active.length,
      readyToDeliver: active.filter((o) => o.status === 'yetgazishga_tayyor').length,
    },
    debt: { count: debtors.length, total: debtors.reduce((s, o) => s + (o.debtAmount ?? 0), 0) },
    series,
  };
}

/* ------------------------------------------------------------------ */
/* Bazadan o'qish                                                      */
/* ------------------------------------------------------------------ */

const ACTIVE_LIMIT = 1000;

/** Buyurtmadan faqat hisob uchun kerakli maydonlar — mijoz ma'lumoti olinmaydi. */
function pickOrder(id: string, v: Record<string, unknown>): OrderInput {
  const num = (k: string) => (typeof v[k] === 'number' ? (v[k] as number) : undefined);
  return {
    id,
    ...(typeof v.status === 'string' ? { status: v.status } : {}),
    ...(num('createdAt') !== undefined ? { createdAt: num('createdAt') } : {}),
    ...(num('deliveredAt') !== undefined ? { deliveredAt: num('deliveredAt') } : {}),
    ...(typeof v.paymentMethod === 'string' ? { paymentMethod: v.paymentMethod } : {}),
    ...(num('paymentAmount') !== undefined ? { paymentAmount: num('paymentAmount') } : {}),
    ...(num('deliveryPaidAmount') !== undefined ? { deliveryPaidAmount: num('deliveryPaidAmount') } : {}),
    ...(num('debtAmount') !== undefined ? { debtAmount: num('debtAmount') } : {}),
    ...(typeof v.active === 'boolean' ? { active: v.active } : {}),
  };
}

function rows<T>(val: unknown, map: (id: string, v: Record<string, unknown>) => T): T[] {
  if (!val || typeof val !== 'object') return [];
  return Object.entries(val as Record<string, unknown>)
    .filter(([, v]) => v && typeof v === 'object')
    .map(([id, v]) => map(id, v as Record<string, unknown>));
}

export async function loadCabinetSummary(tenantId: string, range: CabinetRange, now: number): Promise<CabinetSummary> {
  const p = cabinetPeriod(range, now);
  const base = `tenants/${tenantId}`;
  const orders = db().ref(`${base}/orders`);

  const [created, delivered, active, debtors, history, expenses] = await Promise.all([
    orders.orderByChild('createdAt').startAt(p.prevStart).endAt(p.end).get(),
    orders.orderByChild('deliveredAt').startAt(p.prevStart).endAt(p.end).get(),
    orders.orderByChild('active').equalTo(true).limitToLast(ACTIVE_LIMIT).get(),
    orders.orderByChild('debtAmount').startAt(0.01).get(),
    db().ref(`${base}/order_history`).orderByChild('at').startAt(p.prevStart).endAt(p.end).get(),
    db().ref(`${base}/expenses`).orderByChild('spentAt').startAt(p.prevStart).endAt(p.end).get(),
  ]);

  return buildCabinetSummary({
    range,
    now,
    ordersInPeriod: [...rows(created.val(), pickOrder), ...rows(delivered.val(), pickOrder)],
    activeOrders: rows(active.val(), pickOrder),
    debtors: rows(debtors.val(), pickOrder),
    history: rows(history.val(), (_id, v) => ({
      ...(typeof v.type === 'string' ? { type: v.type } : {}),
      ...(typeof v.at === 'number' ? { at: v.at } : {}),
      ...(typeof v.amount === 'number' ? { amount: v.amount } : {}),
      ...(typeof v.method === 'string' ? { method: v.method } : {}),
    })),
    expenses: rows(expenses.val(), (_id, v) => ({
      ...(typeof v.amount === 'number' ? { amount: v.amount } : {}),
      ...(typeof v.spentAt === 'number' ? { spentAt: v.spentAt } : {}),
      ...(typeof v.createdAt === 'number' ? { createdAt: v.createdAt } : {}),
    })),
  });
}

/* ------------------------------------------------------------------ */
/* Profil, xodimlar, to'lovlar                                         */
/* ------------------------------------------------------------------ */

export interface CabinetProfile {
  tenantId: string;
  name: string;
  phone: string | null;
  address: string | null;
  createdAt: number | null;
  login: string | null;
  status: LicenseStatusPayload;
  planName: string;
}

export async function loadCabinetProfile(params: {
  tenantId: string;
  email: string | undefined;
  now: number;
}): Promise<CabinetProfile> {
  const [profileSnap, license] = await Promise.all([
    db().ref(`tenants/${params.tenantId}/profile`).get(),
    loadLicense(params.tenantId),
  ]);
  if (!profileSnap.exists() || !license) throw ApiError.notFound('Biznes topilmadi.');
  const profile = profileSnap.val() as { name?: string; phone?: string; address?: string; createdAt?: number };
  const email = params.email ?? '';
  return {
    tenantId: params.tenantId,
    name: profile.name ?? '',
    phone: profile.phone ?? null,
    address: profile.address ?? null,
    createdAt: profile.createdAt ?? null,
    login: email.endsWith('@cscrm.local') ? email.slice(0, -'@cscrm.local'.length) : null,
    status: evaluate(license, params.now),
    planName: findPlan(license.planId)?.name ?? license.planId,
  };
}

export interface CabinetEmployee {
  id: string;
  name: string;
  phone: string;
  active: boolean;
  createdAt: number | null;
  lastActiveAt: number | null;
}

/** Xodimlar — faqat ko'rsatiladigan maydonlar; PIN va urinishlar soni yo'q. */
export async function loadCabinetEmployees(tenantId: string): Promise<CabinetEmployee[]> {
  const snap = await db().ref(`tenants/${tenantId}/employees`).get();
  const raw = (snap.val() ?? {}) as Record<string, EmployeeRecord>;
  const ids = Object.keys(raw);

  const lastActive = new Map<string, number | null>();
  for (let i = 0; i < ids.length; i += 100) {
    const res = await auth().getUsers(ids.slice(i, i + 100).map((id) => ({ uid: staffUid(tenantId, id) })));
    for (const u of res.users) lastActive.set(u.uid, lastActiveOf(u.metadata));
  }

  return ids
    .map((id) => {
      const e = raw[id]!;
      return {
        id,
        name: [e.firstName, e.lastName].filter(Boolean).join(' ').trim() || 'Xodim',
        phone: e.phone ?? '',
        active: e.active !== false,
        createdAt: typeof e.createdAt === 'number' ? e.createdAt : null,
        lastActiveAt: lastActive.get(staffUid(tenantId, id)) ?? null,
      };
    })
    .sort((a, b) => Number(b.active) - Number(a.active) || a.name.localeCompare(b.name, 'uz'));
}

export interface CabinetPayment {
  id: string;
  planName: string;
  amount: number;
  confirmedAt: number;
  newExpiresAt: number | null;
}

export async function loadCabinetPayments(tenantId: string): Promise<CabinetPayment[]> {
  const snap = await db().ref(`tenants/${tenantId}/payments`).get();
  return rows(snap.val(), (id, v) => ({
    id,
    planName: typeof v.planName === 'string' ? v.planName : String(v.planId ?? ''),
    amount: typeof v.amount === 'number' ? v.amount : 0,
    confirmedAt: typeof v.confirmedAt === 'number' ? v.confirmedAt : 0,
    newExpiresAt: typeof v.newExpiresAt === 'number' ? v.newExpiresAt : null,
  })).sort((a, b) => b.confirmedAt - a.confirmedAt);
}
