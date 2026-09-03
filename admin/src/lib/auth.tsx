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

interface AuthState {
  /** Firebase foydalanuvchisi. Kirilmagan bo'lsa `null`. */
  user: User | null;

  /**
   * Server bu foydalanuvchini super-admin deb tasdiqladimi.
   *
   * Firebase'ga kirish O'ZI YETARLI EMAS: har qanday hisob kira oladi,
   * lekin panelga faqat `SUPER_ADMIN_UIDS` ro'yxatidagilar kiradi. Shu
   * sabab kirishdan keyin serverdan tasdiq so'raladi.
   */
  isSuperAdmin: boolean;

  /** Boshlang'ich tekshiruv tugadimi. */
  ready: boolean;

  signIn: (email: string, password: string) => Promise<void>;
  signOutNow: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isSuperAdmin, setIsSuperAdmin] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!isFirebaseConfigured()) {
      setReady(true);
      return;
    }

    return onAuthStateChanged(firebaseAuth(), async (next) => {
      setUser(next);

      if (!next) {
        setIsSuperAdmin(false);
        setReady(true);
        return;
      }

      try {
        await api.get('/api/v1/admin/me');
        setIsSuperAdmin(true);
      } catch (err) {
        // 403 - hisob haqiqiy, lekin super-admin emas. Bu xatolik emas,
        // oddiy holat: kirish rad etiladi.
        if (!(err instanceof ApiError) || err.status !== 403) {
          console.error('Super-admin tekshiruvi bajarilmadi', err);
        }
        setIsSuperAdmin(false);
      } finally {
        setReady(true);
      }
    });
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      isSuperAdmin,
      ready,
      signIn: async (email, password) => {
        await signInWithEmailAndPassword(firebaseAuth(), email, password);
      },
      signOutNow: async () => {
        await signOut(firebaseAuth());
      },
    }),
    [user, isSuperAdmin, ready],
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
      return err instanceof Error ? err.message : 'Kirishda xatolik.';
  }
}
