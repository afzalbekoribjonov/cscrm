/**
 * Ega kabinetini ko'rib chiqish — FAQAT ISHLAB CHIQISH UCHUN.
 *
 * `npm run dev` → http://localhost:5173/cabinet-preview.html
 *
 * Haqiqiy server va bazaga ULANMAYDI: javoblar shu fayldagi NAMUNAVIY
 * ma'lumot. Prod yig'ilishiga kirmaydi.
 *
 * Holatlar (URL): ?holat=bosh | xato | bloklangan | kutilmoqda
 * Sahifa: ?yol=/kabinet/obuna
 */
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import type { User } from 'firebase/auth';

import { ToastProvider } from '@/components/ui';
import type { LicenseStatus } from '@/lib/admin-types';
import { ApiError, setDevTransport } from '@/lib/api';
import type { CabinetProfile, CabinetRange, CabinetSummary, OwnerPaymentRequest } from '@/lib/cabinet-types';
import { OwnerAuthContext, type OwnerAuthState } from '@/lib/owner-auth';
import { plans } from '@/lib/plans';
import { cabinetRoutes } from '@/pages/cabinet/CabinetArea';
import '@/styles/global.css';
import '@/styles/ui.css';
import '@/styles/marketing.css';

const q = new URLSearchParams(location.search);
const scenario = q.get('holat') ?? 'oddiy';
const startPath = q.get('yol') ?? '/kabinet';

const DAY = 86_400_000;
const HOUR = 3_600_000;
const TZ = 5 * HOUR;
const now = Date.now();
const today = Math.floor((now + TZ) / DAY) * DAY - TZ;

