import { db } from '../lib/firebase.js';
import { ApiError } from '../middleware/error.js';

/**
 * CSCRM'dan barcha bizneslarga yuboriladigan xabarlar.
 *
 * Yangilik, eslatma yoki taklif — bir marta yoziladi, hamma ko'radi.
 *
 * ILDIZDA saqlanadi, har bir tenant ichida EMAS. Sabab: xabar hammaga
 * bir xil. Har bir biznesga nusxa yozilsa, 500 ta mijozda 500 ta nusxa
 * bo'lardi va matnni tuzatish uchun 500 tasini yangilash kerak bo'lardi.
 *
 * Kim o'qiganini biz kuzatmaymiz — bu qurilmaning o'z ishi. Server
 * tomonda "o'qildi" belgisini saqlash har bir xabar uchun har bir
 * foydalanuvchidan yozuv talab qilardi, foydasi esa deyarli yo'q.
 */

export type BroadcastKind = 'yangilik' | 'eslatma' | 'taklif';

export interface Broadcast {
  title: string;
  body: string;
  kind: BroadcastKind;
  createdAt: number;
  createdBy: string;
  /** Muddati o'tgach ilovada ko'rsatilmaydi. `null` — muddatsiz. */
  expiresAt: number | null;
}

const MAX_TITLE = 120;
const MAX_BODY = 2000;

/** Ilova bir marta o'qiydigan eng ko'p xabar soni. */
const FEED_LIMIT = 50;

export async function createBroadcast(params: {
  title: string;
  body: string;
  kind: BroadcastKind;
  expiresAt?: number | null;
  byUid: string;
  now: number;
}): Promise<{ id: string; broadcast: Broadcast }> {
  const title = params.title.trim();
  const body = params.body.trim();

  if (title.length === 0) throw ApiError.badRequest('Sarlavhani yozing.');
  if (body.length === 0) throw ApiError.badRequest('Xabar matnini yozing.');

  const broadcast: Broadcast = {
    title: title.slice(0, MAX_TITLE),
    body: body.slice(0, MAX_BODY),
    kind: params.kind,
    createdAt: params.now,
    createdBy: params.byUid,
    expiresAt: params.expiresAt ?? null,
  };

  const id = db().ref('broadcasts').push().key!;
  await db().ref(`broadcasts/${id}`).set(broadcast);

  return { id, broadcast };
}

export async function deleteBroadcast(id: string): Promise<void> {
  await db().ref(`broadcasts/${id}`).remove();
}

/**
 * Xabarlar ro'yxati, eng yangisi birinchi.
 *
 * [activeOnly] — muddati o'tganlarini tashlab ketadi (ilova uchun).
 * Panelda esa hammasi ko'rinadi, shu jumladan muddati o'tganlari.
 */
export async function listBroadcasts(params: {
  now: number;
  activeOnly: boolean;
}): Promise<(Broadcast & { id: string })[]> {
  const snap = await db()
    .ref('broadcasts')
    .orderByChild('createdAt')
    .limitToLast(FEED_LIMIT)
    .get();

  if (!snap.exists()) return [];

  const rows = Object.entries(snap.val() as Record<string, Broadcast>).map(
    ([id, b]) => ({ id, ...b }),
  );

  const filtered = params.activeOnly
    ? rows.filter((b) => b.expiresAt === null || b.expiresAt > params.now)
    : rows;

  return filtered.sort((a, b) => b.createdAt - a.createdAt);
}
