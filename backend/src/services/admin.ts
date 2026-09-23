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

/**
 * Barcha bizneslarning qisqa yozuvi (profil + obuna) — har biri
 * alohida kichik o'qish, parallel. Ro'yxat va "Umumiy" sahifasi shuni
 * ishlatadi.
 */
export async function loadTenantRows(
  now: number,
): Promise<{ summary: TenantSummary; license: Omit<License, 'tenantId'> }[]> {
  const ids = await tenantIds();
  const rows = await Promise.all(ids.map((id) => readSummary(id, now)));
  return rows.filter((r): r is NonNullable<typeof r> => r !== null);
}

/** Barcha bizneslar va ularning obuna holati. */
export async function listTenants(now: number): Promise<TenantSummary[]> {
  const result = (await loadTenantRows(now)).map((r) => r.summary);

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
 * So'rov holatini "tasdiqlangan" deb BAND QILADI — tranzaksiya ichida.
 *
 * NEGA KERAK. Bir so'rovni ikki marta tasdiqlash mumkin edi: panel
 * ikki oynada ochiq tursa, "To'lov so'rovlari" va biznes kartasidan
 * bir vaqtda bosilsa yoki javob kechikib, tugma qayta bosilsa. Har
 * safar obuna YANA uzayar va tushum YANA yozilardi.
 *
 * Tranzaksiya faqat bittasiga "pending → approved" o'tishga ruxsat
 * beradi, qolganlari rad etiladi.
 *
 * `null` holati: Admin SDK tranzaksiyani avval MAHALLIY nusxa bilan
 * chaqiradi — u hali yuklanmagan bo'lsa `null`. Shu yerda bekor qilsak
 * (`undefined`), server qiymati umuman tekshirilmay qolardi. `null`
 * qaytarilsa, server haqiqiy qiymat bilan qayta chaqiradi; haqiqatan
 * `null` bo'lsa — so'rov yo'q, natija `approved` bo'lmaydi.
 *
 * Sof funksiya — sinovda tekshiriladi.
 */
export function claimPendingStatus(current: unknown): unknown {
  if (current === null) return null;
  return current === 'pending' ? 'approved' : undefined;
}

/** Takrorlanmas kalit formati — baza kaliti bo'la oladigan belgilar. */
export const IDEMPOTENCY_KEY = /^[A-Za-z0-9_-]{8,64}$/;

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
  /**
   * Qo'lda tasdiqlashda panel beradigan takrorlanmas kalit. Xuddi shu
   * kalit bilan qayta kelgan so'rov yangi to'lov yaratmaydi — oldingi
   * natija qaytariladi.
   */
  idempotencyKey?: string;
  byUid: string;
  now: number;
}): Promise<{ license: License; payment: PaymentRecord; duplicate?: boolean }> {
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

  // Shu kalit bilan to'lov allaqachon yozilgan — takroriy bosish.
  if (params.idempotencyKey) {
    const existing = await db()
      .ref(`tenants/${params.tenantId}/payments/${params.idempotencyKey}`)
      .get();
    if (existing.exists()) {
      return {
        license: { tenantId: params.tenantId, ...current },
        payment: existing.val() as PaymentRecord,
        duplicate: true,
      };
    }
  }

  // So'rov ko'rsatilmagan bo'lsa ham, kutayotgani bo'lsa uni yopamiz.
  // Aks holda super-admin to'lovni oddiy tugma bilan tasdiqlaganda so'rov
  // navbatda abadiy qolib, mijozga "kutilmoqda" deb turaverardi.
  const requestId =
    params.requestId ?? (await findPendingFor(params.tenantId)) ?? undefined;

  // So'rov bor bo'lsa — uni avval band qilamiz. Bittadan ortiq tasdiq
  // shu yerda to'xtaydi, obunaga tegilmasdan. Bu ikkala yo'lni ham
  // qamraydi: so'rov sahifasidan tasdiqlash va qo'lda tasdiqlash bir
  // vaqtda bosilsa, faqat bittasi o'tadi.
  const statusRef = requestId
    ? db().ref(`tenants/${params.tenantId}/payment_requests/${requestId}/status`)
    : null;
  if (statusRef) {
    const claim = await statusRef.transaction(claimPendingStatus);
    if (!claim.committed || claim.snapshot.val() !== 'approved') {
      throw new ApiError(
        409,
        'Bu to\'lov so\'rovi allaqachon ko\'rib chiqilgan.',
        'already_resolved',
      );
    }
  }

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

  const paymentId =
    params.idempotencyKey ??
    db().ref(`tenants/${params.tenantId}/payments`).push().key!;
  const tenantName = profileSnap.exists()
    ? (profileSnap.val() as TenantProfile).name
    : params.tenantId;

  const updates = {
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
  };

  try {
    await db().ref().update(updates);
  } catch (err) {
    // So'rov band qilingan, lekin obuna yozilmadi — bandlikni qaytaramiz,
    // aks holda qayta urinish "allaqachon ko'rib chiqilgan" deb rad
    // etilardi va to'lov hech qachon tasdiqlanmasdi.
    if (statusRef) await statusRef.set('pending').catch(() => undefined);
    throw err;
  }

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
