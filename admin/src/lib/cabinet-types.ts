/** Ega kabineti API javoblari — backend/src/services/cabinet.ts bilan mos. */

import type { LicenseStatus } from './admin-types';
import type { Plan } from './plans';

export interface CabinetProfile {
  tenantId: string;
  name: string;
  phone: string | null;
  address: string | null;
  createdAt: number | null;
  login: string | null;
  status: LicenseStatus;
  planName: string;
}

export type CabinetRange = 'today' | '7d' | '30d' | 'month';

export interface CabinetSummary {
  range: CabinetRange;
  generatedAt: number;
  period: { start: number; end: number; prevStart: number; prevEnd: number };
  income: { cash: number; card: number; other: number; debtPayments: number; total: number };
  previousIncome: number;
  expenses: number;
  previousExpenses: number;
  profit: number;
  orders: { created: number; previousCreated: number; delivered: number; active: number; readyToDeliver: number };
  debt: { count: number; total: number };
  series: { starts: number[]; income: number[]; created: number[] };
}

export interface CabinetEmployee {
  id: string;
  name: string;
  phone: string;
  active: boolean;
  createdAt: number | null;
  lastActiveAt: number | null;
}

export interface CabinetPayment {
  id: string;
  planName: string;
  amount: number;
  confirmedAt: number;
  newExpiresAt: number | null;
}

/** `GET /license/plans` — rejalar va to'lov rekvizitlari. */
export interface PlansResponse {
  plans: Plan[];
  payment: {
    method: string;
    cards: { number: string; type: string }[];
    cardHolder?: string;
    phone?: string;
    email?: string;
    telegram?: string;
    note?: string;
    configured: boolean;
  };
}

/** Egasining oxirgi to'lov so'rovi (admin ma'lumotisiz). */
export interface OwnerPaymentRequest {
  id: string;
  planId: string;
  planName: string;
  amount: number;
  reference?: string;
  note?: string;
  createdAt: number;
  status: 'pending' | 'approved' | 'rejected';
  resolvedAt?: number;
  rejectReason?: string;
}

export interface CabinetMessage {
  id: string;
  title: string;
  body: string;
  kind: 'yangilik' | 'eslatma' | 'taklif';
  createdAt: number;
  expiresAt: number | null;
}
