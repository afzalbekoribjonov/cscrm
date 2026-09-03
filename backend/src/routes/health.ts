import { Router } from 'express';

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