function seeded(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

const status: LicenseStatus =
  scenario === 'bloklangan'
    ? { tenantId: 't1', state: 'expired', planId: 'm1', kind: 'subscription', expiresAt: now - 2 * DAY, daysLeft: -2, checkedAt: now, message: 'Obuna muddati tugagan. To\'lov qiling.', blocked: true }
    : { tenantId: 't1', state: 'expiring', planId: 'm1', kind: 'subscription', expiresAt: now + 3 * DAY, daysLeft: 3, checkedAt: now, message: 'Obuna 3 kundan keyin tugaydi.', blocked: false };

const profile: CabinetProfile = {
  tenantId: 't1',
  name: 'Toza Gilam',
  phone: '998901112233',
  address: 'Toshkent, Chilonzor',
  createdAt: now - 120 * DAY,
  login: 'tozagilam',
  status,
  planName: '1 oylik',
};

function summary(range: CabinetRange): CabinetSummary {
  const empty = scenario === 'bosh';
  const rnd = seeded(range.length * 31 + 7);
  const days = range === 'today' ? 1 : range === '7d' ? 7 : range === '30d' ? 30 : new Date(now + TZ).getUTCDate();
  const starts = Array.from({ length: days }, (_, i) => today - (days - 1 - i) * DAY);
  const income = starts.map(() => (empty ? 0 : Math.round(rnd() * 12) * 45_000));
  const created = starts.map(() => (empty ? 0 : Math.floor(rnd() * 9)));
  const total = income.reduce((a, b) => a + b, 0);
  const cash = Math.round(total * 0.62);
  const exp = empty ? 0 : Math.round(total * 0.28);
  return {
    range,
    generatedAt: now,
    period: { start: starts[0]!, end: today + DAY - 1, prevStart: starts[0]! - days * DAY, prevEnd: starts[0]! - 1 },
    income: { cash, card: total - cash, other: 0, debtPayments: empty ? 0 : 90_000, total },
    previousIncome: empty ? 0 : Math.round(total * 0.87),
    expenses: exp,
    previousExpenses: empty ? 0 : Math.round(exp * 1.1),
    profit: total - exp,
    orders: {
      created: created.reduce((a, b) => a + b, 0),
      previousCreated: empty ? 0 : Math.round(created.reduce((a, b) => a + b, 0) * 0.9),
      delivered: empty ? 0 : Math.round(created.reduce((a, b) => a + b, 0) * 0.8),
      active: empty ? 0 : 14,
      readyToDeliver: empty ? 0 : 5,
    },
    debt: empty ? { count: 0, total: 0 } : { count: 4, total: 385_000 },
    series: { starts, income, created },
  };
}

let request: OwnerPaymentRequest | null =
  scenario === 'kutilmoqda'
    ? { id: 'r1', planId: 'm3', planName: '3 oylik', amount: 537_000, reference: '8600 **** 4412', createdAt: now - 3 * HOUR, status: 'pending' }
    : { id: 'r0', planId: 'm1', planName: '1 oylik', amount: 199_000, createdAt: now - 33 * DAY, status: 'approved', resolvedAt: now - 32 * DAY };

setDevTransport(async (path, init) => {
  await new Promise((r) => setTimeout(r, 250));
  if (scenario === 'xato') throw new ApiError('Aloqa o\'rnatilmadi. Internetni tekshirib, qayta urinib ko\'ring.');
  const url = new URL(path, location.origin);
  const method = init.method ?? 'GET';
  switch (url.pathname) {
    case '/api/v1/cabinet/summary':
      return { ok: true, summary: summary((url.searchParams.get('range') ?? 'month') as CabinetRange) };
    case '/api/v1/cabinet/employees':
      return {
        ok: true,
        employees: scenario === 'bosh'
          ? []
          : [
              { id: 'e1', name: 'Ali Valiyev', phone: '998901000001', active: true, createdAt: now - 90 * DAY, lastActiveAt: now - 20 * 60_000 },
              { id: 'e2', name: 'Dilnoza Karimova', phone: '998901000002', active: true, createdAt: now - 60 * DAY, lastActiveAt: now - 5 * HOUR },
              { id: 'e3', name: 'Jasur Rahimov', phone: '998901000003', active: false, createdAt: now - 40 * DAY, lastActiveAt: now - 20 * DAY },
              { id: 'e4', name: 'Sardor Aliyev', phone: '998901000004', active: true, createdAt: now - 2 * DAY, lastActiveAt: null },
            ],
      };
    case '/api/v1/cabinet/payments':
      return {
        ok: true,
        payments: scenario === 'bosh' ? [] : [0, 1, 2].map((i) => ({ id: `p${i}`, planName: '1 oylik', amount: 199_000, confirmedAt: now - (i * 30 + 32) * DAY, newExpiresAt: now - (i * 30 - 3) * DAY })),
      };
    case '/api/v1/license/plans':
      return {
        ok: true,
        plans,
        payment: { method: 'card_transfer', cards: [{ number: '9860 1234 5678 9012', type: 'Humo' }, { number: '5614 1234 5678 9012', type: 'Uzcard' }], cardHolder: 'NAMUNA EGASI', configured: true },
      };
    case '/api/v1/license/payment-request':
      if (method === 'POST') {
        const body = JSON.parse(String(init.body)) as { planId: string; amount?: number; reference?: string };
        const plan = plans.find((p) => p.id === body.planId)!;
        request = { id: `r${Date.now()}`, planId: plan.id, planName: plan.name, amount: body.amount ?? plan.price, ...(body.reference ? { reference: body.reference } : {}), createdAt: Date.now(), status: 'pending' };
        return { ok: true, request };
      }
      return { ok: true, request };
    case '/api/v1/license/messages':
      return {
        ok: true,
        messages: scenario === 'bosh' ? [] : [{ id: 'b1', title: 'Yangi imkoniyat: qarzdorlar hisoboti', body: 'Endi qarzdor mijozlar ro\'yxatini bir bosishda ko\'rasiz.', kind: 'yangilik', createdAt: now - 2 * DAY, expiresAt: null }],
      };
  }
  throw new ApiError('Bu sahifa uchun namunaviy ma\'lumot yo\'q.');
});

const auth: OwnerAuthState = {
  user: { uid: 'owner1', email: 'tozagilam@cscrm.local' } as User,
  profile,
  notOwner: false,
  ready: true,
  signIn: async () => undefined,
  signOutNow: async () => undefined,
  refresh: async () => undefined,
};

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <OwnerAuthContext.Provider value={auth}>
      <MemoryRouter initialEntries={[startPath]}>
        <ToastProvider>
          <Routes>
            <Route path="/kabinet/*" element={<Routes>{cabinetRoutes()}</Routes>} />
          </Routes>
        </ToastProvider>
      </MemoryRouter>
    </OwnerAuthContext.Provider>
  </StrictMode>,
);
