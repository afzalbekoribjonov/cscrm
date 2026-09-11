import plansData from '@shared/plans.json';

import { formatNumber } from './format';

export type PlanKind = 'trial' | 'subscription' | 'lifetime';

export interface Plan {
  id: string;
  name: string;
  months: number | null;
  days?: number;
  price: number;
  kind: PlanKind;
  description: string;
  highlight: boolean;
  lifetimeAnnualFeeUsd?: number;
}

export const plans = plansData.plans as Plan[];

/**
 * Muddat tugashidan necha kun oldin eslatiladi.
 *
 * Saytda QO'LDA yozilmaydi: eslatma jadvali o'zgarsa, sahifadagi
 * va'da o'z-o'zidan yangilanishi kerak. Ilgari shu yerda `graceDays`
 * ham bor edi — obuna tugagach qo'shimcha vaqt berilmaydigan
 * bo'lganidan keyin u olib tashlandi.
 */
export const warnBeforeDays: number[] = plansData.warnBeforeDays;

/**
 * Sinov muddati kunlarda.
 *
 * Marketing matnida QO'LDA yozilmaydi: narx kabi bu ham yagona
 * manbadan olinadi, aks holda `plans.json` o'zgarganda saytdagi va'da
 * bilan haqiqiy muddat ajralib ketadi.
 */
export const trialDays: number =
  (plansData.plans as Plan[]).find((p) => p.kind === 'trial')?.days ?? 0;

/** Narx hali belgilanmagan rejalar (price === 0, lekin bepul emas). */
export function isPriceUnset(plan: Plan): boolean {
  return plan.kind !== 'trial' && plan.price === 0;
}

export function formatPrice(plan: Plan): string {
  if (plan.kind === 'trial') return 'Bepul';
  if (isPriceUnset(plan)) return 'Narx kelishiladi';
  return `${formatNumber(plan.price)} so'm`;
}

/** Oyiga tushadigan narx — rejalarni taqqoslash uchun. */
export function monthlyPrice(plan: Plan): string | null {
  if (!plan.months || isPriceUnset(plan) || plan.kind === 'trial') return null;
  return `${formatNumber(Math.round(plan.price / plan.months))} so'm/oy`;
}

/**
 * Serverdagi JORIY narxlar.
 *
 * Narx endi bazada va panelda o'zgartiriladi. Fayldagi qiymat esa
 * build paytida bundlega kiradi — ya'ni u eskirishi mumkin.
 *
 * Shuning uchun sahifa avval fayl qiymatini ko'rsatadi (darhol, bo'sh
 * ekran bo'lmasin), keyin serverdan kelganini qo'yadi. Server javob
 * bermasa fayl qiymati qoladi — narx umuman ko'rinmagandan yaxshiroq.
 */
export async function fetchPlans(apiBaseUrl: string): Promise<Plan[] | null> {
  try {
    const res = await fetch(`${apiBaseUrl}/api/v1/license/plans`);
    if (!res.ok) return null;
    const json = (await res.json()) as { plans?: unknown };
    if (!Array.isArray(json.plans)) return null;
    return json.plans as Plan[];
  } catch {
    return null;
  }
}
