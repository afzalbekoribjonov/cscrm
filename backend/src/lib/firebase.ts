import { cert, getApps, initializeApp, type App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getDatabase } from 'firebase-admin/database';

import { env } from '../config/env.js';

/**
 * Service account JSON'ni o'qiydi.
 *
 * Render'da ko'p qatorli qiymat kiritish noqulay, shuning uchun ikki
 * ko'rinish qo'llab-quvvatlanadi:
 *   1. To'g'ridan-to'g'ri JSON matn
 *   2. base64 ga o'ralgan JSON (tavsiya etiladi - yangi qator muammosi yo'q)
 */
function readServiceAccount(): Record<string, unknown> {
  const raw = env.FIREBASE_SERVICE_ACCOUNT.trim();
  const json = raw.startsWith('{')
    ? raw
    : Buffer.from(raw, 'base64').toString('utf8');

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(json) as Record<string, unknown>;
  } catch {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT JSON sifatida o\'qilmadi. Firebase Console → ' +
        'Project settings → Service accounts → "Generate new private key" ' +
        'faylini base64 ga o\'rab joylashtiring.',
    );
  }

  // `private_key` odatda `\n` belgilarini literal ko'rinishda saqlaydi -
  // uni haqiqiy yangi qatorga aylantirmasak, imzo ishlamaydi.
  if (typeof parsed.private_key === 'string') {
    parsed.private_key = parsed.private_key.replace(/\n/g, '\n');
  }
  return parsed;
}

let app: App | undefined;

/** Admin SDK ilovasi - bir marta yaratiladi (hot reload'ga chidamli). */
export function firebaseApp(): App {
  if (app) return app;
  app =
    getApps()[0] ??
    initializeApp({
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      credential: cert(readServiceAccount() as any),
      databaseURL: env.FIREBASE_DATABASE_URL,
    });
  return app;
}

export const db = () => getDatabase(firebaseApp());
export const auth = () => getAuth(firebaseApp());
