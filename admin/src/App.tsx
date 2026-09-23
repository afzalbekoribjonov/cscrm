import { Navigate, Route, Routes } from 'react-router-dom';

import { SiteLayout } from './components/SiteLayout';
import { ToastProvider } from './components/ui';
import { AuthProvider, useAuth } from './lib/auth';
import { NotFoundPage } from './pages/NotFoundPage';
import { AdminLayout } from './pages/admin/AdminLayout';
import { AdminLoginPage } from './pages/admin/AdminLoginPage';
import { adminRoutes } from './pages/admin/nav';
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
 * Ikki shart: tizimga kirilgan BO'LISHI va server uni panel xodimi
 * (super-admin yoki rolga ega) deb TASDIQLAGAN bo'lishi. Ikkinchisi
 * muhim — Firebase'ga har qanday hisob kira oladi, lekin panelga
 * faqat ruxsat etilganlar.
 *
 * Bu faqat ko'rinish darajasidagi himoya: haqiqiy cheklov backendda,
 * har bir `/admin` so'rovi `requireAdmin` va o'z vakolatidan o'tadi.
 */
function RequireAdmin() {
  const { user, access, ready } = useAuth();

  if (!ready) {
    return (
      <p className="muted" style={{ padding: 40, textAlign: 'center' }}>
        Tekshirilmoqda…
      </p>
    );
  }
  if (!user || !access) return <Navigate to="/kirish" replace />;

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
      {/* Amal natijasi xabarlari ("Saqlandi") — butun ilova uchun bitta. */}
      <ToastProvider>
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

          <Route path="/admin" element={<RequireAdmin />}>
            {adminRoutes()}
          </Route>
        </Routes>
      </ToastProvider>
    </AuthProvider>
  );
}
