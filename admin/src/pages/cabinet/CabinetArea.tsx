import { Navigate, Route, Routes } from 'react-router-dom';

import { RouteLoading } from '@/components/RouteLoading';
import { ToastProvider } from '@/components/ui';
import { OwnerAuthProvider, useOwnerAuth } from '@/lib/owner-auth';
import { useNoIndex } from '@/lib/seo';
// Kabinet panel komponentlaridan foydalanadi — uslublari shu bo'lak bilan.
import '@/styles/ui.css';

import { CabinetEmployees } from './CabinetEmployees';
import { CabinetHome } from './CabinetHome';
import { CabinetLayout } from './CabinetLayout';
import { CabinetLogin } from './CabinetLogin';
import { CabinetMessages } from './CabinetMessages';
import { CabinetSubscription } from './CabinetSubscription';

function RequireOwner() {
  const { profile, ready } = useOwnerAuth();
  if (!ready) return <RouteLoading label="Tekshirilmoqda…" />;
  if (!profile) return <Navigate to="/kabinet/kirish" replace />;
  return <CabinetLayout />;
}

/** Kabinet ichki marshrutlari — ilova va ko'rib chiqish sahifasi uchun bitta ro'yxat. */
export function cabinetRoutes() {
  return (
    <>
      <Route path="kirish" element={<CabinetLogin />} />
      <Route element={<RequireOwner />}>
        <Route index element={<CabinetHome />} />
        <Route path="obuna" element={<CabinetSubscription />} />
        <Route path="xodimlar" element={<CabinetEmployees />} />
        <Route path="xabarlar" element={<CabinetMessages />} />
        <Route path="*" element={<Navigate to="/kabinet" replace />} />
      </Route>
    </>
  );
}

/**
 * Biznes egasining veb-kabineti (`/kabinet/*`) — ALOHIDA bo'lak.
 *
 * Ilovadagi login va parol bilan kiriladi. Faqat o'qish va obunani
 * to'lash: buyurtma, xodim va PIN bilan ishlash ilovada qoladi —
 * ikki joyda bir xil amal bo'lsa, ular bir-biriga zid ketishi mumkin.
 */
export default function CabinetArea() {
  useNoIndex();
  return (
    <OwnerAuthProvider>
      <ToastProvider>
        <Routes>{cabinetRoutes()}</Routes>
      </ToastProvider>
    </OwnerAuthProvider>
  );
}
