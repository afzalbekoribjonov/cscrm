import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import express, { type Express, type NextFunction, type Request, type Response } from 'express';

/**
 * Websaytni SHU servisning o'zi tarqatadi.
 *
 * Nega bitta servis: Render'da har bir web-servis alohida hisoblanadi.
 * Backend va sayt bitta joyda tursa — bitta manzil, bitta uyg'oq tutish
 * pingi, CORS esa umuman kerak emas (sayt va API bir xil origin'da).
 *
 * Papka `WEB_DIR` bilan ko'rsatiladi yoki o'zi topiladi. Topilmasa
 * sayt tarqatilmaydi va servis faqat API bo'lib ishlaydi — mahalliy
 * ishlab chiqishda `admin` alohida Vite serverida turadi.
 */

/** Bu fayl `dist/` da ham, `src/` da ham bir xil natija beradi. */
const here = dirname(fileURLToPath(import.meta.url));

export function resolveWebDir(configured?: string): string | null {
  const candidate = configured
    ? resolve(process.cwd(), configured)
    : resolve(here, '../../admin/dist');

  return existsSync(join(candidate, 'index.html')) ? candidate : null;
}

/**
 * Statik fayllar va SPA yo'naltirishini ulaydi.
 *
 * API yo'llaridan KEYIN, xatolik ishlovchisidan OLDIN chaqiriladi.
 */
export function mountWeb(app: Express, webDir: string): void {
  const indexHtml = join(webDir, 'index.html');
  const assetsDir = join(webDir, 'assets');

  app.use(
    express.static(webDir, {
      // `index.html` ni express.static bermaydi — uni quyidagi SPA
      // yo'naltirishi beradi, shunda kesh sarlavhasi bir joyda boshqariladi.
      index: false,
      setHeaders(res, filePath) {
        // Vite `assets/` ichidagi fayl nomiga hash qo'yadi: mazmuni
        // o'zgarsa nom ham o'zgaradi, ya'ni uzoq keshlash xavfsiz.
        if (filePath.startsWith(assetsDir)) {
          res.setHeader('cache-control', 'public, max-age=31536000, immutable');
        } else {
          // Qolganlari (favicon va h.k.) hashsiz - qisqa kesh.
          res.setHeader('cache-control', 'public, max-age=3600');
        }
      },
    }),
  );

  /**
   * SPA: `/narxlar`, `/admin/tenants/...` kabi yo'llar serverda mavjud
   * emas, ularni brauzerdagi router hal qiladi. Shuning uchun har qanday
   * noma'lum yo'lga `index.html` beriladi.
   *
   * `/api/` ISTISNO: noma'lum API yo'li HTML emas, JSON 404 qaytarishi
   * kerak - aks holda ilova "server buzildi" deb tushunadi.
   */
  app.get('*', (req: Request, res: Response, next: NextFunction) => {
    if (req.path.startsWith('/api/')) return next();

    // Yangi joylashdan keyin foydalanuvchi eski ilovada qolib
    // ketmasligi uchun index keshlanmaydi.
    res.setHeader('cache-control', 'no-cache');
    res.sendFile(indexHtml, (err) => {
      if (err) next(err);
    });
  });
}

/**
 * Firebase Auth uchun ruxsat etilgan manzillar.
 *
 * Helmet'ning odatiy CSP'sida `connect-src` yo'q, shuning uchun u
 * `default-src 'self'` ga tushadi va brauzer Firebase'ga chiqishni
 * BLOKLAYDI. Bu faqat ishlab chiqarishda chiqadigan xato: Vite'ning
 * ishlab chiqish serveri CSP qo'ymaydi.
 */
export const FIREBASE_CONNECT_SRC = [
  'https://identitytoolkit.googleapis.com',
  'https://securetoken.googleapis.com',
];
