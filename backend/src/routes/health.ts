import { Router, type Request, type Response } from 'express';

import { env } from '../config/env.js';

export const healthRouter: Router = Router();

const startedAt = Date.now();

/**
 * Render sog'liq tekshiruvi shu yo'lni chaqiradi. Firebase'ga MURoJAAT
 * QILMAYDI - baza sekin javob bersa ham servis "o'lik" deb belgilanmasligi
 * uchun (bu tekshiruv faqat "process tirikmi" degan savolga javob beradi).
 */
healthRouter.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'cscrm-api',
    env: env.NODE_ENV,
    uptimeSeconds: Math.floor((Date.now() - startedAt) / 1000),
    time: new Date().toISOString(),
  });
});

/**
 * Uxlab qolishga qarshi ping — ALOHIDA router.
 *
 * Render'ning bepul tarifida xizmat 15 daqiqa harakatsizlikdan keyin
 * to'xtaydi va keyingi so'rov ~50 soniya kutadi. Tashqi kuzatuv xizmati
 * (UptimeRobot va shunga o'xshashlar) shu yo'lga muntazam so'rov yuborib
 * turadi va xizmat uxlamaydi.
 *
 * Nega `healthRouter` dan ajratilgan: bu yo'l so'rov CHEKLOVIDAN OLDIN
 * ulanadi. Kuzatuv xizmati mijozlar uchun ajratilgan budjetni yemasligi,
 * va bir nechta kuzatuvchi ulansa 429 olib xizmatni "o'lik" deb
 * belgilamasligi kerak.
 *
 * `HEAD` oshkora yozilgan: kuzatuv xizmatlari odatda aynan HEAD yuboradi
 * (javob tanasi kerak emas, faqat holat kodi). Express `GET` yo'lini
 * HEAD'ga o'zi ham ulaydi, lekin bu yo'lning BUTUN vazifasi HEAD'ga
 * javob berish — shuning uchun u ko'rinib tursin.
 *
 * Ataylab eng arzon: bazaga bormaydi, hech narsa hisoblamaydi, tana
 * qaytarmaydi. `/health` dan farqi shunda — u xizmat holatini bildiradi,
 * bu esa faqat "tirikman" deydi.
 */
export const pingRouter: Router = Router();

function pong(_req: Request, res: Response) {
  res.status(200).end();
}

pingRouter.head('/ping', pong);
pingRouter.get('/ping', pong);
