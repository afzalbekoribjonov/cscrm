import { Navigate, Route, Routes } from 'react-router-dom';

import { SiteLayout } from './components/SiteLayout';
import { AuthProvider, useAuth } from './lib/auth';
import { NotFoundPage } from './pages/NotFoundPage';
import { AdminLayout } from './pages/admin/AdminLayout';
import { AdminLoginPage } from './pages/admin/AdminLoginPage';
import { BroadcastsPage } from './pages/admin/BroadcastsPage';
import { DashboardPage } from './pages/admin/DashboardPage';
import { PlansPage } from './pages/admin/PlansPage';
import { SettingsPage } from './pages/admin/SettingsPage';
import { PaymentRequestsPage } from './pages/admin/PaymentRequestsPage';
import { TenantDetailPage } from './pages/admin/TenantDetailPage';
import { TenantsPage } from './pages/admin/TenantsPage';
import { ContactPage } from './pages/marketing/ContactPage';
import { DownloadPage } from './pages/marketing/DownloadPage';
import { FeaturesPage } from './pages/marketing/FeaturesPage';
import { HelpPage } from './pages/marketing/HelpPage';
import { LandingPage } from './pages/marketing/LandingPage';
import { OfferPage } from './pages/marketing/OfferPage';
import { PricingPage } from './pages/marketing/PricingPage';
import { PrivacyPage } from './pages/marketing/PrivacyPage';
import { SOLUTIONS, SolutionPage } from './pages/marketing/SolutionPage';

/**
 * Panelni himoyalaydi.
 *
 * Ikki shart: tizimga kirilgan BO'LISHI va server uni super-admin deb
 * TASDIQLAGAN bo'lishi. Ikkinchisi muhim — Firebase'ga har qanday hisob
 * kira oladi, lekin panelga faqat ruxsat etilganlar.
 *
 * Bu faqat ko'rinish darajasidagi himoya: haqiqiy cheklov backendda,
 * har bir `/admin` so'rovi `requireSuperAdmin` dan o'tadi.
 */
function RequireSuperAdmin() {
  const { user, isSuperAdmin, ready } = useAuth();

  if (!ready) {
    return (
      <p className="muted" style={{ padding: 40, textAlign: 'center' }}>
        Tekshirilmoqda…
      </p>
    );
  }
  if (!user || !isSuperAdmin) return <Navigate to="/kirish" replace />;

  return <AdminLayout />;
}

/**
 * Yo'nalishlar uch guruhga bo'linadi:
 *  * marketing sahifalari — `SiteLayout` (header + footer) ichida
 *  * kirish — o'z karkasi bilan
 *  * `/admin/*` — faqat super-adminlar uchun
 */
export function App() {
  return (
    <AuthProvider>
      <Routes>
        <Route element={<SiteLayout />}>
          <Route index element={<LandingPage />} />
          <Route path="imkoniyatlar" element={<FeaturesPage />} />
          <Route path="narxlar" element={<PricingPage />} />
          <Route path="yuklab-olish" element={<DownloadPage />} />
          <Route path="yordam" element={<HelpPage />} />
          <Route path="aloqa" element={<ContactPage />} />

          {/* Soha sahifalari bitta shablondan chiqadi — yangisini
              qo'shish uchun faqat SOLUTIONS ro'yxatiga yozish kifoya. */}
          {SOLUTIONS.map((s) => (
            <Route
              key={s.slug}
              path={s.slug}
              element={<SolutionPage content={s} />}
            />
          ))}

          <Route path="maxfiylik" element={<PrivacyPage />} />
          <Route path="oferta" element={<OfferPage />} />

          <Route path="*" element={<NotFoundPage />} />
        </Route>

        <Route path="/kirish" element={<AdminLoginPage />} />

        <Route path="/admin" element={<RequireSuperAdmin />}>
          <Route index element={<DashboardPage />} />
          <Route path="payment-requests" element={<PaymentRequestsPage />} />
          <Route path="broadcasts" element={<BroadcastsPage />} />
          <Route path="plans" element={<PlansPage />} />
          <Route path="settings" element={<SettingsPage />} />
          <Route path="tenants" element={<TenantsPage />} />
          <Route path="tenants/:tenantId" element={<TenantDetailPage />} />
        </Route>
      </Routes>
    </AuthProvider>
  );
}
