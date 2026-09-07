import { db } from '../lib/firebase.js';
import { ApiError } from '../middleware/error.js';
import type { Plan } from '../types/license.js';
import { PLANS } from './license.js';

/**
 * Reja NARXLARI bazada saqlanadi, fayl esa boshlang'ich qiymat beradi.
 *
 * Ilgari narx faqat `shared/plans.json` da edi — uni o'zgartirish uchun
 * kodni tahrirlab, qayta joylash kerak bo'lardi. Narx esa bozorga qarab
 * o'zgaradigan narsa, uni panelning o'zidan boshqarish kerak.
 *
 * FAQAT NARX bazadan olinadi. Reja tuzilishi (nomi, necha oy, turi)
 * faylda qoladi: u dasturning mantiqiga bog'liq — masalan "3 oylik"
 * rejaning oyi 3 emas 5 bo'lib qolsa, muddat hisobi buziladi. Narx esa
 * hech qanday mantiqni o'zgartirmaydi.
 */

export interface PlanOverride {
  price: number;
  lifetimeAnnualFeeUsd?: number;
  updatedAt: number;
  updatedBy: string;
}

const OVERRIDES_PATH = 'plan_prices';

/** Bazadagi narxlarni fayl qiymatlari ustiga qo'yadi. */
export function mergePrices(
  base: Plan[],
  overrides: Record<string, PlanOverride | undefined>,
): Plan[] {
  return base.map((plan) => {
    const o = overrides[plan.id];
    if (!o) return plan;

    return {
      ...plan,
      price: typeof o.price === 'number' && o.price >= 0 ? o.price : plan.price,
      ...(typeof o.lifetimeAnnualFeeUsd === 'number' &&
      o.lifetimeAnnualFeeUsd >= 0
        ? { lifetimeAnnualFeeUsd: o.lifetimeAnnualFeeUsd }
        : {}),
    };
  });
}

/**
 * Joriy narxlar bilan rejalar ro'yxati.
 *
 * Baza o'qilmasa fayl qiymatlari bilan davom etadi — narx ro'yxati
 * ko'rsatilmay qolgandan ko'ra eski narx ko'rsatilgani yaxshiroq.
 */
export async function plansWithPrices(): Promise<Plan[]> {
  try {
    const snap = await db().ref(OVERRIDES_PATH).get();
    if (!snap.exists()) return PLANS;
    return mergePrices(
      PLANS,
      snap.val() as Record<string, PlanOverride | undefined>,
    );
  } catch {
    return PLANS;
  }
}

/** Bitta rejani joriy narxi bilan qaytaradi. */
export async function findPlanWithPrice(
  planId: string,
): Promise<Plan | undefined> {
  const plans = await plansWithPrices();
  return plans.find((p) => p.id === planId);
}

/**
 * Narxni o'zgartiradi.
 *
 * Sinov rejasi ATAYLAB chetlanadi: u bepul bo'lishi kerak, narx
 * qo'yilsa "14 kun bepul" degan va'da yolg'onga aylanardi.
 */
export async function setPlanPrice(params: {
  planId: string;
  price: number;
  lifetimeAnnualFeeUsd?: number;
  byUid: string;
  now: number;
}): Promise<Plan> {
  const plan = PLANS.find((p) => p.id === params.planId);
  if (!plan) throw ApiError.badRequest('Bunday reja topilmadi.');
  if (plan.kind === 'trial') {
    throw ApiError.badRequest('Sinov muddati bepul — unga narx qo\'yilmaydi.');
  }
  if (!Number.isFinite(params.price) || params.price < 0) {
    throw ApiError.badRequest('Narx manfiy bo\'lishi mumkin emas.');
  }

  const override: PlanOverride = {
    price: Math.round(params.price),
    updatedAt: params.now,
    updatedBy: params.byUid,
    ...(params.lifetimeAnnualFeeUsd !== undefined
      ? { lifetimeAnnualFeeUsd: Math.round(params.lifetimeAnnualFeeUsd) }
      : {}),
  };

  await db().ref(`${OVERRIDES_PATH}/${params.planId}`).set(override);

  return mergePrices([plan], { [plan.id]: override })[0]!;
}

/** Narxni fayl qiymatiga qaytaradi. */
export async function resetPlanPrice(planId: string): Promise<void> {
  await db().ref(`${OVERRIDES_PATH}/${planId}`).remove();
}
