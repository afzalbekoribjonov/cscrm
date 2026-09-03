import { Router } from 'express';
import { z } from 'zod';

import { requireAuth, requireSuperAdmin } from '../middleware/auth.js';
import { ApiError, asyncRoute } from '../middleware/error.js';
import {
  confirmPayment,
  getStats,
  getTenant,
  listTenants,
  setSuspended,
} from '../services/admin.js';
import { PLANS } from '../services/license.js';
import {
  listPendingPayments,
  rejectPaymentRequest,
} from '../services/payment-request.js';

/**
 * Super-admin yo'llari — CSCRM egasining o'z mijozlarini boshqarish
 * paneli uchun.
 *
 * BARCHA yo'llar ikki qatlamdan o'tadi: `requireAuth` (token haqiqiymi)
 * va `requireSuperAdmin` (UID ruxsat etilganlar ro'yxatidami). Ro'yxat
 * `SUPER_ADMIN_UIDS` sozlamasida — ya'ni bazadan emas, serverdan
 * boshqariladi va uni hech kim ilova orqali o'zgartira olmaydi.
 */
export const adminRouter: Router = Router();

adminRouter.use(requireAuth, requireSuperAdmin);

/** Joriy foydalanuvchi super-admin ekanini tasdiqlaydi (panel kirishi). */
adminRouter.get('/me', (req, res) => {
  res.json({
    ok: true,
    uid: req.user!.uid,
    email: req.user!.email ?? null,
  });
});

adminRouter.get(
  '/stats',
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, stats: await getStats(Date.now()) });
  }),
);

adminRouter.get(
  '/tenants',
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, tenants: await listTenants(Date.now()) });
  }),
);

adminRouter.get(
  '/tenants/:tenantId',
  asyncRoute(async (req, res) => {
    const tenant = await getTenant(req.params.tenantId!, Date.now());
    res.json({ ok: true, tenant, plans: PLANS });
  }),
);

/**
 * Ko'rib chiqilmagan to'lov so'rovlari — panelning ish navbati.
 *
 * Tugunda faqat hal qilinmaganlari turadi, shuning uchun bu so'rov
 * mijozlar soni oshgani bilan og'irlashmaydi.
 */
adminRouter.get(
  '/payment-requests',
  asyncRoute(async (_req, res) => {
    res.json({ ok: true, requests: await listPendingPayments(), plans: PLANS });
  }),
);

const confirmBody = z.object({
  planId: z.string().min(1).max(40),
  /** Haqiqatda olingan summa. Berilmasa reja narxi yoziladi. */
  amount: z.number().min(0).optional(),
  note: z.string().max(500).optional(),
  /** Mijozning so'rovi asosida tasdiqlansa — o'sha so'rov yopiladi. */
  requestId: z.string().min(1).max(60).optional(),
});

/**
 * To'lovni tasdiqlab, obunani uzaytiradi.
 *
 * To'lov usuli qo'lda karta o'tkazma, shuning uchun tasdiqni odam bosadi.
 */
adminRouter.post(
  '/tenants/:tenantId/confirm-payment',
  asyncRoute(async (req, res) => {
    const parsed = confirmBody.safeParse(req.body);
    if (!parsed.success) {
      throw ApiError.badRequest(
        'Reja tanlanmagan yoki summa noto\'g\'ri.',
        parsed.error.flatten().fieldErrors,
      );
    }

    const result = await confirmPayment({
      tenantId: req.params.tenantId!,
      planId: parsed.data.planId,
      ...(parsed.data.amount !== undefined ? { amount: parsed.data.amount } : {}),
      ...(parsed.data.note ? { note: parsed.data.note } : {}),
      ...(parsed.data.requestId ? { requestId: parsed.data.requestId } : {}),
      byUid: req.user!.uid,
      now: Date.now(),
    });

    res.json({ ok: true, ...result });
  }),
);

const suspendBody = z.object({
  suspended: z.boolean(),
  reason: z.string().max(300).optional(),
});

adminRouter.post(
  '/tenants/:tenantId/suspend',
  asyncRoute(async (req, res) => {
    const parsed = suspendBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('So\'rov noto\'g\'ri.');

    await setSuspended(
      req.params.tenantId!,
      parsed.data.suspended,
      parsed.data.reason ?? null,
    );
    res.json({ ok: true });
  }),
);

const rejectBody = z.object({
  reason: z.string().min(1).max(300),
});

/**
 * To'lov so'rovini rad etadi.
 *
 * Sabab MAJBURIY va mijozga ko'rsatiladi - "rad etildi" deb sababsiz
 * qoldirish mijozni yordam xizmatiga qo'ng'iroq qilishga majbur qiladi.
 */
adminRouter.post(
  '/tenants/:tenantId/payment-requests/:requestId/reject',
  asyncRoute(async (req, res) => {
    const parsed = rejectBody.safeParse(req.body);
    if (!parsed.success) throw ApiError.badRequest('Rad etish sababini yozing.');

    await rejectPaymentRequest({
      tenantId: req.params.tenantId!,
      requestId: req.params.requestId!,
      reason: parsed.data.reason,
      byUid: req.user!.uid,
      now: Date.now(),
    });

    res.json({ ok: true });
  }),
);
