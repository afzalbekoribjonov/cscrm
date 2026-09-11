import { createHmac, timingSafeEqual } from 'node:crypto';

import plansData from '../data/plans.json' with { type: 'json' };
import { env } from '../config/env.js';
import { db } from '../lib/firebase.js';
import type {
  License,
  LicenseState,
  LicenseStatusPayload,
  Plan,
  SignedLicenseStatus,
} from '../types/license.js';

export const PLANS: Plan[] = plansData.plans as Plan[];
/**
 * Obuna tugagach beriladigan qo'shimcha kunlar.
 *
 * HOZIR 0 — ya'ni qo'shimcha vaqt BERILMAYDI: muddat tugagan lahzadan
 * ilova bloklanadi. Qiymat sozlamada qolgani bejiz emas: pastdagi kod
 * noldan katta qiymat uchun ham to'g'ri ishlaydi, shuning uchun fikr
 * o'zgarsa bitta raqamni almashtirish yetadi.
 */
export const GRACE_DAYS: number = plansData.grace.days;

/**
 * Bir umrlik rejadagi yillik baza to'lovi uchun alohida muddat.
 *
 * Obunanikidan ATAYLAB ajratilgan. Bu ikki holat bir xil emas: obuna
 * — muddatli ijara, bir umrlik esa to'liq to'langan litsenziya.
 * Ikkinchisini yillik to'lov sanasi o'tgan zahoti bloklash — mutlaqo
 * boshqa qaror, va uni obuna qoidasi bilan birga jimgina o'zgartirib
 * yuborish noto'g'ri bo'lardi.
 */
export const LIFETIME_FEE_GRACE_DAYS: number =
  plansData.grace.lifetimeAnnualFeeDays;
export const WARN_BEFORE_DAYS: number[] = plansData.warnBeforeDays;

const DAY_MS = 24 * 60 * 60 * 1000;

/** Ilova javobni qancha vaqt oflayn ishlata oladi. */
const TTL_SECONDS = 6 * 60 * 60; // 6 soat

export function findPlan(planId: string): Plan | undefined {
  return PLANS.find((p) => p.id === planId);
}

/** Reja boshlanish vaqtidan tugash vaqtini hisoblaydi. */
export function computeExpiry(plan: Plan, startedAt: number): number | null {
  if (plan.kind === 'lifetime') return null;
  if (plan.days) return startedAt + plan.days * DAY_MS;
  if (plan.months) {
    const d = new Date(startedAt);
    d.setMonth(d.getMonth() + plan.months);
    return d.getTime();
  }
  return startedAt;
}

/**
 * Litsenziya holatini SERVER VAQTI bo'yicha aniqlaydi.
 *
 * Ajratilgan sof funksiya - test yozish oson va vaqt hech qayerdan
 * "yashirincha" olinmaydi (`now` doim tashqaridan beriladi).
 */
