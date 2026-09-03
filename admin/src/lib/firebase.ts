import { initializeApp, type FirebaseApp } from 'firebase/app';
import { getAuth, type Auth } from 'firebase/auth';

import { firebaseConfig, isFirebaseConfigured } from './env';

/**
 * Firebase DANGASA ishga tushadi.
 *
 * Sozlama bo'lmasa marketing sahifalari baribir ochilishi kerak —
 * shuning uchun modul yuklanishida emas, faqat kerak bo'lganda.
 */
let app: FirebaseApp | undefined;

export function firebaseApp(): FirebaseApp {
  if (!isFirebaseConfigured()) {
    throw new Error(
      'Firebase sozlanmagan. `admin/.env.local` faylini to\'ldiring.',
    );
  }
  app ??= initializeApp(firebaseConfig());
  return app;
}

export function firebaseAuth(): Auth {
  return getAuth(firebaseApp());
}
