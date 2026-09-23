import { lazy, Suspense, type ReactNode } from 'react';
import { Route, Routes } from 'react-router-dom';

import { RouteLoading } from './components/RouteLoading';
import { SiteLayout } from './components/SiteLayout';
import { NotFoundPage } from './pages/NotFoundPage';
import { LandingPage } from './pages/marketing/LandingPage';
import { SOLUTIONS, SolutionPage } from './pages/marketing/SolutionPage';

/*
 * Bo'laklar (code splitting).
 *
 * Bosh sahifa va soha sahifalari — asosiy bo'lakda: reklamadan kelgan
 * tashrifchi aynan ularni ochadi va ular darhol chiqishi kerak.
 * Qolgan sahifalar birinchi o'tishda yuklanadi.
 *
 * Panel (`/kirish`, `/admin/*`) — Firebase Auth SDK bilan birga butunlay
 * alohida: saytga kirgan mijoz uni umuman yuklab olmaydi.
 */
const named = <K extends string>(load: () => Promise<Record<K, React.ComponentType>>, name: K) =>
  lazy(() => load().then((m) => ({ default: m[name] })));

const FeaturesPage = named(() => import('./pages/marketing/FeaturesPage'), 'FeaturesPage');
const PricingPage = named(() => import('./pages/marketing/PricingPage'), 'PricingPage');
const DownloadPage = named(() => import('./pages/marketing/DownloadPage'), 'DownloadPage');
const HelpPage = named(() => import('./pages/marketing/HelpPage'), 'HelpPage');
const ContactPage = named(() => import('./pages/marketing/ContactPage'), 'ContactPage');
const PrivacyPage = named(() => import('./pages/marketing/PrivacyPage'), 'PrivacyPage');
const OfferPage = named(() => import('./pages/marketing/OfferPage'), 'OfferPage');

const AdminArea = lazy(() => import('./pages/admin/AdminArea'));
const AdminRoutes = lazy(() => import('./pages/admin/AdminRoutes'));
const AdminLoginPage = named(() => import('./pages/admin/AdminLoginPage'), 'AdminLoginPage');

function Page({ children }: { children: ReactNode }) {
  return <Suspense fallback={<RouteLoading />}>{children}</Suspense>;
}

/**
 * Yo'nalishlar uch guruhga bo'linadi:
 *  * marketing sahifalari — `SiteLayout` (header + footer) ichida
 *  * kirish — o'z karkasi bilan
 *  * `/admin/*` — faqat panel xodimlari uchun
 */
export function App() {
  return (
    <Routes>
      <Route element={<SiteLayout />}>
        <Route index element={<LandingPage />} />
        <Route path="imkoniyatlar" element={<Page><FeaturesPage /></Page>} />
        <Route path="narxlar" element={<Page><PricingPage /></Page>} />
        <Route path="yuklab-olish" element={<Page><DownloadPage /></Page>} />
        <Route path="yordam" element={<Page><HelpPage /></Page>} />
        <Route path="aloqa" element={<Page><ContactPage /></Page>} />

        {/* Soha sahifalari bitta shablondan chiqadi — yangisini
            qo'shish uchun faqat SOLUTIONS ro'yxatiga yozish kifoya. */}
        {SOLUTIONS.map((s) => (
          <Route key={s.slug} path={s.slug} element={<SolutionPage content={s} />} />
        ))}

        <Route path="maxfiylik" element={<Page><PrivacyPage /></Page>} />
        <Route path="oferta" element={<Page><OfferPage /></Page>} />

        <Route path="*" element={<NotFoundPage />} />
      </Route>

      {/* Kirish va panel — bitta `AuthProvider` ostida (AdminArea). */}
      <Route element={<Page><AdminArea /></Page>}>
        <Route path="/kirish" element={<AdminLoginPage />} />
        <Route path="/admin/*" element={<AdminRoutes />} />
      </Route>
    </Routes>
  );
}
