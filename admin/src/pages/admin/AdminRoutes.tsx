import { Navigate, Route, Routes } from 'react-router-dom';

import { RouteLoading } from '@/components/RouteLoading';
import { useAuth } from '@/lib/auth';

import { AdminLayout } from './AdminLayout';
import { adminRoutes } from './nav';

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
  if (!ready) return <RouteLoading label="Tekshirilmoqda…" />;
  if (!user || !access) return <Navigate to="/kirish" replace />;
  return <AdminLayout />;
}

/** `/admin/*` — panelning ichki marshrutlari (alohida bo'lak). */
export default function AdminRoutes() {
  return (
    <Routes>
      <Route element={<RequireAdmin />}>{adminRoutes()}</Route>
    </Routes>
  );
}
