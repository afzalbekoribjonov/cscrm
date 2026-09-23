import type { ReactNode } from 'react';
import { Navigate, Route } from 'react-router-dom';

import type { IconName } from '@/components/Icon';
import { EmptyState, PageHeader } from '@/components/ui';
import { useAuth } from '@/lib/auth';
import type { Permission } from '@/lib/permissions';

import { AccessPage } from './AccessPage';
import { AuditPage } from './AuditPage';
import { BroadcastsPage } from './BroadcastsPage';
import { DashboardPage } from './DashboardPage';
import { PaymentRequestsPage } from './PaymentRequestsPage';
import { PlansPage } from './PlansPage';
import { SettingsPage } from './SettingsPage';
import { TenantDetailPage } from './TenantDetailPage';
import { TenantsPage } from './TenantsPage';
import { UsersPage } from './UsersPage';

export interface NavItem {
  to: string;
  label: string;
  icon: IconName;
  end?: boolean;
  /** Menyu bandini ko'rish uchun kerakli vakolat. */
  permission: Permission;
  /** Yonida ko'rsatiladigan son (masalan, kutilayotgan to'lovlar). */
  badge?: 'pendingPayments';
}

/**
 * Menyu — faqat HOZIR ishlaydigan bo'limlar va faqat vakolati borlariga.
 * Guruhlar orasida ajratuvchi: kundalik ish → odamlar → sozlash.
 */
export const NAV: NavItem[][] = [
  [
    { to: '/admin', label: 'Umumiy', icon: 'grid', end: true, permission: 'tenants.read' },
    { to: '/admin/tenants', label: 'Bizneslar', icon: 'building', permission: 'tenants.read' },
    {
      to: '/admin/payment-requests',
      label: 'To\'lov so\'rovlari',
      icon: 'card',
      permission: 'payments.manage',
      badge: 'pendingPayments',
    },
  ],
  [
    { to: '/admin/users', label: 'Foydalanuvchilar', icon: 'people', permission: 'users.read' },
    { to: '/admin/audit', label: 'Amallar jurnali', icon: 'activity', permission: 'audit.read' },
    { to: '/admin/access', label: 'Panel xodimlari', icon: 'shield', permission: 'admins.manage' },
  ],
  [
    { to: '/admin/broadcasts', label: 'Xabarlar', icon: 'bell', permission: 'broadcasts.manage' },
    { to: '/admin/plans', label: 'Tariflar', icon: 'money', permission: 'plans.manage' },
    { to: '/admin/settings', label: 'Sozlamalar', icon: 'settings', permission: 'settings.manage' },
  ],
];

/** Vakolat yo'q — sahifa o'rniga aniq tushuntirish (bo'sh sahifa yoki xato emas). */
function NoAccess() {
  return (
    <>
      <PageHeader title="Ruxsat yo'q" />
      <EmptyState
        icon="lock"
        title="Bu bo'lim sizning rolingizga ochilmagan"
        description="Kerak bo'lsa, panel administratoriga murojaat qiling."
      />
    </>
  );
}

function Guard({ permission, children }: { permission: Permission; children: ReactNode }) {
  const { can } = useAuth();
  return can(permission) ? <>{children}</> : <NoAccess />;
}

/**
 * `/admin` — "Umumiy" ko'rish huquqi bo'lmasa, ruxsati bor birinchi
 * bo'limga o'tadi. Hech biri bo'lmasa — tushuntirish.
 */
function AdminHome() {
  const { can } = useAuth();
  if (can('tenants.read')) return <DashboardPage />;
  const first = NAV.flat().find((item) => can(item.permission));
  if (first) return <Navigate to={first.to} replace />;
  return (
    <>
      <PageHeader title="Xush kelibsiz" />
      <EmptyState
        icon="lock"
        title="Rolingizga hali vakolat berilmagan"
        description="Panel administratori rolingizga kerakli bo'limlarni ochgach, ular menyuda paydo bo'ladi."
      />
    </>
  );
}

/** `/admin` ichidagi marshrutlar — ilova va ko'rib chiqish sahifasi uchun bitta ro'yxat. */
export function adminRoutes() {
  return (
    <>
      <Route index element={<AdminHome />} />
      <Route path="tenants" element={<Guard permission="tenants.read"><TenantsPage /></Guard>} />
      <Route path="tenants/:tenantId" element={<Guard permission="tenants.read"><TenantDetailPage /></Guard>} />
      <Route
        path="payment-requests"
        element={<Guard permission="payments.manage"><PaymentRequestsPage /></Guard>}
      />
      <Route path="users" element={<Guard permission="users.read"><UsersPage /></Guard>} />
      <Route path="audit" element={<Guard permission="audit.read"><AuditPage /></Guard>} />
      <Route path="access" element={<Guard permission="admins.manage"><AccessPage /></Guard>} />
      <Route path="broadcasts" element={<Guard permission="broadcasts.manage"><BroadcastsPage /></Guard>} />
      <Route path="plans" element={<Guard permission="plans.manage"><PlansPage /></Guard>} />
      <Route path="settings" element={<Guard permission="settings.manage"><SettingsPage /></Guard>} />
      <Route path="*" element={<Navigate to="/admin" replace />} />
    </>
  );
}
