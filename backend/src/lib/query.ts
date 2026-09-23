import type { Reference } from 'firebase-admin/database';

/** Baza "bu maydon bo'yicha indeks yo'q" deb rad etdimi. */
export function isMissingIndex(err: unknown): boolean {
  return err instanceof Error && /index not defined/i.test(err.message);
}

const warned = new Set<string>();

/**
 * `orderByChild(child).equalTo(value)` — qoidalarda indeks bo'lmasa ham ishlaydi.
 *
 * NEGA: `.indexOn` baza qoidalarida turadi va qoidalar kod bilan birga
 * EMAS, alohida joylanadi. Indeks hali joylanmagan bo'lsa so'rov
 * "Index not defined" bilan yiqiladi — biznesni o'chirish yoki jurnal
 * shunchaki ishlamay qolardi. Bunday holda tugun to'liq o'qiladi va
 * xotirada saralanadi: sekinroq, lekin natija bir xil. Qoidalar
 * joylangach indeksli yo'l o'zi ishlay boshlaydi.
 *
 * `limitToLast` — kalit tartibidagi oxirgi N ta (push-kalitlar uchun —
 * eng yangilari).
 */
export async function whereEquals<T = unknown>(
  ref: Reference,
  child: string,
  value: string,
  limitToLast?: number,
): Promise<Record<string, T>> {
  try {
    const query = ref.orderByChild(child).equalTo(value);
    const snap = await (limitToLast ? query.limitToLast(limitToLast) : query).get();
    return (snap.val() ?? {}) as Record<string, T>;
  } catch (err) {
    if (!isMissingIndex(err)) throw err;
    const where = `${ref.key ?? '/'}.${child}`;
    if (!warned.has(where)) {
      warned.add(where);
      // eslint-disable-next-line no-console
      console.warn(`[cscrm] ${where} indeksi yo'q — tugun to'liq o'qilmoqda. Baza qoidalarini joylang.`);
    }
    const all = ((await ref.get()).val() ?? {}) as Record<string, unknown>;
    const matched = Object.keys(all)
      .sort()
      .filter((k) => {
        const v = all[k];
        return typeof v === 'object' && v !== null && (v as Record<string, unknown>)[child] === value;
      });
    const keys = limitToLast ? matched.slice(-limitToLast) : matched;
    return Object.fromEntries(keys.map((k) => [k, all[k] as T]));
  }
}
