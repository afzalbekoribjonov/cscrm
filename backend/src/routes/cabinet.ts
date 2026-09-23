import { Router } from 'express';
import { z } from 'zod';

import { requireAuth, requireTenant } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import {
  CABINET_RANGES,
  loadCabinetEmployees,
  loadCabinetPayments,
  loadCabinetProfile,
  loadCabinetSummary,
  type CabinetRange,
} from '../services/cabinet.js';

/**
 * Biznes egasining veb-kabineti (`cscrm.uz/kabinet`).
 *
 * Faqat EGA (token da'vosida `role: owner`) va faqat O'Z biznesi —
 * biznes ID so'rovdan emas, tokendan olinadi. Hamma yo'l faqat o'qiydi.
 * Obuna, to'lov so'rovi va xabarlar mavjud `/license/*` yo'llari orqali.
 */
export const cabinetRouter: Router = Router();

cabinetRouter.use(requireAuth);

/** Kabinetga kirish: kim va qaysi biznes. Ega bo'lmasa — 403. */
cabinetRouter.get(
  '/me',
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req, 'owner');
    res.json({
      ok: true,
      profile: await loadCabinetProfile({ tenantId, email: req.user!.email, now: Date.now() }),
    });
  }),
);

const summaryQuery = z.object({
  range: z.enum(CABINET_RANGES as [CabinetRange, ...CabinetRange[]]).default('month'),
});

cabinetRouter.get(
  '/summary',
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req, 'owner');
    const parsed = summaryQuery.safeParse(req.query);
    if (!parsed.success) throw ApiError.badRequest('Davr noto\'g\'ri tanlangan.');
    res.json({ ok: true, summary: await loadCabinetSummary(tenantId, parsed.data.range, Date.now()) });
  }),
);

cabinetRouter.get(
  '/employees',
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req, 'owner');
    res.json({ ok: true, employees: await loadCabinetEmployees(tenantId) });
  }),
);

cabinetRouter.get(
  '/payments',
  asyncRoute(async (req, res) => {
    const { tenantId } = requireTenant(req, 'owner');
    res.json({ ok: true, payments: await loadCabinetPayments(tenantId) });
  }),
);
