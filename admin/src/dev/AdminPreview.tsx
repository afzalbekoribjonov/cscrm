/**
 * Boshqaruv panelini ko'rib chiqish — FAQAT ISHLAB CHIQISH UCHUN.
 *
 * `npm run dev` → http://localhost:5173/admin-preview.html
 *
 * Haqiqiy server va bazaga ULANMAYDI: API javoblari shu fayldagi
 * NAMUNAVIY ma'lumot bilan almashtiriladi (`setDevTransport`), kirish
 * esa soxta foydalanuvchi bilan. Prod yig'ilishiga kirmaydi.
 *
 * Holatlar (URL): ?holat=bosh | xato | sekin | faolliksiz
 * Boshlang'ich sahifa: ?yol=/admin/tenants/t2 (standart — /admin)
 */
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import type { User } from 'firebase/auth';

import { ToastProvider } from '@/components/ui';
import type { Overview, OverviewRange } from '@/lib/admin-types';
import { ApiError, setDevTransport } from '@/lib/api';
import { AuthContext, type AuthState } from '@/lib/auth';
import { AdminLayout } from '@/pages/admin/AdminLayout';
import { DashboardPage } from '@/pages/admin/DashboardPage';
import { PaymentRequestsPage } from '@/pages/admin/PaymentRequestsPage';
import { TenantDetailPage } from '@/pages/admin/TenantDetailPage';
import { TenantsPage } from '@/pages/admin/TenantsPage';
import '@/styles/global.css';
import '@/styles/ui.css';
import '@/styles/marketing.css';

import { createTenantStore } from './tenant-fixtures';

const scenario = new URLSearchParams(location.search).get('holat') ?? 'oddiy';
const startPath = new URLSearchParams(location.search).get('yol') ?? '/admin';
const tenantStore = createTenantStore(scenario === 'bosh');

const DAY = 86_400_000;
const TZ = 5 * 3_600_000;
const dayStart = (t: number) => Math.floor((t + TZ) / DAY) * DAY - TZ;

