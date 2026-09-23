import { Suspense } from 'react';
import { Outlet } from 'react-router-dom';

import { RouteLoading } from '@/components/RouteLoading';
import { ToastProvider } from '@/components/ui';
import { AuthProvider } from '@/lib/auth';
import { useNoIndex } from '@/lib/seo';
// Panel uslublari faqat panel bilan yuklanadi — marketing sahifalariga kerak emas.
import '@/styles/ui.css';

/**
 * Panel hududi (`/kirish` va `/admin/*`) — ALOHIDA bo'lak.
 *
 * Firebase Auth SDK va panel komponentlari faqat shu yerda yuklanadi:
 * saytga kirgan oddiy tashrifchi ularni umuman yuklab olmaydi.
 * Kirish sahifasi va panel bitta `AuthProvider` ostida — biridan
 * ikkinchisiga o'tganda kirish holati qayta tekshirilmaydi.
 */
export default function AdminArea() {
  useNoIndex();
  return (
    <AuthProvider>
      <ToastProvider>
        <Suspense fallback={<RouteLoading />}>
          <Outlet />
        </Suspense>
      </ToastProvider>
    </AuthProvider>
  );
}
