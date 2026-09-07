import { db } from '../lib/firebase.js';
import { ApiError } from '../middleware/error.js';
import type { License, LicenseStatusPayload, Plan } from '../types/license.js';
import type { TenantProfile } from '../types/tenant.js';
import { computeExpiry, evaluate } from './license.js';
import { findPlanWithPrice } from './plan-prices.js';
import {
  findPendingFor,
  latestPaymentRequest,
  resolveUpdates,
  type PaymentRequestRecord,
} from './payment-request.js';

/**
 * Super-admin paneli uchun ma'lumot.
 *
 * MUHIM QOIDA: bu yerda HECH QACHON `tenants` tuguni butunlay o'qilmaydi.
 * RTDB'da tugunni o'qish uning BUTUN daraxtini yuklab olish demak — ya'ni
 * `ref('tenants').get()` har bir biznesning har bir buyurtmasi va tarixini
 * ham tortib olardi. Panel ochilganda butun baza yuklanishi kerak emas.
 *
 * Buning o'rniga `/tenant_directory` da faqat ID'lar ro'yxati turadi va
 * har bir biznesdan aynan kerakli kichik tugunlar o'qiladi.
 */

/** Ro'yxatdagi bitta biznes. */
export interface TenantSummary {
  tenantId: string;
  name: string;
  phone?: string;
  createdAt: number;
  status: LicenseStatusPayload;
}

export interface PaymentRecord {
  planId: string;
  planName: string;
  amount: number;
  confirmedBy: string;
  confirmedAt: number;
  note?: string;
  /** To'lovdan keyingi yangi muddat (ms) — bir umrlikda `null`. */
  newExpiresAt: number | null;
}

export interface TenantDetail extends TenantSummary {
  license: License;
  payments: (PaymentRecord & { id: string })[];
  employeeCount: number;
  orderCount: number;
  /** Ko'rib chiqilmagan yoki oxirgi to'lov so'rovi. */
  paymentRequest: (PaymentRequestRecord & { id: string }) | null;
}

export interface AdminStats {
  totalTenants: number;
  activeTenants: number;
  blockedTenants: number;
  trialTenants: number;
  lifetimeTenants: number;
  /** Oxirgi 30 kunda tasdiqlangan to'lovlar summasi. */
  revenue30d: number;
  /** Ko'rib chiqilmagan to'lov so'rovlari. */
  pendingPayments: number;
}

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Bizneslar ID'lari.
 *
 * Alohida tugun kerak, chunki RTDB Admin SDK'da "faqat kalitlarni ber"
 * (shallow) so'rovi yo'q — `tenants` ni o'qish butun bazani yuklardi.
 */
async function tenantIds(): Promise<string[]> {
  const snap = await db().ref('tenant_directory').get();
  if (!snap.exists()) return [];
  return Object.keys(snap.val() as Record<string, unknown>);
}

/** Biznes ro'yxatga tushishi uchun kerakli yozuv (ro'yxatdan o'tishda). */
export function directoryEntry(
  tenantId: string,
  createdAt: number,
): Record<string, unknown> {
  return { [`tenant_directory/${tenantId}`]: createdAt };
}

async function readSummary(
  tenantId: string,
  now: number,
): Promise<{ summary: TenantSummary; license: Omit<License, 'tenantId'> } | null> {
  const [profileSnap, licenseSnap] = await Promise.all([
    db().ref(`tenants/${tenantId}/profile`).get(),
    db().ref(`tenants/${tenantId}/license`).get(),
  ]);
  if (!profileSnap.exists() || !licenseSnap.exists()) return null;

  const profile = profileSnap.val() as TenantProfile;
  const license = licenseSnap.val() as Omit<License, 'tenantId'>;

  return {
    summary: {
      tenantId,
      name: profile.name,
      ...(profile.phone ? { phone: profile.phone } : {}),
      createdAt: profile.createdAt,
      status: evaluate({ tenantId, ...license }, now),
    },
    license,
  };
}

/** Barcha bizneslar va ularning obuna holati. */
export async function listTenants(now: number): Promise<TenantSummary[]> {
  const ids = await tenantIds();
  const rows = await Promise.all(ids.map((id) => readSummary(id, now)));

  const result = rows
    .filter((r): r is NonNullable<typeof r> => r !== null)
    .map((r) => r.summary);

  // Diqqat talab qiladiganlar tepada: bloklanganlar, keyin muddati
  // yaqinlar, keyin qolganlari.
  const weight = (t: TenantSummary) =>
    t.status.blocked ? 0 : t.status.state === 'active' ? 2 : 1;

  result.sort((a, b) => {
    const w = weight(a) - weight(b);
    if (w !== 0) return w;
    return (a.status.daysLeft ?? 1e9) - (b.status.daysLeft ?? 1e9);
  });

  return result;
}

