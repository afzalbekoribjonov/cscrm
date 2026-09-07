import { db } from '../lib/firebase.js';
import { ApiError } from '../middleware/error.js';
import type { TenantProfile } from '../types/tenant.js';
import { findPlanWithPrice } from './plan-prices.js';

/**
 * To'lov so'rovi — "men to'ladim, tekshiring".
 *
 * To'lov usuli qo'lda karta o'tkazma, ya'ni bank bizga hech narsa
 * aytmaydi. Shu sabab mijoz o'zi xabar berishi kerak — aks holda
 * super-admin har bir o'tkazmani bank ilovasidan qo'lda topib, qaysi
 * biznesniki ekanini taxmin qilishi kerak bo'lardi.
 *
 * IKKI JOYGA yoziladi:
 *  * `/tenants/{id}/payment_requests/{reqId}` — biznesning o'z tarixi
 *    (ilova shu yerdan "so'rovingiz kutilmoqda" deb ko'rsatadi)
 *  * `/pending_payments/{reqId}` — super-admin navbati. Faqat HAL
 *    QILINMAGANLARI turadi va hal bo'lishi bilan O'CHIRILADI, shuning
 *    uchun bu tugun hech qachon kattalashmaydi.
 */

export type PaymentRequestStatus = 'pending' | 'approved' | 'rejected';

export interface PaymentRequestRecord {
  planId: string;
  planName: string;
  /** Mijoz aytgan summa. */
  amount: number;
  /** O'tkazma raqami yoki chek raqami — bank bilan solishtirish uchun. */
  reference?: string;
  note?: string;
  createdAt: number;
  createdBy: string;
  status: PaymentRequestStatus;
  resolvedAt?: number;
  resolvedBy?: string;
  /** Rad etilgan bo'lsa — sababi (mijozga ko'rsatiladi). */
  rejectReason?: string;
}

/** Super-admin navbatidagi yozuv — tenant nomi bilan birga. */
export interface PendingPayment extends PaymentRequestRecord {
  id: string;
  tenantId: string;
  tenantName: string;
}

const MAX_REFERENCE = 120;
const MAX_NOTE = 500;

function pendingRef() {
  return db().ref('pending_payments');
}

/** Shu biznesning hal qilinmagan so'rovi bormi. */
export async function findPendingFor(tenantId: string): Promise<string | null> {
  const snap = await pendingRef()
    .orderByChild('tenantId')
    .equalTo(tenantId)
    .get();
  if (!snap.exists()) return null;
  const [first] = Object.keys(snap.val() as Record<string, unknown>);
  return first ?? null;
}

export async function submitPaymentRequest(params: {
  tenantId: string;
  planId: string;
  amount?: number;
  reference?: string;
  note?: string;
  uid: string;
  now: number;
}): Promise<{ requestId: string; request: PaymentRequestRecord }> {
  const plan = await findPlanWithPrice(params.planId);
  if (!plan) throw ApiError.badRequest('Bunday reja topilmadi.');
  if (plan.kind === 'trial') {
    throw ApiError.badRequest('Sinov muddati uchun to\'lov qilinmaydi.');
  }

  // Bitta vaqtda bitta so'rov. Bu ham tartib uchun, ham navbatni
  // takroriy so'rovlar bilan to'ldirib yuborishning oldini oladi.
  if (await findPendingFor(params.tenantId)) {
    throw ApiError.badRequest(
      'Oldingi so\'rovingiz hali ko\'rib chiqilmoqda. Biroz kuting.',
    );
  }

  const profileSnap = await db()
    .ref(`tenants/${params.tenantId}/profile`)
    .get();
  if (!profileSnap.exists()) throw ApiError.notFound('Biznes topilmadi.');
  const tenantName = (profileSnap.val() as TenantProfile).name;

  const reference = params.reference?.trim().slice(0, MAX_REFERENCE);
  const note = params.note?.trim().slice(0, MAX_NOTE);

  const request: PaymentRequestRecord = {
    planId: plan.id,
    planName: plan.name,
    amount: params.amount ?? plan.price,
    createdAt: params.now,
    createdBy: params.uid,
    status: 'pending',
    ...(reference ? { reference } : {}),
    ...(note ? { note } : {}),
  };

  const requestId = pendingRef().push().key!;

  await db().ref().update({
    [`tenants/${params.tenantId}/payment_requests/${requestId}`]: request,
    [`pending_payments/${requestId}`]: {
      ...request,
      tenantId: params.tenantId,
      tenantName,
    },
  });

  return { requestId, request };
}

/**
 * Biznesning oxirgi so'rovi — ilovadagi to'lov ekrani uchun.
 *
 * Tugun kichik (yiliga bir necha yozuv), shuning uchun to'liq o'qiladi.
 */
export async function latestPaymentRequest(
  tenantId: string,
): Promise<(PaymentRequestRecord & { id: string }) | null> {
  const snap = await db().ref(`tenants/${tenantId}/payment_requests`).get();
  if (!snap.exists()) return null;

  const rows = Object.entries(
    snap.val() as Record<string, PaymentRequestRecord>,
  ).map(([id, r]) => ({ id, ...r }));

  rows.sort((a, b) => b.createdAt - a.createdAt);
  return rows[0] ?? null;
}

/** Super-admin navbati — faqat hal qilinmaganlar. */
export async function listPendingPayments(): Promise<PendingPayment[]> {
  const snap = await pendingRef().get();
  if (!snap.exists()) return [];

  return Object.entries(snap.val() as Record<string, Omit<PendingPayment, 'id'>>)
    .map(([id, r]) => ({ id, ...r }))
    .sort((a, b) => a.createdAt - b.createdAt);
}

/**
 * So'rovni yopadi: tarixdagi holatini yangilaydi va navbatdan olib
 * tashlaydi. Tasdiqlash `confirmPayment` ichidan chaqiriladi.
 */
export function resolveUpdates(params: {
  tenantId: string;
  requestId: string;
  status: Extract<PaymentRequestStatus, 'approved' | 'rejected'>;
  byUid: string;
  now: number;
  rejectReason?: string;
}): Record<string, unknown> {
  const base = `tenants/${params.tenantId}/payment_requests/${params.requestId}`;
  return {
    [`${base}/status`]: params.status,
    [`${base}/resolvedAt`]: params.now,
    [`${base}/resolvedBy`]: params.byUid,
    [`${base}/rejectReason`]: params.rejectReason ?? null,
    [`pending_payments/${params.requestId}`]: null,
  };
}

export async function rejectPaymentRequest(params: {
  tenantId: string;
  requestId: string;
  reason: string;
  byUid: string;
  now: number;
}): Promise<void> {
  const ref = db().ref(
    `tenants/${params.tenantId}/payment_requests/${params.requestId}`,
  );
  const snap = await ref.get();
  if (!snap.exists()) throw ApiError.notFound('So\'rov topilmadi.');

  const current = snap.val() as PaymentRequestRecord;
  if (current.status !== 'pending') {
    throw ApiError.badRequest('Bu so\'rov allaqachon ko\'rib chiqilgan.');
  }

  await db().ref().update(
    resolveUpdates({
      tenantId: params.tenantId,
      requestId: params.requestId,
      status: 'rejected',
      byUid: params.byUid,
      now: params.now,
      rejectReason: params.reason,
    }),
  );
}