/** Barqaror "tasodifiy" — har ochilganda bir xil rasm. */
function seeded(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

function starts(range: OverviewRange, now: number): number[] {
  const today = dayStart(now);
  if (range === '7d' || range === '30d') {
    const n = range === '7d' ? 7 : 30;
    return Array.from({ length: n }, (_, i) => today - (n - 1 - i) * DAY);
  }
  if (range === '90d') {
    const monday = today - ((new Date(today + TZ).getUTCDay() + 6) % 7) * DAY;
    return Array.from({ length: 13 }, (_, i) => monday - (12 - i) * 7 * DAY);
  }
  const d = new Date(now + TZ);
  return Array.from({ length: 12 }, (_, i) => Date.UTC(d.getUTCFullYear(), d.getUTCMonth() - 11 + i, 1) - TZ);
}

const NAMES = [
  'Toza Gilam', "G'olib Servis", 'Oq Parda', 'Nur Kimyoviy', 'Shabada', 'Bahor Kir Yuvish',
  'Musaffo', 'Yangi Uy', 'Sof Gilam', 'Orzu Servis',
];

function overview(range: OverviewRange): Overview {
  const now = Date.now();
  const rnd = seeded(range.length * 97 + 13);
  const s = starts(range, now);
  const empty = scenario === 'bosh';
  const scale = range === '12m' ? 18 : range === '90d' ? 5 : 1;

  const revenue = s.map((_, i) =>
    empty ? 0 : Math.round((rnd() < 0.25 ? 0 : 199_000 * (1 + Math.floor(rnd() * 3))) * scale * (0.6 + i / s.length)),
  );
  const registrations = s.map(() => (empty ? 0 : Math.floor(rnd() * 3 * Math.sqrt(scale))));
  const sum = (a: number[]) => a.reduce((x, y) => x + y, 0);

  return {
    range,
    generatedAt: now,
    period: { start: s[0]!, prevStart: s[0]! - (now - s[0]!) },
    revenue: { current: sum(revenue), previous: empty ? 0 : Math.round(sum(revenue) * 0.82), count: revenue.filter(Boolean).length },
    registrations: { current: sum(registrations), previous: empty ? 0 : Math.max(0, sum(registrations) - 2) },
    tenants: empty
      ? { total: 0, active: 0, trial: 0, expiring: 0, blocked: 0, paid: 0, onTrial: 0 }
      : { total: 46, active: 31, trial: 6, expiring: 5, blocked: 4, paid: 34, onTrial: 8 },
    activity:
      scenario === 'faolliksiz' ? null : empty ? { activeTenants: 0, activeUsers: 0, totalUsers: 0 } : { activeTenants: 29, activeUsers: 87, totalUsers: 131 },
    pendingPayments: empty ? 0 : 2,
    series: { starts: s, revenue, registrations },
    attention: empty
      ? []
      : [
          { tenantId: 't1', name: NAMES[1]!, reason: 'pending_payment', state: 'expired', daysLeft: -2, amount: 537_000, at: now - 3 * 3_600_000 },
          { tenantId: 't2', name: NAMES[4]!, reason: 'pending_payment', state: 'expiring', daysLeft: 1, amount: 199_000, at: now - 26 * 3_600_000 },
          { tenantId: 't3', name: NAMES[6]!, reason: 'blocked', state: 'expired', daysLeft: -1 },
          { tenantId: 't4', name: NAMES[8]!, reason: 'blocked', state: 'suspended', daysLeft: null },
          { tenantId: 't5', name: NAMES[2]!, reason: 'expiring', state: 'expiring', daysLeft: 2 },
          { tenantId: 't6', name: NAMES[9]!, reason: 'expiring', state: 'expiring', daysLeft: 6 },
        ],
    recentTenants: empty
      ? []
      : [0, 3, 5, 7, 9].map((n, i) => ({
          tenantId: `r${n}`,
          name: NAMES[n]!,
          createdAt: now - (i * 2 + 1) * 3_600_000 * 11,
          state: i === 3 ? 'expiring' : 'active',
          kind: i < 2 ? 'trial' : 'subscription',
          lastActiveAt: i === 1 ? null : now - (i + 1) * 40 * 60_000,
        })),
    recentPayments: empty
      ? []
      : [1, 0, 3, 5, 2].map((n, i) => ({
          id: `p${i}`,
          tenantId: `t${n}`,
          tenantName: NAMES[n]!,
          planName: ['1 oylik', '3 oylik', '1 yillik', '1 oylik', 'Bir umrlik'][i]!,
          amount: [199_000, 537_000, 1_790_000, 199_000, 4_500_000][i]!,
          at: now - (i * 7 + 2) * 3_600_000,
        })),
  };
}

setDevTransport(async (path, init) => {
  await new Promise((r) => setTimeout(r, scenario === 'sekin' ? 2500 : 250));
  if (scenario === 'xato') {
    throw new ApiError('Aloqa o\'rnatilmadi. Internetni tekshirib, qayta urinib ko\'ring.');
  }
  const url = new URL(path, location.origin);
  const method = init.method ?? 'GET';
  const body = typeof init.body === 'string' ? (JSON.parse(init.body) as Record<string, unknown>) : {};
  const handled = tenantStore(method, url.pathname, body);
  if (handled !== undefined) return handled;
  if (url.pathname === '/api/v1/admin/badges') {
    const queue = tenantStore('GET', '/api/v1/admin/payment-requests', {}) as { requests: unknown[] };
    return { ok: true, badges: { pendingPayments: queue.requests.length } };
  }
  if (url.pathname === '/api/v1/admin/overview') {
    const range = (url.searchParams.get('range') ?? '30d') as OverviewRange;
    return { ok: true, overview: overview(range) };
  }
  throw new ApiError('Bu sahifa uchun namunaviy ma\'lumot yo\'q.');
});

const auth: AuthState = {
  user: { email: 'admin@cscrm.uz', uid: 'preview' } as User,
  isSuperAdmin: true,
  ready: true,
  signIn: async () => undefined,
  signOutNow: async () => undefined,
};

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AuthContext.Provider value={auth}>
      <MemoryRouter initialEntries={[startPath]}>
        <ToastProvider>
          <Routes>
            <Route path="/admin" element={<AdminLayout />}>
              <Route index element={<DashboardPage />} />
              <Route path="tenants" element={<TenantsPage />} />
              <Route path="tenants/:tenantId" element={<TenantDetailPage />} />
              <Route path="payment-requests" element={<PaymentRequestsPage />} />
              <Route path="*" element={<p className="muted">Bu sahifa keyingi bosqichda.</p>} />
            </Route>
            <Route path="*" element={<p className="muted">Ko'rib chiqishda faqat panel.</p>} />
          </Routes>
        </ToastProvider>
      </MemoryRouter>
    </AuthContext.Provider>
  </StrictMode>,
);
