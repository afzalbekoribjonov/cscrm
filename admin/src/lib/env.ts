/**
 * Brauzerga chiqadigan sozlamalar.
 *
 * DIQQAT: Firebase qiymatlari DANGASA (lazy) o'qiladi. Ilgari ular modul
 * yuklanishida tekshirilgan edi — natijada sozlama yo'q bo'lsa BUTUN sayt
 * (marketing sahifalari ham) oq ekranga aylanardi. Endi tekshiruv faqat
 * Firebase haqiqatan kerak bo'lganda ishga tushadi, marketing sahifalari
 * esa sozlamasiz ham ochilaveradi.
 */
function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Sozlama yetishmayapti: ${name}. ` +
        '`admin/.env.local` faylini `.env.example` asosida to\'ldiring.',
    );
  }
  return value;
}

const raw = import.meta.env;

export const env = {
  apiBaseUrl: raw.VITE_API_BASE_URL ?? 'http://localhost:8080',
  isDev: raw.DEV,
} as const;

/** Firebase sozlanganmi — Auth'ga urinishdan OLDIN shuni tekshiring. */
export function isFirebaseConfigured(): boolean {
  return Boolean(
    raw.VITE_FIREBASE_API_KEY &&
      raw.VITE_FIREBASE_PROJECT_ID &&
      raw.VITE_FIREBASE_APP_ID &&
      raw.VITE_FIREBASE_DATABASE_URL,
  );
}

/**
 * Firebase konfiguratsiyasi. Sozlama to'liq bo'lmasa xatolik tashlaydi —
 * shuning uchun chaqirishdan oldin [isFirebaseConfigured] ni tekshiring.
 */
export function firebaseConfig() {
  return {
    apiKey: required('VITE_FIREBASE_API_KEY', raw.VITE_FIREBASE_API_KEY),
    authDomain: required('VITE_FIREBASE_AUTH_DOMAIN', raw.VITE_FIREBASE_AUTH_DOMAIN),
    projectId: required('VITE_FIREBASE_PROJECT_ID', raw.VITE_FIREBASE_PROJECT_ID),
    databaseURL: required('VITE_FIREBASE_DATABASE_URL', raw.VITE_FIREBASE_DATABASE_URL),
    appId: required('VITE_FIREBASE_APP_ID', raw.VITE_FIREBASE_APP_ID),
    messagingSenderId: raw.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '',
  } as const;
}
