import { db } from '../lib/firebase.js';
import { ApiError } from '../middleware/error.js';

/**
 * Saytning boshqariladigan sozlamalari — hozircha ilovani yuklab olish
 * manzili.
 *
 * NEGA BAZADA, KODDA EMAS: APK har yangilanganda manzil o'zgaradi
 * (yangi fayl, yangi versiya). Manzil kodda tursa, har safar saytni
 * qayta yig'ib, qayta joylash kerak bo'lardi — ya'ni ilovani
 * yangilash uchun dasturchi kerak bo'lardi. Endi u paneldan
 * o'zgartiriladi va sayt darhol yangisini beradi.
 *
 * Fayl serverda saqlanmaydi — manzil tashqi xotiraga (Google Drive,
 * Telegram kanali, keyinchalik Play Store) ishora qiladi. Bu ataylab:
 * 50 MB li faylni har yuklab olishda bepul tarifdagi server orqali
 * uzatish uni sekinlashtirib qo'yardi.
 */

export interface SiteSettings {
  /** APK (yoki Play Store) manzili. Bo'sh bo'lsa — sahifada tugma o'rniga aloqa taklifi chiqadi. */
  downloadUrl: string;
  /** Ko'rsatiladigan versiya, masalan "1.4.0". */
  version: string;
  /** Fayl hajmi MB da. 0 — noma'lum, ko'rsatilmaydi. */
  sizeMb: number;
  /** Qisqa izoh — "nima yangilandi". */
  note: string;
  updatedAt: number;
  updatedBy: string;
}

const PATH = 'site_settings';

const EMPTY: SiteSettings = {
  downloadUrl: '',
  version: '',
  sizeMb: 0,
  note: '',
  updatedAt: 0,
  updatedBy: '',
};

/**
 * Joriy sozlamalar.
 *
 * Baza javob bermasa bo'sh qiymat qaytadi, xatolik EMAS: yuklab olish
 * manzili yo'qligi sababli butun sahifa ochilmay qolgandan ko'ra,
 * sahifa ochilib "aloqaga chiqing" degani yaxshiroq.
 */
export async function getSiteSettings(): Promise<SiteSettings> {
  try {
    const snap = await db().ref(PATH).get();
    if (!snap.exists()) return EMPTY;
    return { ...EMPTY, ...(snap.val() as Partial<SiteSettings>) };
  } catch {
    return EMPTY;
  }
}

/**
 * Manzilni tekshiradi va tozalaydi.
 *
 * Bu shunchaki chiroyli ko'rinish uchun emas, XAVFSIZLIK tekshiruvi:
 * manzil saytda `<a href>` ichiga tushadi. `javascript:` sxemasi
 * yozilsa, u havolani bosgan har bir mehmonning brauzerida kod
 * ishga tushirishning tayyor yo'li bo'lardi.
 */
export function normalizeDownloadUrl(raw: string): string {
  const url = raw.trim();
  if (!url) return '';

  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw ApiError.badRequest('Manzil noto\'g\'ri — to\'liq havola kiriting.');
  }
  // `javascript:` va shunga o'xshash sxemalar sahifaga kod
  // kiritishning tayyor yo'li bo'lardi — faqat http(s) ruxsat etiladi.
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
    throw ApiError.badRequest('Manzil https:// bilan boshlanishi kerak.');
  }
  return url;
}

export async function setSiteSettings(params: {
  downloadUrl: string;
  version: string;
  sizeMb: number;
  note: string;
  byUid: string;
  now: number;
}): Promise<SiteSettings> {
  const next: SiteSettings = {
    downloadUrl: normalizeDownloadUrl(params.downloadUrl),
    version: params.version.trim().slice(0, 20),
    sizeMb:
      Number.isFinite(params.sizeMb) && params.sizeMb > 0
        ? Math.round(params.sizeMb * 10) / 10
        : 0,
    note: params.note.trim().slice(0, 300),
    updatedAt: params.now,
    updatedBy: params.byUid,
  };

  await db().ref(PATH).set(next);
  return next;
}