export async function getTenant(
  tenantId: string,
  now: number,
): Promise<TenantDetail> {
  // Buyurtmalar va tarix ATAYLAB o'qilmaydi — ular cheksiz o'sadi.
  // Buyurtmalar soni hisoblagichdan olinadi (o'sha raqam ayni paytda
  // berilgan oxirgi buyurtma raqami).
  const [
    profileSnap,
    licenseSnap,
    paymentsSnap,
    employeesSnap,
    counterSnap,
    paymentRequest,
  ] = await Promise.all([
    db().ref(`tenants/${tenantId}/profile`).get(),
    db().ref(`tenants/${tenantId}/license`).get(),
    db().ref(`tenants/${tenantId}/payments`).get(),
    db().ref(`tenants/${tenantId}/employees`).get(),
    db().ref(`tenants/${tenantId}/counters/orderId`).get(),
    latestPaymentRequest(tenantId),
  ]);

  if (!profileSnap.exists() || !licenseSnap.exists()) {
    throw ApiError.notFound('Biznes topilmadi.');
  }

  const profile = profileSnap.val() as TenantProfile;
  const license: License = {
    tenantId,
    ...(licenseSnap.val() as Omit<License, 'tenantId'>),
  };

  const payments = paymentsSnap.exists()
    ? Object.entries(paymentsSnap.val() as Record<string, PaymentRecord>)
        .map(([id, p]) => ({ id, ...p }))
        .sort((a, b) => b.confirmedAt - a.confirmedAt)
    : [];

  return {
    tenantId,
    name: profile.name,
    ...(profile.phone ? { phone: profile.phone } : {}),
    createdAt: profile.createdAt,
    status: evaluate(license, now),
    license,
    payments,
    employeeCount: employeesSnap.exists()
      ? Object.keys(employeesSnap.val() as Record<string, unknown>).length
      : 0,
    orderCount: (counterSnap.val() as number | null) ?? 0,
    paymentRequest,
  };
}

/**
 * Yangi muddatni hisoblaydi.
 *
 * Muddat hali tugamagan bo'lsa YANGI muddat mavjudining ustiga qo'shiladi
 * (oldindan to'lagan mijoz kunini yo'qotmasligi kerak). Tugagan bo'lsa —
 * bugundan boshlanadi.
 *
 * Sof funksiya: test qilinadi, hech qanday bazaga tegmaydi.
 */
export function computeRenewal(
  plan: Plan,
  currentExpiresAt: number | null,
  now: number,
): { startedAt: number; expiresAt: number | null; nextAnnualFeeAt: number | null } {
  if (plan.kind === 'lifetime') {
    // Bir umrlik: muddat yo'q, lekin yillik baza to'lovi bor.
    const next = new Date(now);
    next.setFullYear(next.getFullYear() + 1);
    return { startedAt: now, expiresAt: null, nextAnnualFeeAt: next.getTime() };
  }

  const base =
    currentExpiresAt !== null && currentExpiresAt > now ? currentExpiresAt : now;

  return {
    startedAt: now,
    expiresAt: computeExpiry(plan, base),
    nextAnnualFeeAt: null,
  };
}

/**
 * To'lovni tasdiqlaydi va obunani uzaytiradi.
 *
 * To'lov usuli qo'lda (karta o'tkazma), shuning uchun tasdiqlashni
 * super-admin bajaradi. Har bir tasdiq ikki joyga yoziladi: biznesning
 * o'z tarixiga va umumiy `payments_log` ga. Ikkinchisi daromad
 * statistikasi uchun — u `at` bo'yicha indekslangan, ya'ni "oxirgi 30
 * kun" so'rovi butun tarixni emas, faqat kerakli qismini o'qiydi.
 */
