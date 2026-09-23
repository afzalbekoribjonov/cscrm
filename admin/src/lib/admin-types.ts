/** Super-admin API javoblarining turlari (backend bilan mos). */

import type { Tone } from '@/components/ui/Badge';

import { formatDay, formatTime } from './dates';
import type { Permission } from './permissions';

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

/** Arxiv holati: qachon arxivlangan va qachon butunlay o'chiriladi. */
export interface ArchiveInfo {
  archivedAt: number;
  purgeAfter: number;
  reason: string;
}

export interface TenantSummary {
  tenantId: string;
  name: string;
  phone?: string;
  createdAt: number;
  status: LicenseStatus;
  /** Reja nomi ("3 oylik"). */
  planName: string;
  archive: ArchiveInfo | null;
  /** Egasi yoki xodimining oxirgi faolligi; noma'lum — `null`. */
  lastActiveAt: number | null;
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
  address?: string;
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

export type AuditAction =
  | 'payment.confirm'
  | 'payment.reject'
  | 'tenant.update'
  | 'tenant.suspend'
  | 'tenant.unsuspend'
  | 'tenant.archive'
  | 'tenant.restore'
  | 'tenant.delete'
  | 'tenant.purge'
  | 'license.update'
  | 'credentials.login'
  | 'credentials.password'
  | 'plan.price'
  | 'plan.price_reset'
  | 'broadcast.create'
  | 'broadcast.delete'
  | 'site.settings'
  | 'role.create'
  | 'role.update'
  | 'role.delete'
  | 'admin.add'
  | 'admin.role'
  | 'admin.remove'
  | 'user.signout';

/** Amallar jurnali yozuvi — backend/src/services/audit.ts bilan mos. */
export interface AuditEntry {
  id: string;
  at: number;
  action: AuditAction;
  actor: { uid: string; email: string | null };
  tenantId?: string;
  tenantName?: string;
  note?: string;
  changes?: Record<string, { from: unknown; to: unknown }>;
}

/** Platforma foydalanuvchisi — backend/src/services/users.ts bilan mos. */
export interface PlatformUser {
  uid: string;
  kind: 'owner' | 'staff';
  tenantId: string;
  tenantName: string;
  tenantArchived: boolean;
  name: string;
  login?: string;
  phone?: string;
  /** Xodim ilovada faolmi (egasi o'chirib qo'ymaganmi). */
  active: boolean;
  /** Hech kirmagan xodimda hisob yo'q. */
  hasAccount: boolean;
  createdAt: number | null;
  lastActiveAt: number | null;
  disabled: boolean;
}

/** Panel roli — backend/src/services/admin-access.ts bilan mos. */
export interface AdminRole {
  id: string;
  name: string;
  description?: string;
  permissions: Permission[];
  createdAt: number;
  createdBy: string;
  updatedAt?: number;
  memberCount: number;
}

export interface AdminMember {
  uid: string;
  email: string;
  roleId: string;
  roleName: string | null;
  addedAt: number;
  lastSignInAt: number | null;
  disabled: boolean;
}

export interface AccessOverview {
  roles: AdminRole[];
  members: AdminMember[];
  superAdmins: { uid: string; email: string | null; lastSignInAt: number | null }[];
  permissions: { id: Permission; label: string; superOnly: boolean }[];
}

/** Biznes egasining kirish ma'lumotlari. Parol HECH QACHON kelmaydi. */
export interface OwnerCredentials {
  uid: string;
  login: string | null;
  email: string | null;
  lastSignInAt: string | null;
  disabled: boolean;
}

/** "Umumiy" sahifasi davri. */
export type OverviewRange = '7d' | '30d' | '90d' | '12m';

export type AttentionReason = 'pending_payment' | 'blocked' | 'expiring';

/** `GET /admin/overview` javobi — backend/src/services/overview.ts bilan mos. */
export interface Overview {
  range: OverviewRange;
  generatedAt: number;
  period: { start: number; prevStart: number };
  revenue: { current: number; previous: number; count: number };
  registrations: { current: number; previous: number };
  /**
   * `active/trial/expiring/blocked` — chart guruhlari (har biznes bittasida).
   * `paid` — pullik va bloklanmagan (muddati yaqinlari ham), `onTrial` — sinovda.
   */
  tenants: {
    total: number;
    active: number;
    trial: number;
    expiring: number;
    blocked: number;
    paid: number;
    onTrial: number;
  };
  /** `null` — faollikni aniqlab bo'lmadi. */
  activity: { activeTenants: number; activeUsers: number; totalUsers: number } | null;
  pendingPayments: number;
  series: { starts: number[]; revenue: number[]; registrations: number[] };
  attention: {
    tenantId: string;
    name: string;
    reason: AttentionReason;
    state: LicenseState;
    daysLeft: number | null;
    amount?: number;
    at?: number;
  }[];
  recentTenants: {
    tenantId: string;
    name: string;
    createdAt: number;
    state: LicenseState;
    kind: 'trial' | 'subscription' | 'lifetime';
    lastActiveAt: number | null;
  }[];
  recentPayments: {
    id: string;
    tenantId: string;
    tenantName: string;
    planName: string;
    amount: number;
    at: number;
  }[];
}

/**
 * Holatning ko'rinishi: nom va ohang (`<Badge tone>` uchun).
 *
 * Ilgari to'g'ridan-to'g'ri rang qaytarardi (`var(--success)` va h.k.)
 * va u MATN rangi sifatida ishlatilardi — oq fonda 1.9–3.9:1, ya'ni
 * o'qish qiyin. Endi ohang: Badge uni tekshirilgan `--*-ink` rangiga
 * aylantiradi (>= 4.5:1).
 */
export function stateVisual(state: LicenseState): { label: string; tone: Tone } {
  switch (state) {
    case 'active':
      return { label: 'Faol', tone: 'success' };
    case 'expiring':
      return { label: 'Muddat yaqin', tone: 'warning' };
    case 'grace':
      return { label: 'Muddat tugadi', tone: 'warning' };
    case 'expired':
      return { label: 'Bloklangan', tone: 'danger' };
    case 'lifetime_fee_due':
      return { label: 'Yillik to\'lov', tone: 'warning' };
    case 'suspended':
      return { label: 'To\'xtatilgan', tone: 'danger' };
  }
}

export { formatSom } from './format';

/**
 * Sana va vaqt — Toshkent vaqti bo'yicha, oy nomi bilan ("23-sentabr 14:05").
 *
 * Ilgari brauzerning `toLocaleString('uz-UZ')` ishlatilardi: natija
 * brauzerga qarab turlicha chiqardi ("09/23/2026" yoki "23.09.2026")
 * va kompyuter soat mintaqasiga bog'liq edi.
 */
export function formatDateTime(ms: number | null | undefined): string {
  if (!ms) return '—';
  return `${formatDay(ms)} ${formatTime(ms)}`;
}

export function formatDate(ms: number | null | undefined): string {
  if (!ms) return '—';
  return formatDay(ms);
}
