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
export const graceDays: number = plansData.grace.days;

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
