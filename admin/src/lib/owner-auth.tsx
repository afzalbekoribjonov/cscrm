import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut, type User } from 'firebase/auth';

import { api, ApiError } from './api';
import type { CabinetProfile } from './cabinet-types';
import { isFirebaseConfigured } from './env';
import { firebaseAuth } from './firebase';

/** Ilova loginlari Firebase'da shu domen bilan email bo'lib saqlanadi. */
const LOGIN_DOMAIN = '@cscrm.local';

/** Server qoidasi bilan bir xil (backend `sanitizeLogin`, ilova `auth_service`). */
export function normalizeLogin(input: string): string {
  return input.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
}

export interface OwnerAuthState {
  user: User | null;
  /** Server tasdiqlagan biznes egasi. `null` — ega emas yoki kirmagan. */
  profile: CabinetProfile | null;
  /** Kirgan, lekin biznes egasi emas (xodim, panel hisobi va h.k.). */
  notOwner: boolean;
  ready: boolean;
  signIn: (login: string, password: string) => Promise<void>;
  signOutNow: () => Promise<void>;
  /** Profil va obuna holatini qayta olish (to'lovdan keyin). */
  refresh: () => Promise<void>;
}

/** Eksport — ko'rib chiqish sahifasi soxta ega berishi uchun. */
export const OwnerAuthContext = createContext<OwnerAuthState | null>(null);

/**
 * Biznes egasining kabinetga kirishi.
 *
 * Kirish ilovadagi login va parol bilan. Firebase'ga kirish O'ZI
 * YETARLI EMAS: server tokendagi da'vo bo'yicha "bu biznes egasi"
 * deb tasdiqlashi kerak (`GET /cabinet/me`).
 */
export function OwnerAuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<CabinetProfile | null>(null);
  const [notOwner, setNotOwner] = useState(false);
  const [ready, setReady] = useState(false);

  const load = useCallback(async () => {
    try {
      const r = await api.get<{ profile: CabinetProfile }>('/api/v1/cabinet/me');
      setProfile(r.profile);
      setNotOwner(false);
    } catch (err) {
      setProfile(null);
      // 403 — hisob haqiqiy, lekin biznes egasi emas.
      setNotOwner(err instanceof ApiError && err.status === 403);
      if (!(err instanceof ApiError) || (err.status !== 403 && err.status !== 401)) {
        console.error('Kabinet profilini olib bo\'lmadi', err);
      }
    }
  }, []);

  useEffect(() => {
    if (!isFirebaseConfigured()) {
      setReady(true);
      return;
    }
    return onAuthStateChanged(firebaseAuth(), async (next) => {
      setUser(next);
      if (!next) {
        setProfile(null);
        setNotOwner(false);
        setReady(true);
        return;
      }
      // Yangi kirishda da'volar tokenga tushgan bo'lishi uchun yangilanadi.
      await next.getIdToken(true).catch(() => undefined);
      await load();
      setReady(true);
    });
  }, [load]);

  const value = useMemo<OwnerAuthState>(
    () => ({
      user,
      profile,
      notOwner,
      ready,
      signIn: async (login, password) => {
        await signInWithEmailAndPassword(firebaseAuth(), `${normalizeLogin(login)}${LOGIN_DOMAIN}`, password);
      },
      signOutNow: async () => {
        await signOut(firebaseAuth());
      },
      refresh: load,
    }),
    [user, profile, notOwner, ready, load],
  );

  return <OwnerAuthContext.Provider value={value}>{children}</OwnerAuthContext.Provider>;
}

export function useOwnerAuth(): OwnerAuthState {
  const ctx = useContext(OwnerAuthContext);
  if (!ctx) throw new Error('useOwnerAuth faqat <OwnerAuthProvider> ichida ishlaydi');
  return ctx;
}

/** Kirish xatolari — ega uchun tushunarli matn (login, email emas). */
export function ownerAuthErrorMessage(err: unknown): string {
  const code = (err as { code?: string }).code ?? '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
    case 'auth/invalid-email':
      return 'Login yoki parol noto\'g\'ri.';
    case 'auth/user-disabled':
      return 'Bu hisob bloklangan. Yordam xizmatiga murojaat qiling.';
    case 'auth/too-many-requests':
      return 'Juda ko\'p urinish. Bir necha daqiqadan so\'ng qayta urining.';
    case 'auth/network-request-failed':
      return 'Internet aloqasini tekshiring.';
    default:
      console.error('Kabinetga kirib bo\'lmadi', err);
      return 'Kirishda muammo yuz berdi. Qayta urinib ko\'ring.';
  }
}
