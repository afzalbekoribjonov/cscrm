/** Super-admin API javoblarining turlari (backend bilan mos). */

export type LicenseState =
  | 'active'
  | 'expiring'
  | 'grace'
  | 'expired'
  | 'lifetime_fee_due'
  | 'suspended';

export interface LicenseStatus {
  tenantId: string;
  state: LicenseState;
  planId: string;
  kind: 'trial' | 'subscription' | 'lifetime';
  expiresAt: number | null;
  daysLeft: number | null;
  checkedAt: number;
  message: string;
  blocked: boolean;
}

export interface TenantSummary {
  tenantId: string;
  name: string;
  phone?: string;
  createdAt: number;
  status: LicenseStatus;
}

export interface PaymentRecord {
  id: string;
  planId: string;
  planName: string;
  amount: number;
  confirmedBy: string;
  confirmedAt: number;
  note?: string;
  newExpiresAt: number | null;
}

/** Biznes yuborgan "men to'ladim" so'rovi. */
export interface PaymentRequestRecord {
  id: string;
  planId: string;
  planName: string;
  amount: number;
  reference?: string;
  note?: string;
  createdAt: number;
  createdBy: string;
  status: 'pending' | 'approved' | 'rejected';
  resolvedAt?: number;
  resolvedBy?: string;
  rejectReason?: string;
}

/** Navbatdagi so'rov — qaysi biznesdan kelgani bilan. */
export interface PendingPayment extends PaymentRequestRecord {
  tenantId: string;
  tenantName: string;
}

export interface TenantDetail extends TenantSummary {
  license: {
    planId: string;
    kind: string;
    startedAt: number;
    expiresAt: number | null;
    nextAnnualFeeAt?: number | null;
    suspended?: boolean;
    suspendedReason?: string | null;
  };
  payments: PaymentRecord[];
  employeeCount: number;
  orderCount: number;
  /** Oxirgi to'lov so'rovi (bo'lmasa `null`). */
  paymentRequest: PaymentRequestRecord | null;
}

export interface AdminStats {
  totalTenants: number;
  activeTenants: number;
  blockedTenants: number;
  trialTenants: number;
  lifetimeTenants: number;
  revenue30d: number;
  /** Ko'rib chiqilmagan to'lov so'rovlari. */
  pendingPayments: number;
}

/** Holatning ko'rinishi: nom va rang. */
export function stateVisual(state: LicenseState): {
  label: string;
  color: string;
} {
  switch (state) {
    case 'active':
      return { label: 'Faol', color: 'var(--success)' };
    case 'expiring':
      return { label: 'Muddat yaqin', color: 'var(--warning)' };
    case 'grace':
      return { label: 'Muddat tugadi', color: 'var(--warning)' };
    case 'expired':
      return { label: 'Bloklangan', color: 'var(--danger)' };
    case 'lifetime_fee_due':
      return { label: 'Yillik to\'lov', color: 'var(--accent)' };
    case 'suspended':
      return { label: 'To\'xtatilgan', color: 'var(--danger)' };
  }
}

export { formatSom } from './format';

export function formatDateTime(ms: number | null | undefined): string {
  if (!ms) return '—';
  return new Date(ms).toLocaleString('uz-UZ', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

export function formatDate(ms: number | null | undefined): string {
  if (!ms) return '—';
  return new Date(ms).toLocaleDateString('uz-UZ', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}
