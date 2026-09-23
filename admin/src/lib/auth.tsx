import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut,
  type User,
} from 'firebase/auth';

import { api, ApiError } from './api';
import { firebaseAuth } from './firebase';
import { isFirebaseConfigured } from './env';
import type { Permission } from './permissions';

/** Server tasdiqlagan panel kirishi (`GET /admin/me`). */
export interface AdminAccess {
  isSuperAdmin: boolean;
  /** Panel xodimining roli; super-admin uchun `null`. */
  role: { id: string; name: string } | null;
  permissions: Permission[];
}

export interface AuthState {
  /** Firebase foydalanuvchisi. Kirilmagan bo'lsa `null`. */
  user: User | null;

  /**
   * Panelga kirish — server tasdiqlagan bo'lsa.
   *
   * Firebase'ga kirish O'ZI YETARLI EMAS: har qanday hisob kira oladi,
   * lekin panelga faqat super-admin va rolga ega xodimlar. Shu sabab
   * kirishdan keyin serverdan tasdiq va vakolatlar so'raladi.
   */
  access: AdminAccess | null;

  /** Vakolat bormi — menyu va tugmalar uchun (himoya serverda). */
  can: (permission: Permission) => boolean;

  /** Boshlang'ich tekshiruv tugadimi. */
  ready: boolean;

  signIn: (email: string, password: string) => Promise<void>;
  signOutNow: () => Promise<void>;
}

/** Vakolatlar ro'yxatidan `can` — kontekst va sinovlar uchun bitta joy. */
export function canFrom(access: AdminAccess | null): (p: Permission) => boolean {
  const set = new Set(access?.permissions ?? []);
  return (p) => Boolean(access) && (access!.isSuperAdmin || set.has(p));
}

/** Eksport — faqat ko'rib chiqish sahifalari (src/dev/) soxta foydalanuvchi berishi uchun. */
export const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [access, setAccess] = useState<AdminAccess | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!isFirebaseConfigured()) {
      setReady(true);
      return;
    }

    return onAuthStateChanged(firebaseAuth(), async (next) => {
      setUser(next);

      if (!next) {
        setAccess(null);
        setReady(true);
        return;
      }

      try {
        const me = await api.get<Partial<AdminAccess>>('/api/v1/admin/me');
        setAccess({
          isSuperAdmin: me.isSuperAdmin === true,
          role: me.role ?? null,
          permissions: Array.isArray(me.permissions) ? me.permissions : [],
        });
      } catch (err) {
        // 403 - hisob haqiqiy, lekin panelga ruxsati yo'q. Bu xatolik
        // emas, oddiy holat: kirish rad etiladi.
        if (!(err instanceof ApiError) || err.status !== 403) {
          console.error('Panel kirishini tekshirib bo\'lmadi', err);
        }
        setAccess(null);
      } finally {
        setReady(true);
      }
    });
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      access,
      can: canFrom(access),
      ready,
      signIn: async (email, password) => {
        await signInWithEmailAndPassword(firebaseAuth(), email, password);
      },
      signOutNow: async () => {
        await signOut(firebaseAuth());
      },
    }),
    [user, access, ready],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth faqat <AuthProvider> ichida ishlaydi');
  return ctx;
}

/** Firebase Auth xatoliklarini o'zbekcha xabarga aylantiradi. */
export function authErrorMessage(err: unknown): string {
  const code = (err as { code?: string }).code ?? '';
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
      return 'E-pochta yoki parol noto\'g\'ri.';
    case 'auth/invalid-email':
      return 'E-pochta formatida xatolik.';
    case 'auth/user-disabled':
      return 'Bu hisob bloklangan.';
    case 'auth/too-many-requests':
      return 'Juda ko\'p urinish. Bir necha daqiqadan so\'ng urining.';
    case 'auth/network-request-failed':
      return 'Internet aloqasini tekshiring.';
    default:
      // Firebase'ning o'z matni ("Firebase: Error (auth/…)") ko'rsatilmaydi —
      // u inglizcha va foydalanuvchiga hech narsa aytmaydi. Tahlil uchun
      // konsolda qoladi.
      console.error('Kirish bajarilmadi', err);
      return 'Kirishda muammo yuz berdi. Qayta urinib ko\'ring.';
  }
}