export async function confirmPayment(params: {
  tenantId: string;
  planId: string;
  amount?: number;
  note?: string;
  /** Mijoz yuborgan so'rov asosida tasdiqlanayotgan bo'lsa — uning ID'si. */
  requestId?: string;
  byUid: string;
  now: number;
}): Promise<{ license: License; payment: PaymentRecord }> {
  // Narx bazadagi JORIY qiymat bilan olinadi - summa ko'rsatilmasa
  // o'sha yoziladi, ya'ni panelda o'zgartirilgan narx amal qiladi.
  const plan = await findPlanWithPrice(params.planId);
  if (!plan) throw ApiError.badRequest('Bunday reja topilmadi.');
  if (plan.kind === 'trial') {
    throw ApiError.badRequest('Sinov muddatini qo\'lda berib bo\'lmaydi.');
  }

  const [licenseSnap, profileSnap] = await Promise.all([
    db().ref(`tenants/${params.tenantId}/license`).get(),
    db().ref(`tenants/${params.tenantId}/profile`).get(),
  ]);
  if (!licenseSnap.exists()) throw ApiError.notFound('Biznes topilmadi.');

  const current = licenseSnap.val() as Omit<License, 'tenantId'>;
  const renewal = computeRenewal(plan, current.expiresAt, params.now);

  const license: License = {
    tenantId: params.tenantId,
    planId: plan.id,
    kind: plan.kind,
    startedAt: renewal.startedAt,
    expiresAt: renewal.expiresAt,
    nextAnnualFeeAt: renewal.nextAnnualFeeAt,
    // To'lov qabul qilindi - to'xtatilgan bo'lsa ochiladi.
    suspended: false,
    suspendedReason: null,
  };

  const payment: PaymentRecord = {
    planId: plan.id,
    planName: plan.name,
    amount: params.amount ?? plan.price,
    confirmedBy: params.byUid,
    confirmedAt: params.now,
    ...(params.note ? { note: params.note } : {}),
    newExpiresAt: renewal.expiresAt,
  };

  const paymentId = db().ref(`tenants/${params.tenantId}/payments`).push().key!;
  const tenantName = profileSnap.exists()
    ? (profileSnap.val() as TenantProfile).name
    : params.tenantId;

  // So'rov ko'rsatilmagan bo'lsa ham, kutayotgani bo'lsa uni yopamiz.
  // Aks holda super-admin to'lovni oddiy tugma bilan tasdiqlaganda so'rov
  // navbatda abadiy qolib, mijozga "kutilmoqda" deb turaverardi.
  const requestId =
    params.requestId ?? (await findPendingFor(params.tenantId)) ?? undefined;

  await db().ref().update({
    [`tenants/${params.tenantId}/license`]: {
      planId: license.planId,
      kind: license.kind,
      startedAt: license.startedAt,
      expiresAt: license.expiresAt,
      nextAnnualFeeAt: license.nextAnnualFeeAt,
      suspended: false,
      suspendedReason: null,
    },
    [`tenants/${params.tenantId}/payments/${paymentId}`]: payment,
    [`payments_log/${paymentId}`]: {
      tenantId: params.tenantId,
      tenantName,
      planId: plan.id,
      planName: plan.name,
      amount: payment.amount,
      at: params.now,
    },
    ...(requestId
      ? resolveUpdates({
          tenantId: params.tenantId,
          requestId,
          status: 'approved',
          byUid: params.byUid,
          now: params.now,
        })
      : {}),
  });

  return { license, payment };
}

/** Biznesni to'xtatadi yoki qayta yoqadi. */
export async function setSuspended(
  tenantId: string,
  suspended: boolean,
  reason: string | null,
): Promise<void> {
  const ref = db().ref(`tenants/${tenantId}/license`);
  if (!(await ref.get()).exists()) throw ApiError.notFound('Biznes topilmadi.');

  await ref.update({
    suspended,
    suspendedReason: suspended ? reason : null,
  });
}

export async function getStats(now: number): Promise<AdminStats> {
  const monthAgo = now - 30 * DAY_MS;

  const [ids, revenueSnap, pendingSnap] = await Promise.all([
    tenantIds(),
    // `at` bo'yicha indekslangan — butun to'lovlar tarixi emas, faqat
    // oxirgi 30 kunlik qismi o'qiladi.
    db().ref('payments_log').orderByChild('at').startAt(monthAgo).get(),
    db().ref('pending_payments').get(),
  ]);

  const stats: AdminStats = {
    totalTenants: 0,
    activeTenants: 0,
    blockedTenants: 0,
    trialTenants: 0,
    lifetimeTenants: 0,
    revenue30d: 0,
    pendingPayments: pendingSnap.exists()
      ? Object.keys(pendingSnap.val() as Record<string, unknown>).length
      : 0,
  };

  const rows = await Promise.all(ids.map((id) => readSummary(id, now)));
  for (const row of rows) {
    if (!row) continue;
    stats.totalTenants += 1;
    if (row.summary.status.blocked) stats.blockedTenants += 1;
    else stats.activeTenants += 1;
    if (row.license.kind === 'trial') stats.trialTenants += 1;
    if (row.license.kind === 'lifetime') stats.lifetimeTenants += 1;
  }

  if (revenueSnap.exists()) {
    for (const entry of Object.values(
      revenueSnap.val() as Record<string, { amount?: number }>,
    )) {
      stats.revenue30d += entry.amount ?? 0;
    }
  }

  return stats;
}
