import cors from 'cors';
import express, { type Request } from 'express';
import rateLimit from 'express-rate-limit';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';

import { env } from './config/env.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { adminRouter } from './routes/admin.js';
import { authRouter } from './routes/auth.js';
import { employeesRouter } from './routes/employees.js';
import { healthRouter, pingRouter } from './routes/health.js';
import { licenseRouter } from './routes/license.js';
import { siteRouter } from './routes/site.js';
import { FIREBASE_CONNECT_SRC, mountWeb, resolveWebDir } from './web.js';

const app = express();

// Render proxy ortida ishlaydi - haqiqiy mijoz IP'si shu sozlama bilan
// to'g'ri aniqlanadi (rate limit uchun muhim).
app.set('trust proxy', 1);

app.use(
  pinoHttp({
    level: env.isProd ? 'info' : 'debug',
    // Sog'liq tekshiruvi va uxlashga qarshi ping muntazam keladi -
    // loglarni bosib ketmasligi uchun jimlashtiramiz.
    autoLogging: {
      ignore: (req: { url?: string }) =>
        req.url === '/api/v1/health' || req.url === '/api/v1/ping',
    },
  }),
);

// Websayt shu servisdan tarqatilsa, brauzer Firebase Auth'ga chiqa
// olishi kerak. Helmet'ning odatiy CSP'sida `connect-src` yo'q va u
// `default-src 'self'` ga tushadi — natijada kirish so'rovi bloklanadi.
app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: true,
      directives: {
        'connect-src': ["'self'", ...FIREBASE_CONNECT_SRC],
      },
    },
  }),
);
/**
 * So'rov shu servisning O'ZIDAN kelganmi.
 *
 * Websayt shu servisdan tarqatilganda uning origin'i `CORS_ORIGINS`
 * ro'yxatida bo'lmasligi mumkin - lekin u begona emas, o'zimiz.
 * `trust proxy` yoqilgani uchun `req.protocol` proksi ortida ham
 * to'g'ri sxemani beradi.
 */
function isSameOrigin(req: Request, origin: string): boolean {
  const host = req.get('host');
  return Boolean(host) && origin === `${req.protocol}://${host}`;
}

/**
 * CORS faqat `/api/` ga qo'llanadi - statik fayllarga u umuman kerak
 * emas va u yerda faqat xalaqit beradi.
 */
app.use(
  '/api/',
  cors((req, cb) => {
    const origin = req.headers.origin;

    // Origin yo'q = mobil ilova yoki server-to-server. Ularga ruxsat,
    // chunki CORS brauzer himoyasi - ilovaga aloqasi yo'q.
    if (
      !origin ||
      env.corsOrigins.includes(origin) ||
      isSameOrigin(req as Request, origin)
    ) {
      return cb(null, { origin: true, credentials: true });
    }

    // Rad etamiz, lekin XATOLIK TASHLAMAYMIZ. `throw` qilinsa Express
    // 500 qaytaradi va begona sayt bizning servisimizni xato holatga
    // tushira oladi. To'g'ri xatti-harakat - CORS sarlavhasini
    // qo'ymaslik; javobni o'qishni brauzerning o'zi to'xtatadi.
    cb(null, { origin: false });
  }),
);
app.use(express.json({ limit: '1mb' }));

// Sog'liq tekshiruvi va uxlashga qarshi ping so'rov CHEKLOVIDAN OLDIN
// ulanadi.
//
// Bu shunchaki qulaylik emas: mijozlar yuki chegarani to'ldirsa,
// Render'ning sog'liq tekshiruvi ham 429 olardi va u buni "xizmat
// nosog'lom" deb tushunib, servisni qayta ishga tushirardi — aynan eng
// band paytda. Ikkala yo'l ham arzon va maxfiy ma'lumot qaytarmaydi.
app.use('/api/v1', pingRouter);
app.use('/api/v1', healthRouter);

app.use(
  '/api/',
  rateLimit({
    windowMs: 60_000,
    limit: 120,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: {
      ok: false,
      error: { code: 'rate_limited', message: 'Juda ko\'p so\'rov yuborildi.' },
    },
  }),
);

app.use('/api/v1/admin', adminRouter);
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/employees', employeesRouter);
app.use('/api/v1/license', licenseRouter);
app.use('/api/v1/site', siteRouter);

// Websayt (agar yig'ilgan bo'lsa) - API yo'llaridan KEYIN, xatolik
// ishlovchisidan OLDIN.
const webDir = resolveWebDir(process.env.WEB_DIR);
if (webDir) mountWeb(app, webDir);

app.use(notFoundHandler);
app.use(errorHandler);

const server = app.listen(env.PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`[cscrm-api] ${env.NODE_ENV} — http://localhost:${env.PORT}`);
});

// Render deploy paytida SIGTERM yuboradi: joriy so'rovlarni tugatib,
// keyin chiqamiz (aks holda foydalanuvchi uzilib qolgan javob oladi).
for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10_000).unref();
  });
}