export function evaluate(license: License, now: number): LicenseStatusPayload {
  const base = {
    tenantId: license.tenantId,
    planId: license.planId,
    kind: license.kind,
    expiresAt: license.expiresAt,
    checkedAt: now,
    ttlSeconds: TTL_SECONDS,
  };

  if (license.suspended) {
    return {
      ...base,
      state: 'suspended',
      daysLeft: null,
      blocked: true,
      message:
        license.suspendedReason?.trim() ||
        'Hisobingiz vaqtincha to\'xtatilgan. Yordam xizmatiga murojaat qiling.',
    };
  }

  // --- Bir umrlik ---
  if (license.kind === 'lifetime') {
    const feeAt = license.nextAnnualFeeAt ?? null;
    if (feeAt !== null && now > feeAt + LIFETIME_FEE_GRACE_DAYS * DAY_MS) {
      return {
        ...base,
        state: 'lifetime_fee_due',
        daysLeft: Math.ceil((feeAt - now) / DAY_MS),
        blocked: true,
        message:
          'Ma\'lumotlar bazasi uchun yillik to\'lov muddati o\'tdi. '
          + 'Ilovadan foydalanishni davom ettirish uchun to\'lovni amalga oshiring.',
      };
    }
    if (feeAt !== null && now > feeAt) {
      return {
        ...base,
        state: 'lifetime_fee_due',
        daysLeft: Math.ceil((feeAt - now) / DAY_MS),
        blocked: false,
        message:
          'Yillik baza to\'lovi muddati keldi. '
          + `${LIFETIME_FEE_GRACE_DAYS} kun ichida to'lanmasa, ilova bloklanadi.`,
      };
    }
    return {
      ...base,
      state: 'active',
      daysLeft: feeAt === null ? null : Math.ceil((feeAt - now) / DAY_MS),
      blocked: false,
      message: 'Bir umrlik litsenziya faol.',
    };
  }

  // --- Muddatli obuna / sinov ---
  const expiresAt = license.expiresAt;
  if (expiresAt === null) {
    // Ma'lumot buzilgan - xavfsiz tomonga og'amiz (bloklaymiz), lekin
    // sababi tushunarli bo'lsin.
    return {
      ...base,
      state: 'expired',
      daysLeft: null,
      blocked: true,
      message: 'Obuna muddati aniqlanmadi. Yordam xizmatiga murojaat qiling.',
    };
  }

  const daysLeft = Math.ceil((expiresAt - now) / DAY_MS);

  // HOZIRGI QOIDA: qo'shimcha vaqt yo'q (`GRACE_DAYS` = 0) — muddat
  // tugagan lahzadan ilova bloklanadi.
  //
  // Sinovga esa u qanday bo'lganda ham berilmaydi: qo'shimcha kunlar
  // "pulini to'lab yurgan mijoz muddatni o'tkazib yuborsa ishi
  // to'xtamasin" degan qoida edi, sinovda esa hech kim hech narsa
  // to'lamagan. Bu shart `GRACE_DAYS` qaytadan yoqilsa kerak bo'ladi,
  // shuning uchun joyida qoldirilgan.
  const graceDays = license.kind === 'trial' ? 0 : GRACE_DAYS;
  const graceEnd = expiresAt + graceDays * DAY_MS;

  if (now > graceEnd) {
    return {
      ...base,
      state: 'expired',
      daysLeft,
      blocked: true,
      message:
        'Obuna muddati tugagan. Davom ettirish uchun to\'lovni amalga oshiring.',
    };
  }

  if (now > expiresAt) {
    // `graceDays` = 0 bo'lganda bu shoxga UMUMAN tushilmaydi:
    // yuqoridagi `now > graceEnd` allaqachon bloklagan bo'ladi.
    // Hozirgi sozlamada aynan shunday. Shox saqlanib turibdi, chunki
    // qo'shimcha kunlar qaytarilsa mantiq shu yerda.
    const graceLeft = Math.ceil((graceEnd - now) / DAY_MS);
    return {
      ...base,
      state: 'grace',
      daysLeft,
      blocked: false,
      message:
        `Obuna muddati tugadi. Ilova yana ${graceLeft} kun ishlaydi — `
        + 'shu vaqt ichida to\'lovni amalga oshiring.',
    };
  }

  const state: LicenseState =
    daysLeft <= Math.max(...WARN_BEFORE_DAYS) ? 'expiring' : 'active';

  return {
    ...base,
    state,
    daysLeft,
    blocked: false,
    message:
      state === 'expiring'
        ? `Obuna muddati tugashiga ${daysLeft} kun qoldi.`
        : 'Obuna faol.',
  };
}

// --- Imzo ---

/**
 * Payload'ni imzolaydi. Kalitlar tartibi doim bir xil bo'lishi uchun
 * `JSON.stringify` emas, aniq tartibda yig'ilgan matn imzolanadi -
 * aks holda ilova va server turli natija olishi mumkin.
 */
function canonical(payload: LicenseStatusPayload): string {
  return [
    payload.tenantId,
    payload.state,
    payload.planId,
    payload.kind,
    payload.expiresAt ?? '',
    payload.daysLeft ?? '',
    payload.checkedAt,
    payload.ttlSeconds,
    payload.blocked ? '1' : '0',
  ].join('|');
}

export function sign(payload: LicenseStatusPayload): string {
  return createHmac('sha256', env.LICENSE_SIGNING_SECRET)
    .update(canonical(payload))
    .digest('base64url');
}

export function verify(payload: LicenseStatusPayload, signature: string): boolean {
  const expected = Buffer.from(sign(payload));
  const given = Buffer.from(signature);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

export function signed(payload: LicenseStatusPayload): SignedLicenseStatus {
  return { payload, signature: sign(payload) };
}

// --- Ma'lumotlar bazasi ---

/** Tenant litsenziyasini o'qiydi. Topilmasa `null`. */
export async function loadLicense(tenantId: string): Promise<License | null> {
  const snap = await db().ref(`tenants/${tenantId}/license`).get();
  if (!snap.exists()) return null;
  return { tenantId, ...(snap.val() as Omit<License, 'tenantId'>) };
}
