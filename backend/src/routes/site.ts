import { Router } from 'express';

import { asyncRoute } from '../middleware/error.js';
import { getSiteSettings } from '../services/site-settings.js';

/**
 * Websaytning ochiq sozlamalari.
 *
 * ATAYLAB ochiq (tizimga kirish talab qilinmaydi): bu ma'lumotni
 * saytga kelgan har bir odam ko'radi — ilovani yuklab olish manzili va
 * versiyasi. Maxfiy hech narsa yo'q.
 */
export const siteRouter: Router = Router();

siteRouter.get(
  '/settings',
  asyncRoute(async (_req, res) => {
    const settings = await getSiteSettings();
    res.json({
      ok: true,
      download: {
        url: settings.downloadUrl,
        version: settings.version,
        sizeMb: settings.sizeMb,
        note: settings.note,
        updatedAt: settings.updatedAt,
      },
    });
  }),
);
