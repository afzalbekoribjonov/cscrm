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
import { healthRouter } from './routes/health.js';
import { licenseRouter } from './routes/license.js';

const app = express();

// Render proxy ortida ishlaydi - haqiqiy mijoz IP'si shu sozlama bilan
// to'g'ri aniqlanadi (rate limit uchun muhim).
app.set('trust proxy', 1);

app.use(
  pinoHttp({
    level: env.isProd ? 'info' : 'debug',
    // Sog'liq tekshiruvi har necha soniyada keladi - loglarni bosib
    // ketmasligi uchun jimlashtiramiz.
    autoLogging: {
      ignore: (req: { url?: string }) => req.url === '/api/v1/health',
    },
  }),
);

app.use(helmet());
app.use(
  cors({
    origin(origin, cb) {
      // Origin yo'q = mobil ilova yoki server-to-server. Ularga ruxsat,
      // chunki CORS brauzer himoyasi - ilovaga aloqasi yo'q.
      if (!origin) return cb(null, true);
      if (env.corsOrigins.includes(origin)) return cb(null, true);
      cb(new Error(`CORS: ${origin} ruxsat etilmagan`));
    },
    credentials: true,
  }),
);
app.use(express.json({ limit: '1mb' }));

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

app.use('/api/v1', healthRouter);
app.use('/api/v1/admin', adminRouter);
app.use('/api/v1/auth', authRouter);
app.use('/api/v1/employees', employeesRouter);
app.use('/api/v1/license', licenseRouter);

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
