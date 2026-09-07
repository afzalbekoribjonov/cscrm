import { getMessaging } from 'firebase-admin/messaging';

import { db } from '../lib/firebase.js';

/**
 * Push bildirishnomalar (FCM).
 *
 * Qurilma tokenlari ILDIZDA saqlanadi: xabar barcha bizneslarga
 * yuboriladi, ya'ni bitta so'rovda hamma token kerak. Tenant ichida
 * bo'lsa, har bir biznesdan alohida o'qish kerak bo'lardi.
 *
 * Token kalit sifatida ishlatiladi — bitta qurilma ikki marta
 * yozilmaydi. FCM tokenida `/` `.` `#` `$` `[` `]` bo'lmaydi, shuning
 * uchun u RTDB kaliti bo'la oladi (baribir tekshiramiz).
 */

export interface PushToken {
  tenantId: string;
  uid: string;
  platform: string;
  updatedAt: number;
}

/** FCM bitta so'rovda shuncha qurilmani qabul qiladi. */
const BATCH_SIZE = 500;

/** RTDB kalitida bo'lishi mumkin bo'lmagan belgilar. */
const INVALID_KEY = /[.#$/[\]]/;

export function isValidToken(token: string): boolean {
  return (
    token.length >= 20 && token.length <= 4096 && !INVALID_KEY.test(token)
  );
}

/**
 * Qurilma tokenini saqlaydi.
 *
 * Har safar ilova ochilganda chaqiriladi — token vaqti-vaqti bilan
 * yangilanadi va eskisi ishlamay qoladi.
 */
export async function registerToken(params: {
  token: string;
  tenantId: string;
  uid: string;
  platform: string;
  now: number;
}): Promise<void> {
  if (!isValidToken(params.token)) return;

  const record: PushToken = {
    tenantId: params.tenantId,
    uid: params.uid,
    platform: params.platform,
    updatedAt: params.now,
  };
  await db().ref(`push_tokens/${params.token}`).set(record);
}

/** Chiqishda chaqiriladi — qurilmaga endi xabar bormasin. */
export async function removeToken(token: string): Promise<void> {
  if (!isValidToken(token)) return;
  await db().ref(`push_tokens/${token}`).remove();
}

/**
 * Barcha qurilmalarga xabar yuboradi.
 *
 * Yetkazilmagan tokenlar O'CHIRILADI: ilova o'chirilgan yoki token
 * eskirgan qurilmalar ro'yxatda abadiy qolib, u cheksiz o'sib
 * ketmasligi kerak. FCM aynan qaysi token yaroqsizligini aytadi.
 *
 * Xatolik TASHLANMAYDI: push — qo'shimcha yetkazish yo'li. U ishlamasa
 * ham xabarning o'zi bazada saqlangan va ilova ochilganda ko'rinadi.
 */
export async function sendToAll(params: {
  title: string;
  body: string;
  data?: Record<string, string>;
}): Promise<{ sent: number; failed: number; removed: number }> {
  const result = { sent: 0, failed: 0, removed: 0 };

  let tokens: string[];
  try {
    const snap = await db().ref('push_tokens').get();
    if (!snap.exists()) return result;
    tokens = Object.keys(snap.val() as Record<string, PushToken>);
  } catch {
    return result;
  }

  const stale: string[] = [];

  for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
    const batch = tokens.slice(i, i + BATCH_SIZE);
    try {
      const response = await getMessaging().sendEachForMulticast({
        tokens: batch,
        notification: { title: params.title, body: params.body },
        data: params.data ?? {},
        android: {
          priority: 'high',
          notification: {
            // Kanal ilovada shu nom bilan yaratiladi. Mos kelmasa
            // Android bildirishnomani jimgina tashlab yuboradi.
            channelId: 'cscrm_messages',
          },
        },
      });

      result.sent += response.successCount;
      result.failed += response.failureCount;

      response.responses.forEach((r, index) => {
        if (r.success) return;
        const code = r.error?.code ?? '';
        if (
          code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/invalid-argument'
        ) {
          const token = batch[index];
          if (token) stale.push(token);
        }
      });
    } catch {
      result.failed += batch.length;
    }
  }

  if (stale.length > 0) {
    const updates: Record<string, null> = {};
    for (const token of stale) updates[`push_tokens/${token}`] = null;
    try {
      await db().ref().update(updates);
      result.removed = stale.length;
    } catch {
      /* tozalash keyingi safar */
    }
  }

  return result;
}
